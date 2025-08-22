(*
  HParserを使用した簡易HTMLパーサー(Delphi/Lazarus共用)
  TRegExpr:https://github.com/andgineer/TRegExpr

  ver1.0 2025/08/22 初版
*)
unit SHParser;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  Classes, SysUtils, HParse, RegExpr;

type
  TNodeInfo = record
    Token: AnsiChar;
    Value: string;
    Lebel: integer;
  end;
  TNodeArray = array of TNodeInfo;

  TSHParser = class(TObject)
  protected
    FParser: THParser;
    FNode: TNodeArray;
    FCount: integer;
    FHTMLSrc: string;
    procedure InitNode;
    function GetNodeCount: integer;
  public
    constructor Create(const HTML: String);
    destructor Destroy; override;
    function GetNodeText(Tag, Attrib, AName: string; AsText: boolean = True): string; overload;
    function GetNodeText(Tag: string; AsText: boolean = True): string; overload;
    function GetRegExText(PatternL, PatternR: string; AsText: boolean = True): string;
    function GetText(Src: string): string;
    property Node: TNodeArray read FNode;
    property NodeCount: integer read GetNodeCount;
  end;


implementation

constructor TSHParser.Create(const HTML: string);
var
  s: string;
begin
  FHTMLSrc := HTML;
  // HTML内の改行を削除する
  s := ReplaceRegExpr(#13#10, HTML, '');
  FParser := THParser.Create(s);
  FCount := 0;
  // 喉データを構成する
  InitNode;
end;

destructor TSHParser.Destroy;
begin
  if Assigned(FParser) then
    FParser.Free;
  SetLength(FNode, 0);
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

end;

// Tag Attrib="AName"を検索してその中に含まれるコンテンツを返す
// AsTextを省略もしくはTrueを指定した場合はコンテンツ内のテキストだけを
// Falseを指定した場合はタグも含めたHTMLソースを返す
function TSHParser.GetNodeText(Tag, Attrib, AName: string; AsText: boolean): string;
var
  s, atts, st: string;
  i, lv: integer;
begin
  if (Attrib = '') and (AName = '') then
  begin
    Result := GetNodeText(Tag, AsText);
    Exit;
  end;
  Result := '';
  i := 0;
  atts := Attrib + '="' + AName + '"';
  st := '<' + Tag;
  while i < FCount do
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
        if Pos(atts, s) > 0 then  // 検索パターンがマッチした
        begin
          s := '';
          // マッチしたノードレベル以下の値がそのノードにぶら下がるコンテンツとなるため
          // それらすべてを再連結して返す
          while FNode[i].Lebel > lv do
          begin
            s := s + FNode[i].Value;
            Inc(i);
            if i = FCount then Break;
          end;
          // Trueであればテキストだけを返す
          if AsText then
            s := getText(s);
          Result := s;
          Break;
        end else
          Dec(i); // 次の検索が正しく行われるようにカウンターを一つ戻す
      end;
    end;
    Inc(i);
    if i = FCount then Break;
  end;
end;

// Tag内のコンテンツを返す
// AsTextを省略もしくはTrueを指定した場合はコンテンツ内のテキストだけを
// Falseを指定した場合はタグも含めたHTMLソースを返す
function TSHParser.GetNodeText(Tag: string; AsText: boolean): string;
var
  s, st: string;
  i, lv: integer;
begin
  Result := '';
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
          Inc(i);
          if i = FCount then Break;
        end;
        if AsText then
          s := getText(s);
        Result := s;
        Break;
      end;
    end;
    Inc(i);
    if i = FCount then Break;
  end;
end;

// 正規表現を用いてetNodeTextでは抽出出来ないテキスト用
// 正規表現パターンPatternL/PatternRで囲まれたコンテンツを返す
// AsTextを省略もしくはTrueを指定した場合はコンテンツ内のテキストだけを
// Falseを指定した場合はタグも含めたHTMLソースを返す
function TSHParser.GetRegExText(PatternL, PatternR: string; AsText: boolean): string;
var
  r: TRegExpr;
  ptn, s: string;
begin
  Result := '';

  ptn := PatternL + '.*?' + PatternR;
  r := TRegExpr.Create;
  try
    r.Expression  := ptn;
    r.InputString := FHTMLSrc;
    if r.Exec then
    begin
      s := r.Match[0];
      s := ReplaceRegExpr(PatternR, ReplaceRegExpr(PatternL, s, ''), '');
      if AsText then
        s := getText(s);
      Result := s;
    end;
  finally
    r.Free;
  end;
end;

function TSHParser.GetText(Src: string): string;
var
  s: string;
begin
  s := ReplaceRegExpr('<br.*?>', Src, #13#10);
  s := ReplaceRegExpr('<.*?>', s, '');
  Result := s;
end;

function TSHParser.GetNodeCount: integer;
begin
  Result := Length(FNode);
end;


end.

