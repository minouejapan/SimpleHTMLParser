﻿(*
  TSHParserを使用したなろう系作品テキストダウンローダー
  na6dl2.exe (HTML解析をSHParserで刷新したためna6dl2と命名)
  LazarusにてWindows版とLinux版をビルド可能(Windows版はDelphiでもビルド可能かも)
  必要なライブラリ：
    SHParser:https://github.com/minouejapan/SimpleHTMLParser
    TRegExpr:https://github.com/andgineer/TRegExpr

  ver1.0  2025/09/07 SHParserサンプルに対してna6dlと同等機能を実装した

*)
program na6dl2;

{$IFDEF FPC}
  {$MODE DELPHI}
  {$CODEPAGE UTF8}
{$ELSE}
  {$APPTYPE CONSOLE}
{$ENDIF}

uses
  Classes, SysUtils, RegExpr,
  {$IFDEF WINDOWS}
    Windows,
  {$ENDIF}
  UniHtml, // GetHTML
  HParse,
  SHParser
  {$IFNDEF FPC}
    ,LazUTF8Wrap
  {$ELSE}
    ,LazUTF8
  {$ENDIF}
  ;

{$R *.res}
{$R na6dl2ver.res}


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
  VERSION = 'na6dl2 ver1.0 2025/09/07 INOUE, masahiro';
{$IFDEF LINUX}
  CRLF = #10;
{$ELSE}
  CRLF = #13#10;
{$ENDIF}
{$IFDEF WINDOWS}
  // ユーザメッセージID
  WM_DLINFO  = WM_USER + 30;
{$ENDIF}

var
  TextBuff, LogFile: TStringList;
  FileName, LogName, StartPage: string;
  CpTitle: string;
  CookieName,
  CookieData: string;
  hWnd: THandle;
  StartN: integer;


// なろう系青空文庫準拠形式エンコード
// TSHParserのOnBeforeGetTextから呼ばれる
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
  tmp := UTF8StringReplace(tmp,  '<ruby><rb>', '｜', [rfReplaceAll]);
  tmp := ReplaceRegExpr('</rb><rp>.</rp><rt>', tmp, '《');
  tmp := ReplaceRegExpr('</rt><rp>.</rp></ruby>', tmp, '》');
  // 青空文庫形式で保存する際のルビの変換
  tmp := UTF8StringReplace(tmp,  '<ruby>', '｜', [rfReplaceAll]);
  tmp := ReplaceRegExpr('<rp>.</rp><rt>', tmp, '《');
  tmp := ReplaceRegExpr('</rt><rp>.</rp></ruby>', tmp, '》');
// 埋め込み画像を変換する
  tmp := ReplaceRegExpr('<a href=".*?"><img src="', tmp, CRLF + '［＃リンクの図（');
  tmp := ReplaceRegExpr('" alt=.*?/>', tmp, '）入る］' + CRLF);
// 埋め込みリンクを変換する
  tmp := UTF8StringReplace(tmp, '<a href="', CRLF + '［＃リンク（', [rfReplaceAll]);
  tmp := UTF8StringReplace(tmp, '">挿絵</a>', '）入る］' + CRLF, [rfReplaceAll]);
  Result := tmp;
end;

