{
  LazHTMLParserサンプル
  小説家になろう簡易ダウンローダー
}
unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, RegExpr;

type
  TNvStat = record
    NvlStat,
    AuthURL: string;
    TotalPg: integer;
  end;

  { TForm1 }
  TForm1 = class(TForm)
    Button1: TButton;
    URL: TEdit;
    Label1: TLabel;
    Memo1: TMemo;
    procedure Button1Click(Sender: TObject);
  private
    function GetNvStat(Src: string): TNvStat;
    procedure NarouDL(URLAddr: string);
  public

  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

uses
  SHParser, WinHTML;

{ TForm1 }

function TForm1.GetNvStat(Src: string): TNvStat;
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
  res := GetHTML(aurl);
  Parser := TSHParser.Create(res);
  try
    Result.NvlStat := Parser.GetRegExText('<span class="p-infotop-type__type.*?">', '</span>', False);
    Result.AuthURL := Parser.GetRegExText('<dd class="p-infotop-data__value"><a href="', '">', False);
    sn := Parser.GetNodeText('span', 'class', 'p-infotop-type__allep', False);
    sn := ReplaceRegExpr('全', ReplaceRegExpr('エピソード', sn, ''), '');
    sn := StringReplace(sn, ',', '', [rfReplaceAll]);
    try
      pn := StrToInt(sn);
    except
      pn := 0;
    end;
  finally
    Parser.Free;
  end;
  Result.TotalPg := pn;
end;

procedure TForm1.NarouDL(URLAddr: string);
var
  res, aurl, txt: string;
  stat: TNvStat;
  i: integer;
  Parser: TSHParser;
  r: TRegExpr;
begin
  res := GetHTML(URLAddr);
  // トップページ
  stat :=  GetNvStat(res);
  Parser := TSHParser.Create(res);
  try
    txt := Parser.GetNodeText('h1', 'class', 'p-novel__title');
    Memo1.Lines.Add('【' + stat.NvlStat + '】' + txt);
    txt := Parser.GetNodeText('div', 'class', 'p-novel__author');
    txt := StringReplace(txt, '作者：', '', []);
    Memo1.Lines.Add(txt);
    txt := Parser.GetNodeText('div', 'class', 'p-novel__summary');
    Memo1.Lines.Add('［＃ここから罫囲み］'#13#10 + txt + #13#10 + '［＃ここで罫囲み終わり］'#13#10'［＃改ページ］');
  finally
    Parser.Free;
  end;
  // 各話を取得する
  for i := 1 to stat.TotalPg do
  begin
    aurl := URLAddr + IntToStr(i) + '/';
    res := GetHTML(aurl);
    r := TRegExpr.Create;
    try
      r.InputString := res;
      r.Expression  := '<article class="p-novel">.*?</article>';
      if r.Exec then
        res := r.Match[0];
    finally
      r.Free;
    end;
    Parser := TSHParser.Create(res);
    try
      txt := Parser.GetNodeText('h1', 'class', 'p-novel__title p-novel__title--rensai');
      Memo1.Lines.Add('［＃中見出し］' + txt + '［＃中見出し終わり］');
      txt := Parser.GetNodeText('div', 'class', 'js-novel-text p-novel__text');
      Memo1.Lines.Add(txt + #13#10 + '［＃改ページ］');
    finally
      Parser.Free;
    end;
    Application.ProcessMessages;
    Sleep(500);
  end;
end;

procedure TForm1.Button1Click(Sender: TObject);
var
  aurl: string;
  re: TRegExpr;
begin
  Button1.Enabled := False;
  Memo1.Lines.Clear;

  aurl := URL.Text;
  re := TregExpr.Create;
  try
    Re.Expression := '^https://ncode.syosetu.com/n\d{4}\w{1,2}/';
    Re.InputString:= aurl;
    if not Re.Exec then
      Memo1.Lines.Add('URLが違います.')
    else
      NarouDL(aurl);
  finally
    re.Free;
  end;
  Button1.Enabled := True;
end;

end.

