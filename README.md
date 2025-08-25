## SimpleHTMLParser

### 説明
Delphi/Lazarus用のシンプルなHTMLパーサーです。<br>
HTMLパーサーのコアとしてFDELPHIサンプル蔵アーカイブ(https://delfusa.main.jp/delfusafloor/archive/www.nifty.ne.jp_forum_fdelphi/samples/00953.html)のHTML Parserユニット(一部修正したもの)を使用します。このユニットの作者はTEditorの開発者でもある本田勝彦氏です。<br>
SHParser内蔵のテキスト変換前と後に自前処理用のコールバック関数を登録出来るようにしました。

```Delphi

uses
  SHParser;

// テキスト変換時のコールバック処理用
function MyDecorder(Src: string): string;
var
  tmp: string;
begin
  // 青空文庫形式で保存する際のルビの変換
  tmp := StringReplace(Src, '<ruby><rb>', '｜', [rfReplaceAll]);
  tmp := ReplaceRegExpr('</rb><rp>.</rp><rt>', tmp, '《');
  tmp := ReplaceRegExpr('</rt><rp>.</rp></ruby>', tmp, '》');
  Result := tmp;
end;

var
  Parser: TSHParser;
  res: string;
begin
  Parser := TSHParser.Create(HTMLSource);
  try
    Parser.OnBeforeGetText := @MyDecorder;  // SHParserのテキスト変換前に自前の変換処理を登録する
    res := Parser.GetNodeText('div', 'class', 'p-novel__summary');
    Writeln(res);
  finally
    Parser.Free;
  end;
end;
```

詳細はDelphiもしくはLazarsuフォルダ内のサンプルプロジェクトを参照してください。<br>
このサンプルプロジェクトはURLに小説家になろう作品のトップページURLを入力してDonloadボタンを押すことでその作品をダウンロードします。<br>
<br>
Lazarusフォルダ内にあるna6dl2プロジェクトはTSHParserを使用したなろう系ダウンローダーサンプルです。<br>


