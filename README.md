## SimpleHTMLParser

### 説明
Delphi/Lazarus用のシンプルなHTMLパーサーです。<br>
HTMLパーサーのコアとしてFDELPHIサンプル蔵アーカイブ(https://delfusa.main.jp/delfusafloor/archive/www.nifty.ne.jp_forum_fdelphi/samples/00953.html)のHTML Parserユニット(一部修正したもの)を使用します。<br>

```Delphi

uses
  SHParser;

var
  Parser: TSHParser;
  res: string;
begin
  Parser := TSHParser.Create(HTMLSource);
  try
    res := Parser.GetNodeText('div', 'class', 'p-novel__summary');
    Writeln(res);
  finally
    Parser.Free;
  end;
end;
```

詳細はDelphiもしくはLazarsuフォルダ内のサンプルプロジェクトを参照してください。<br>
このサンプルプロジェクトはURLに小説家になろう作品のトップページURLを入寮してDonloadボタンを押すことでその作品をダウンロードします。

