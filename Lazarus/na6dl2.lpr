(*
  TSHParserを使用したなろう系ダウンローダーサンプル
*)
program na6dl2;

{$IFDEF FPC}
  {$MODE Delphi}
  {$codepage utf8}
{$ENDIF}

uses
  Classes, SysUtils, LazUTF8, RegExpr, 
  WinHTML in '..\winhtml.pas',
  HParse in '..\hparse.pas',
  SHParser in '..\shparser.pas'
{$IFNDEF FPC}
  , LazUTF8Wrap
{$ENDIF}
  ;

type
  TNvStat = record
    NvlStat,
    AuthURL,
    FstDate,
    LstDate,
    FnlDate: string;
    TotalPg: integer;
  end;

const
  VERSION = 'na6dl2 ver1.0 2025/08/25 INOUE, masahiro';

var
  TextBuff, LogFile: TStringList;
  FileName, LogName: string;
  CpTitle: string;
  CookieName,
  CookieData: string;


// なろう系青空文庫準拠形式エンコード
function AozoraDecord(Src: string): string;
var
  tmp: string;
begin
  // 青空文庫形式タグ文字を青空文庫形式でエスケープする
  tmp := UTF8StringReplace(Src, '<rp>《</rp><rt>', '</rb><rp>(</rp><rt>',  [rfReplaceAll]);
  tmp := UTF8StringReplace(tmp, '</rt><rp>》</rp></ruby>', '</rt><rp>)</rp></ruby>',  [rfReplaceAll]);
  tmp := UTF8StringReplace(tmp, '《', '※［＃始め二重山括弧、1-1-52］',  [rfReplaceAll]);
  tmp := UTF8StringReplace(tmp, '》', '※［＃終わり二重山括弧、1-1-53］',  [rfReplaceAll]);
  tmp := UTF8StringReplace(tmp, '｜', '※［＃縦線、1-1-35］',   [rfReplaceAll]);
  // 青空文庫形式で保存する際のルビの変換
  tmp := UTF8StringReplace(tmp,  '<ruby><rb>',          '｜', [rfReplaceAll]);
  tmp := ReplaceRegExpr('</rb><rp>.</rp><rt>', tmp,     '《');
  tmp := ReplaceRegExpr('</rt><rp>.</rp></ruby>', tmp,  '》');
  // 青空文庫形式で保存する際のルビの変換
  tmp := UTF8StringReplace(tmp,  '<ruby>',              '｜', [rfReplaceAll]);
  tmp := ReplaceRegExpr('<rp>.</rp><rt>', tmp,          '《');
  tmp := ReplaceRegExpr('</rt><rp>.</rp></ruby>', tmp,  '》');
  // 埋め込み画像を変換する
  tmp := ReplaceRegExpr('<a href=".*?"><img src="', tmp,#13#10'［＃リンクの図（');
  tmp := ReplaceRegExpr('" alt=.*?/>', tmp,             '）入る］'#13#10);
  // 埋め込みリンクを変換する
  tmp := UTF8StringReplace(tmp, '<a href="',            #13#10'［＃リンク（', [rfReplaceAll]);
  tmp := UTF8StringReplace(tmp, '">挿絵</a>',           '）入る］'#13#10, [rfReplaceAll]);

  Result := tmp;
end;
//-------------------------------------------

function GetNvStat(Src: string): TNvStat;
var
  aurl, res, sn: string;
  pn: integer;
  Parser: TSHParser;
begin
  Result.TotalPg := 0;
  Result.AuthURL := '';
  Parser := TSHParser.Create(Src);
  try
    aurl := Parser.GetRegExText('<a class="c-menu__item c-menu__item--headnav" href="', '">作品情報</a>', False);
  finally
    Parser.Free;
  end;
  res := GetHTML(aurl, CookieName, CookieData);
  Parser := TSHParser.Create(res);
  try
    Result.NvlStat := Parser.GetRegExText('<span class="p-infotop-type__type.*?">', '</span>', False);
    Result.AuthURL := Parser.GetRegExText('<dd class="p-infotop-data__value"><a href="', '">', False);
    Result.FstDate := Parser.GetRegExText('<dt class="p-infotop-data__title">掲載日</dt>.*?">', '</dd>', False);
    Result.FnlDate := Parser.GetRegExText('<dt class="p-infotop-data__title">最終掲載日</dt>.*?">', '</dd>', False);
    Result.LstDate := Parser.GetRegExText('<dt class="p-infotop-data__title">最新掲載日</dt>.*?">', '</dd>', False);
    sn := SysToUTF8(Parser.GetNodeText('span', 'class', 'p-infotop-type__allep', False));
    sn := ReplaceRegExpr('全', ReplaceRegExpr('エピソード', sn, ''), '');
    sn := StringReplace(sn, ',', '', [rfReplaceAll]);
    if sn <> '' then
    begin
      try
        pn := StrToInt(sn);
      except
        pn := 0;
      end;
    end else
      pn := 0;
  finally
    Parser.Free;
  end;
  Result.TotalPg := pn;
end;

// 章タイトルを取得する
function GetChapTitle(HTMLSrc: string): string;
var
  src, res: string;
  r: TRegExpr;
begin
  Result := '';

  src := UTF8StringReplace(HTMLSrc, #13#10, '', [rfReplaceAll]);
  r := TRegExpr.Create;
  try
    r.InputString := src;
    r.Expression  := '<div class="c-announce">.*?</span>';
    if r.Exec then
    begin
      res := r.Match[0];
      res := ReplaceRegExpr('</span>', ReplaceRegExpr('<div class="c-announce">.*?<span>', res, ''), '');
      Result := res;
    end;
  finally
    r.Free;
  end;
end;

// 各話の本文を取得する
function GetBody(HTMLSrc: string): string;
var
  Parser: TSHParser;
  txt, res, chap: string;
begin
  txt := '';
  chap := GetChapTitle(HTMLSrc);
  if chap <> '' then
  begin
    // 章タイトルがある
    if chap <> CpTitle then
    begin
      CpTitle := chap;
      txt := '［＃大見出し］' + chap + '［＃大見出し終わり］'#13#10;
    end;
  end;
  Result := '';
  Parser := TSHParser.Create(HTMLSrc);
  try
    // テキスト化の前処理を登録する
    Parser.OnBeforeGetText := @AozoraDecord;

    res := Parser.GetNodeText('h1', 'class', 'p-novel__title p-novel__title--rensai');
    if res <> '' then
      txt := txt + '［＃中見出し］' + res + '［＃中見出し終わり］'#13#10;
    // 前書き
    res := Parser.GetNodeText('div', 'class', 'js-novel-text p-novel__text p-novel__text--preface');
    if res <> '' then
      txt := txt + '［＃ここから罫囲み］'#13#10 + res + #13#10'［＃ここで罫囲み終わり］'#13#10'［＃水平線］'#13#10;
    // 本文
    res := Parser.GetNodeText('div', 'class', 'js-novel-text p-novel__text');
    txt := txt + res + #13#10;
    // 後書き
    res := Parser.GetNodeText('div', 'class', 'js-novel-text p-novel__text p-novel__text--afterword');
    if res <> '' then
      txt := txt + '［＃水平線］'#13#10'［＃ここから罫囲み］'#13#10 + res + #13#10'［＃ここで罫囲み終わり］'#13#10;
    // ページ終わり
    txt := txt + '［＃改ページ］';
    Result := txt;
  finally
    Parser.Free;
  end;
end;

procedure NarouDL(URLAddr: string);
var
  res, aurl, txt, title, author, st: string;
  stat: TNvStat;
  i: integer;
  Parser: TSHParser;
  r: TRegExpr;
  isShort: boolean;
begin
  res := GetHTML(URLAddr, CookieName, CookieData);
  // トップページ
  stat :=  GetNvStat(res);
  isShort := stat.NvlStat = '短編';
  st := '【' + stat.NvlStat + '】';
  Parser := TSHParser.Create(res);
  try
    // テキスト化の前処理を登録する
    Parser.OnBeforeGetText := @AozoraDecord;
    title := Parser.GetNodeText('h1', 'class', 'p-novel__title');
    // ファイル名を準備する
    FileName := Parser.PathFilter(title);
    LogName  := st + FileName + '.log';
    FileName := st + FileName + '.txt';

    TextBuff.Add(st + Title);
    author := Parser.GetNodeText('div', 'class', 'p-novel__author', False);
    author := ReplaceRegExpr('<.*?>', ReplaceRegExpr('作者：', author, ''), '');
    TextBuff.Add(author);
    txt := Parser.GetNodeText('div', 'class', 'p-novel__summary');
    if txt <> '' then
      TextBuff.Add('［＃ここから罫囲み］'#13#10 + txt + #13#10 + '［＃ここで罫囲み終わり］'#13#10'［＃改ページ］')
    else
      TextBuff.Add('［＃改ページ］');
    LogFile.Add('小説URL   :' + URLAddr);
    LogFile.Add('タイトル  :' + st + title);
    LogFile.Add('作者      :' + author);
    LogFile.Add('作者URL   :' + stat.AuthURL);
    LogFile.Add('掲載日    :' + stat.FstDate);
    if stat.FnlDate <> '' then
      LogFile.Add('最終掲載日:' + stat.FnlDate)
    else if stat.LstDate <> '' then
      LogFile.Add('最新掲載日:' + stat.LstDate);
    LogFile.Add('あらすじ');
    LogFile.Add(txt + #13#10);
    LogFile.Add(DateToStr(Now));
  finally
    Parser.Free;
  end;
  // 短編の処理
  if isShort then
  begin
    r := TRegExpr.Create;
    try
      r.InputString := res;
      r.Expression  := '<article class="p-novel">.*?</article>';
      if r.Exec then
        res := r.Match[0];
    finally
      r.Free;
    end;
    TextBuff.Add('［＃中見出し］' + title + '［＃中見出し終わり］');
    TextBuff.Add(GetBody(res));
    Writeln('短編のエピソードを取得しました.');
    Exit;
  end;
  Writeln('全' + IntToStr(stat.TotalPg) + 'ページ');
  Write('各話を取得中 [  0/' + Format('%3d', [stat.TotalPg]) + ']');
  CpTitle := '';  // 章タイトル検出用
  // 各話を取得する
  for i := 1 to stat.TotalPg do
  begin
    Write(#13'各話を取得中 [' + Format('%3d', [i]) + '/' + Format('%3d', [stat.TotalPg]) +']');
    aurl := URLAddr + IntToStr(i) + '/';
    res := GetHTML(aurl, CookieName, CookieData);
    r := TRegExpr.Create;
    try
      r.InputString := res;
      r.Expression  := '<div class="c-announce">.*?</article>';
      if r.Exec then
        res := r.Match[0];
    finally
      r.Free;
    end;
    txt := GetBody(res); // 本文を取得する
    TextBuff.Add(txt);
    Sleep(500);
  end;
  Writeln(#13#10' ... ' + IntToStr(stat.TotalPg) + ' 個のエピソードを取得しました.');
end;

var
  aurl: string;
begin
  if ParamCount = 0 then
  begin
    Writeln('');
    Writeln(VERSION);
    Writeln('  使用方法');
    Writeln('  na6dl2 小説トップページURL');
    Exit;
  end;

  aurl := ParamStr(1);
  if (UTF8Pos('https://ncode.syosetu.com/n', aurl) <> 1) and (UTF8Pos('https://novel18.syosetu.com/n', aurl) <> 1) then
  begin
    Writeln('小説のURLが違います.');
    ExitCode := -1;
    Exit;
  end;
  // ノクターン系かどうか
  CookieName := ''; CookieData := '';
  if UTF8Pos('https://novel18.syosetu.com/n', aurl) = 1 then
  begin
    CookieName := 'over18';
    CookieData := 'yes';
  end;

  TextBuff := TStringList.Create;
  LogFile  := TStringList.Create;
  try
    Write('小説情報を取得中 ' + aurl + ' ... ');
    NarouDL(aurl);
    TextBuff.SaveToFile(FileName, TEncoding.UTF8);
    LogFile.SaveToFile(LogName, TEncoding.UTF8);
  finally
    TextBuff.Free;
    LogFile.Free;
  end;
  Writeln('終了しました.');
end.

