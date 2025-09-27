(*
  HParserを使用した簡易HTMLパーサー(Delphi/Lazarus共用)
  TRegExpr:https://github.com/andgineer/TRegExpr

  ver1.6 2025/09/27 Createの#13#10削除で#13を削除出来ていなかった不具合を修正した
  ver1.5 2025/09/08 属性="名前"検索を正規表現検索に変更した
  ver1.4 2025/09/07 検索メソッド名をFind, FindRegexに変更した(旧来のメソッドも使用可)
                    またマッチした全てのコンテンツを返すFindAll, FindRegexAllを追加した
  vcr1.3 2025/09/02 Linux環境も考慮してCRとLFの処理を分離した
  ver1.2 2025/08/25 GetNodeTextでの各ノード値からHTMLソースを再構築する際の半角スペースの処理を修正した
  ver1.1 2025/08/23 HTMLエンコードされた文字のデコード処理を追加した
                    GetText処理の前後に呼呼び出せるコールバック関数を追加したファイル名フィルターを追加した
  ver1.0 2025/08/22 初版
*)
unit SHParser;

{$IFDEF FPC}
  {$MODE DELPHI}
  {$CODEPAGE UTF8}
{$ENDIF}

interface

uses
  Classes, SysUtils, HParse, RegExpr
{$IFDEF FPC}
  ,LazUTF8
{$ELSE}
  ,LazUTF8Wrap
{$ENDIF}
  ;

type
  TNodeInfo = record
    Token: AnsiChar;
    Value: string;
    Lebel: integer;
  end;
  TFoundList = TStringList;
  TNodeArray = array of TNodeInfo;
  TOnGetText = function(HTMLSrc: string): string;

  TSHParser = class(TObject)
  protected
    FParser: THParser;
    FNode: TNodeArray;
    FCount: integer;
    FHTMLSrc: string;
    FFoundList: TFoundList;
    FIsAll: boolean;
    FNodeComp: integer;
    procedure InitNode;
    function GetNodeCount: integer;
    // 検索処理本体
    function FindTagwAttr(Tag, Attrib, AName: string; AsText, IsAll: boolean): TFoundList;
    function FindTag(Tag: string; AsText, IsAll: boolean): TFoundList;
    function FindRegExpr(PatternL, PatternR: string; AsText, IsAll: boolean): TFoundList;
  public
    OnBeforeGetText: TOnGetText;
    OnAfterGetText: TOnGetText;
    constructor Create(HTML: String);
    destructor Destroy; override;
    // 旧検索処理
    function GetNodeText(Tag, Attrib, AName: string; AsText: boolean = True): string; overload;
    function GetNodeText(Tag: string; AsText: boolean = True): string; overload;
    function GetRegExText(PatternL, PatternR: string; AsText: boolean = True): string;
    // 検索処理
    function Find(Tag, Attrib, AName: string; AsText: boolean = True): string; overload;
    function Find(Tag: string; AsText: boolean = True): string; overload;
    function FindAll(Tag, Attrib, AName: string; AsText: boolean = True): TFoundList; overload;
    function FindAll(Tag: string; AsText: boolean = True): TFoundList; overload;
    function FindRegex(PatternL, PatternR: string; AsText: boolean = True): string; overload;
    function FindRegexAll(PatternL, PatternR: string; AsText: boolean = True): TFoundList; overload;

    function GetText(HTMLSrc: string): string;
    function GetMaskedContent(SrcStr, PattarnL, PattarnR: string): string;
    function CompareRegex(InputStr, ARegExpr: string): boolean;
    function PathFilter(PathName: string; PathLength: integer = 24): string;
    property Node: TNodeArray read FNode;
    property NodeCount: integer read GetNodeCount;
    property NodeComp: integer read FNodeComp;
  end;


implementation

// HTML特殊文字の処理
// 1)エスケープ文字列 → 実際の文字
// 2)&#x????; → 通常の文字
function Restore2RealChar(Base: string): string;
var
  tmp, cd, rcd: string;
  w, mp, ml: integer;
  ch: Char;
  wch: WideChar;
  r: TRegExpr;