// 作品情報取得
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
    aurl := Parser.FindRegex('<a class="c-menu__item c-menu__item--headnav" href="', '">作品情報</a>', False);
  finally
    Parser.Free;
  end;
  res := GetHTML(aurl, CookieName, CookieData);
  Parser := TSHParser.Create(res);
  try
    Result.NvlStat := Parser.FindRegex('<span class="p-infotop-type__type.*?">', '</span>', False);
    Result.AuthURL := Parser.FindRegex('<dd class="p-infotop-data__value"><a href="', '">', False);
    Result.FstDate := Parser.FindRegex('<dt class="p-infotop-data__title">掲載日</dt>.*?">', '</dd>', False);
    Result.FnlDate := Parser.FindRegex('<dt class="p-infotop-data__title">最終掲載日</dt>.*?">', '</dd>', False);
    Result.LstDate := Parser.FindRegex('<dt class="p-infotop-data__title">最新掲載日</dt>.*?">', '</dd>', False);
{$IFDEF FPC}
    sn := SysToUTF8(Parser.Find('span', 'class', 'p-infotop-type__allep', False));
{$ELSE}
    sn := Parser.Find('span', 'class', 'p-infotop-type__allep', False);
{$ENDIF}
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
  // 実行環境がlIBUXの場合も想定してCRLFをCRとLFそれぞれで削除する
  src := UTF8StringReplace(HTMLSrc, #13, '', [rfReplaceAll]);
  src := UTF8StringReplace(HTMLSrc, #10, '', [rfReplaceAll]);
  r := TRegExpr.Create;
  try
    r.InputString := src;
    r.Expression  := '<span>.*?</span></div><!--/.c-announce-->';
    if r.Exec then
    begin
      res := r.Match[0];
      res := ReplaceRegExpr('<span>', ReplaceRegExpr('</span></div><!--/.c-announce-->', res, ''), '');
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
      txt := '［＃大見出し］' + chap + '［＃大見出し終わり］' + CRLF;
    end;
  end;
  Result := '';
  Parser := TSHParser.Create(HTMLSrc);
  try
    // テキスト化の前処理を登録する
    Parser.OnBeforeGetText := @AozoraDecord;

    res := Parser.Find('h1', 'class', 'p-novel__title p-novel__title--rensai');
    if res <> '' then
      txt := txt + '［＃中見出し］' + res + '［＃中見出し終わり］'+ CRLF;
    // 前書き
    res := Parser.Find('div', 'class', 'js-novel-text p-novel__text p-novel__text--preface');
    if res <> '' then
      txt := txt + '［＃ここから罫囲み］' + CRLF + res + CRLF + '［＃ここで罫囲み終わり］' + CRLF + '［＃水平線］' + CRLF;
    // 本文
    res := Parser.Find('div', 'class', 'js-novel-text p-novel__text');
    txt := txt + res + CRLF;
    // 後書き
    res := Parser.Find('div', 'class', 'js-novel-text p-novel__text p-novel__text--afterword');
    if res <> '' then
      txt := txt + '［＃水平線］' + CRLF + '［＃ここから罫囲み］' + CRLF + res + CRLF + '［＃ここで罫囲み終わり］' + CRLF;
    // ページ終わり
    txt := txt + '［＃改ページ］';
    Result := txt;
  finally
    Parser.Free;
  end;
end;

procedure NarouDL(URLAddr: string);
var
  res, aurl, txt, title, author, st, sendstr: string;
  stat: TNvStat;
  i: integer;
  Parser: TSHParser;
  r: TRegExpr;
  isShort: boolean;
{$IFDEF FPC}
  ws: WideString;
{$ENDIF}
{$IFDEF WINDOWS}
  CDS: TCopyDataStruct;
  conhdl: THandle;
{$ENDIF}
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
    title := Parser.Find('h1', 'class', 'p-novel__title');
    // ファイル名を準備する
    if FileName = '' then
    begin
      FileName := Parser.PathFilter(title);
      LogName  := st + FileName + '.log';
      FileName := st + FileName + '.txt';
    end else begin
      LogName := ChangeFileExt(FileName, '.log');
    end;
    TextBuff.Add(st + Title);
    author := Parser.Find('div', 'class', 'p-novel__author', False);
    author := ReplaceRegExpr('<.*?>', ReplaceRegExpr('作者：', author, ''), '');
    TextBuff.Add(author);
    txt := Parser.Find('div', 'class', 'p-novel__summary');
    if txt <> '' then
      TextBuff.Add('［＃ここから罫囲み］' + CRLF + txt + CRLF + '［＃ここで罫囲み終わり］' + CRLF + '［＃改ページ］')
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
    LogFile.Add(txt + CRLF);
    LogFile.Add(DateToStr(Now));
{$IFDEF WINDOWS}
    // Naro2mobiから呼び出された場合は進捗状況をSendする
    if hWnd <> 0 then
    begin
      conhdl := GetStdHandle(STD_OUTPUT_HANDLE);
      sendstr := title + ',' + author;
      Cds.dwData := Stat.TotalPg - StartN + 1;
    {$IFDEF FPC}
      ws := UTF8ToUTF16(sendstr);
      Cds.cbData := ByteLength(ws) + 2;
      Cds.lpData := PWideChar(ws);
    {$ELSE}
      Cds.cbData := (UTF8Length(sendstr) + 1) * SizeOf(Char);
      Cds.lpData := Pointer(sendstr);
    {$ENDIF}
      SendMessage(hWnd, WM_COPYDATA, conhdl, LPARAM(Addr(Cds)));
    end;
{$ENDIF}
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
  for i := StartN to stat.TotalPg do
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
{$IFDEF WINDOWS}
    if hWnd <> 0 then
      SendMessage(hWnd, WM_DLINFO, i - StartN + 1, 1);
{$ENDIF}
    Sleep(500);
  end;
  Writeln(CRLF+ ' ... ' + IntToStr(stat.TotalPg) + ' 個のエピソードを取得しました.');
end;

var
  aurl, op: string;
  i: integer;


begin
  if ParamCount = 0 then
  begin
    Writeln('');
    Writeln(VERSION);
    Writeln('  使用方法');
    Writeln('  na6dl2 小説トップページURL');
    ExitCode := -1;
    Exit;
  end;
  StartN := 1;
  ExitCode := 0;
  // オプション引数取得
  for i := 0 to ParamCount - 1 do
  begin
    op := ParamStr(i + 1);
    // Naro2mobiのWindowsハンドル
    if UTF8Pos('-h', op) = 1 then
    begin
      UTF8Delete(op, 1, 2);
      try
        hWnd := StrToInt(op);
      except
        Writeln('Error: Invalid Naro2mobi Handle.');
        ExitCode := -1;
        Exit;
      end;
    // DL開始ページ番号
    end else if UTF8Pos('-s', op) = 1 then
    begin
      UTF8Delete(op, 1, 2);
      StartPage := op;
      try
        StartN := StrToInt(op);
      except
        Writeln('Error: Invalid Start Page Number.');
        ExitCode := -1;
        Exit;
      end;
    // 作品URL
    end else if UTF8Pos('https:', op) = 1 then
    begin
      aurl := op;
      if UTF8Copy(aurl, UTF8Length(aurl), 1) <> '/' then
        aurl := aurl + '/';
    // それ以外であれば保存ファイル名
    end else begin
      FileName := op;
      if UTF8UpperCase(ExtractFileExt(op)) <> '.TXT' then
        FileName := FileName + '.txt';
    end;
  end;

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