begin
  // エスケープされた文字
  tmp := UTF8StringReplace(Base, '&lt;',      '<',  [rfReplaceAll]);
  tmp := UTF8StringReplace(tmp,  '&gt;',      '>',  [rfReplaceAll]);
  tmp := UTF8StringReplace(tmp,  '&quot;',    '"',  [rfReplaceAll]);
  tmp := UTF8StringReplace(tmp,  '&nbsp;',    ' ',  [rfReplaceAll]);
  tmp := UTF8StringReplace(tmp,  '&yen;',     '\',  [rfReplaceAll]);
  tmp := UTF8StringReplace(tmp,  '&brvbar;',  '|',  [rfReplaceAll]);
  tmp := UTF8StringReplace(tmp,  '&copy;',    '©',  [rfReplaceAll]);
  tmp := UTF8StringReplace(tmp,  '&amp;',     '&',  [rfReplaceAll]);
  // &#????;にエンコードされた文字をデコードする(2023/3/19)
  // 正規表現による処理に変更した(2024/3/9)
  r := TRegExpr.Create;
  try
    r.Expression  := '&#.*?;';
    r.InputString := tmp;
    if r.Exec then
    begin
      repeat
        cd := r.Match[0];
        mp := r.MatchPos[0];
        ml := r.MatchLen[0];
        UTF8Delete(tmp, mp, ml);
        UTF8Delete(cd, 1, 2);           // &#を削除する
        UTF8Delete(cd, UTF8Length(cd), 1);  // 最後の;を削除する
        if cd[1] = 'x' then         // 先頭が16進数を表すxであればDelphiの16進数接頭文字$に変更する
          cd[1] := '$';
        try
          w := StrToInt(cd);
          ch := Char(w);
        except
          ch := '?';
        end;
        UTF8Insert(ch, tmp, mp);
        r.InputString := tmp;
      until not r.Exec;
    end;
    // unicodeエスケープ文字(\uxxxx)
    r.Expression  := '\\u[0-9A-Fa-f]{4}';
    r.InputString := tmp;
    if r.Exec then
    begin
      repeat
        cd := r.Match[0];
        rcd := '\' + cd;
        UTF8Delete(cd, 1, 2);   // \uを削除する
        UTF8Insert('$', cd, 1); // 先頭に16進数接頭文字$を追加する
        try
          w := StrToInt(cd);
          wch := Char(w);
        except
          wch := '？';
        end;
        tmp := ReplaceRegExpr(rcd, tmp, wch);
      until not r.ExecNext;
    end;
  finally
    r.Free;
  end;
  Result := tmp;
end;

constructor TSHParser.Create(HTML: string);
var
  s: string;
begin
  // HTML内の改行を削除する(Linux環境を考慮してCRとLFの処理を分離)
  s := UTF8StringReplace(HTML, #13, '', [rfReplaceAll]);
  s := UTF8StringReplace(s, #10, '', [rfReplaceAll]);
  FParser := THParser.Create(s);
  FHTMLSrc := s;
  FCount := 0;
  FFoundList := TFoundList.Create;
  // ノードデータを構成する
  InitNode;
end;

destructor TSHParser.Destroy;
begin
  if Assigned(FParser) then
    FParser.Free;
  SetLength(FNode, 0);
  if Assigned(FFoundList) then
    FFoundList.Free;
end;

// HParserで解析したトークンを基にノードを構成する
// 但し使い勝手を良くするために、TreeNodeで構成するのではなく
// トークンの相対位置をLebel値で保存する
procedure TSHParser.InitNode;
var
  d: integer;
  cf: boolean;
begin
  d := 0;
  while FParser.Token <> toEof do
  begin
    Inc(FCount);
    SetLength(FNode, FCount);
    cf := False;
    FNode[FCount - 1].Token := FParser.Token;
    FNode[FCount - 1].Value := FParser.TokenString;
    case FParser.Token of
      toTag:
        cf := True;
      toEndTag:
        Dec(d);
    end;
    FNode[FCount - 1].Lebel := d;
    if cf then Inc(d);
    FParser.NextToken;
  end;
  FNodeComp := d;
end;

// 正規表現でStrLとSrtRがマッチするか調べる
function TSHParser.CompareRegex(InputStr, ARegExpr: string): boolean;
begin
  Result := ExecRegExpr(ARegExpr, InputStr);
end;

// Tag Attrib="AName"を検索してその中に含まれるコンテンツを返す
// AsTextを省略もしくはTrueを指定した場合はコンテンツ内のテキストだけを
// Falseを指定した場合はタグも含めたHTMLソースを返す
// IsAllがTrueの場合は一致したコンテンツ全てをTFoundListで返す
function TSHParser.FindTagwAttr(Tag, Attrib, AName: string; AsText, IsAll: boolean): TFoundList;
var
  s, atts, st: string;
  i, lv: integer;
begin
  if (Attrib = '') and (AName = '') then
  begin
    Result := FindTag(Tag, AsText, IsAll);
    Exit;
  end;
  FIsAll := IsAll;
  FFoundList.Clear;
  i := 0;
  atts := Attrib + '="' + AName + '"';
  st := '<' + Tag;
  while i < (FCount - 1) do
  begin
    if FNode[i].Token = toTag then
    begin
      if FNode[i].Value = st then
      begin
        lv := FNode[i].Lebel;
        s := '';
        // タグがマッチしたら'>'までの属性や値を再構成する
        while FNode[i].Token <> toEndTag do
        begin
          Inc(i);
          if i = FCount then Break;
          case FNode[i].Token of
            toOption: s := ' ' + s + FNode[i].Value;
            toParam: s := s + FNode[i].Value;
            else Break;
          end;
        end;
        s := s + FNode[i].Value;
        Inc(i);
        if Compareregex(s, atts) then  // 検索パターンがマッチした
        begin
          s := '';
          // マッチしたノードレベル以下の値がそのノードにぶら下がるコンテンツとなるため
          // それらすべてを再連結して返す
          while FNode[i].Lebel > lv do
          begin
            if (Length(s) > 0) and ((s[Length(s)] = '"') and (FNode[i].Value <> '>')) then
              s := s + ' ';
            s := s + FNode[i].Value;
            if (FNode[i].Value[1] = '<') and (FNode[i + 1].Value[1] <> '<') and (FNode[i + 1].Value[1] <> '>') then
              s := s + ' ';
            Inc(i);
            if i = (FCount - 1) then
              Break;
          end;
          // Trueであればテキストだけを返す
          if AsText then
            s := GetText(s);
          FFoundList.Add(s);
          if not IsAll then
            Break;
        end else
          Dec(i); // 次の検索が正しく行われるようにカウンターを一つ戻す
      end;
    end;
    Inc(i);
  end;
  Result := FFoundList;
end;

// Tag内のコンテンツを返す
// AsTextを省略もしくはTrueを指定した場合はコンテンツ内のテキストだけを
// Falseを指定した場合はタグも含めたHTMLソースを返す
// IsAllがTrueの場合は一致したコンテンツ全てをTFoundListで返す
function TSHParser.FindTag(Tag: string; AsText, IsAll: boolean): TFoundList;
var
  s, st: string;
  i, lv: integer;
begin
  FIsAll := IsAll;
  FFoundList.Clear;
  i := 0;
  st := '<' + Tag;
  while i < FCount do
  begin
    if FNode[i].Token = toTag then
    begin
      if FNode[i].Value = st then
      begin
        lv := FNode[i].Lebel;
        s := '';
        Inc(i);
        while FNode[i].Lebel > lv do
        begin
          s := s + FNode[i].Value;
          if (FNode[i].Token = toTag) and (FNode[i + 1].Token <> toEndTag) then
            s := s + ' ';
          Inc(i);
          if i = FCount then Break;
        end;
        if AsText then
          s := getText(s);
        FFoundList.Add(s);
        if not IsAll then
          Break;
      end;
    end;
    Inc(i);
    if i = FCount then Break;
  end;
  Result := FFoundList;
end;

// GetNodeTextでは抽出出来ない場合用
// 正規表現パターンPatternL/PatternRで囲まれたコンテンツを返す
// AsTextを省略もしくはTrueを指定した場合はコンテンツ内のテキストだけを
// Falseを指定した場合はタグも含めたHTMLソースを返す
function TSHParser.FindRegExpr(PatternL, PatternR: string; AsText, IsAll: boolean): TFoundList;
var
  r: TRegExpr;
  ptn, s: string;
begin
  FIsAll := IsAll;
  FFoundList.Clear;

  ptn := PatternL + '[\s\S]*?' + PatternR;
  r := TRegExpr.Create;
  try
    r.Expression  := ptn;
    r.InputString := FHTMLSrc;
    if r.Exec then
      repeat
        s := r.Match[0];
        s := ReplaceRegExpr(PatternR, ReplaceRegExpr(PatternL, s, ''), '');
        if AsText then
          s := getText(s);
        FFoundList.Add(s);
        if not isAll then
          Break;
      until not r.ExecNext;
  finally
    r.Free;
  end;
  Result := FFoundList;
end;

// 旧仕様の互換性維持
function TSHParser.GetNodeText(Tag, Attrib, AName: string; AsText: boolean): string;
var
  lst: TFoundList;
begin
  lst := FindTagwAttr(Tag, Attrib, AName, AsText, False);
  if lst.Count > 0 then
    Result := lst[0]
  else
    Result := '';
end;

// 旧仕様の互換性維持
function TSHParser.GetNodeText(Tag: string; AsText: boolean): string;
var
  lst: TFoundList;
begin
  lst := FindTag(Tag, AsText, False);
  if lst.Count > 0 then
    Result := lst[0]
  else
    Result := '';
end;

// 旧仕様の互換性維持
function TSHParser.GetRegExText(PatternL, PatternR: string; AsText: boolean): string;
var
  lst: TFoundList;
begin
  lst := FindRegExpr(PatternL, PatternR, AsText, False);
  if lst.Count > 0 then
    Result := lst[0]
  else
    Result := '';
end;

// Tag Attrib=ANameでードを検索して最初にマッチしたコンテンツを返す
function TSHParser.Find(Tag, Attrib, AName: string; AsText: boolean): string;
var
  lst: TFoundList;
begin
  lst := FindTagwAttr(Tag, Attrib, AName, AsText, False);
  if lst.Count > 0 then
    Result := lst[0]
  else
    Result := '';
end;

// Tagでードを検索して最初にマッチしたコンテンツを返す
function TSHParser.Find(Tag: string; AsText: boolean = True): string;
var
  lst: TFoundList;
begin
  lst := FindTag(Tag, AsText, False);
  if lst.Count > 0 then
    Result := lst[0]
  else
    Result := '';
end;

// Tag Attrib=ANameでードを検索してマッチした全てのコンテンツを返す
function TSHParser.FindAll(Tag, Attrib, AName: string; AsText: boolean = True): TFoundList; overload;
begin
  Result := FindTagwAttr(Tag, Attrib, AName, AsText, True);
end;

// Tagでードを検索してマッチした全てのコンテンツを返す
function TSHParser.FindAll(Tag: string; AsText: boolean = True): TFoundList; overload;
begin
  Result := FindTag(Tag, AsText, True);
end;

// PattarnLとPatternRで囲われたコンテンツを正規表現検索して最初にマッチしたものを返す
function TSHParser.FindRegex(PatternL, PatternR: string; AsText: boolean = True): string;
var
  lst: TFoundList;
begin
  lst := FindRegExpr(PatternL, PatternR, AsText, False);
  if lst.Count > 0 then
    Result := lst[0]
  else
    Result := '';
end;

// PattarnLとPatternRで囲われたコンテンツを正規表現検索してマッチした全てを返す
function TSHParser.FindRegexAll(PatternL, PatternR: string; AsText: boolean = True): TFoundList; inline;
begin
  Result := FindRegExpr(PatternL, PatternR, AsText, True);
end;

// 取得したコンテンツからテキストだけを抽出する
function TSHParser.GetText(HTMLSrc: string): string;
var
  s: string;
begin
  s := HTMLSrc;
  if Assigned(OnBeforeGetText) then // 前処理
    s := OnBeforeGetText(s);

  if FIsAll then
    s := ReplaceRegExpr('<br.*?>', s, ' ')        // 結果をリストに保存する場合は<br />を改行ではなく半角スペースに置換
  else begin
    s := ReplaceRegExpr('<br.*?>', s, #13#10);    // 結果を単独で返す場合は<br><br/><br />を改行コードに置換
    s := ReplaceRegExpr('<br>', s, #13#10);       
    s := ReplaceRegExpr('< br>', s, #13#10);
  end;
  s := ReplaceRegExpr('<[\s\S]*?>', s, '');            // その他のHTMLタグを除去
  s := StringReplace(s, ' ', '', [rfReplaceAll]); // 半角スペースを除去
  s := Restore2Realchar(s);                       // エスケープされた文字を元に戻す

  if Assigned(OnAfterGetText) then  // 後処理
    s := OnAfterGetText(s);

  Result := s;
end;

// SrcStrから正規表現パターンPattarnL, PattarnR部分を除去した文字列を返す
function TSHParser.GetMaskedContent(SrcStr, PattarnL, PattarnR: string): string; inline;
begin
  Result := ReplaceRegExpr(PattarnR, ReplaceRegExpr(PattarnL, SrcStr, ''), '');
end;

// パースしたすべてのノード数を返す
function TSHParser.GetNodeCount: integer; inline;
begin
  Result := Length(FNode);
end;

// タイトル名にファイル名として使用出来ない文字を'-'に置換する
// Lazarus(FPC)とDelphiで文字コード変換方法が異なるためコンパイル環境で
// 変換処理を切り替える
function TSHParser.PathFilter(PathName: string; PathLength: integer): string;
var
  path, tmp: string;
  wstr: WideString;
begin
  tmp := Restore2Realchar(PathName);
  // ファイル名を一旦ShiftJISに変換して再度Unicode化することでShiftJISで使用
  // 出来ない文字を除去する
{$IFDEF FPC}
  wstr := UTF8ToUTF16(tmp);
  path := UTF16ToUTF8(wstr);      // これでUTF-8依存文字は??に置き換わる
{$ELSE}
  wstr := WideString(tmp);
	path := string(wstr);
{$ENDIF}
  // ファイル名として使用できない文字を'-'に置換する
  path := ReplaceRegExpr('[\\/:;\*\?\+,."<>|\.\t ]', path, '-');

{$IFDEF FPC}
  path := UTF8Copy(path, 1, Pathlength);
{$ELSE}
  path := Copy(path, 1, Pathlength);
{$ENDIF}
  Result := path;
end;

end.

