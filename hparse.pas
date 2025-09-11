(*
  FDELPHIサンプル蔵 HTML Parser (Copyright 1996-2002 Delphi Users' Forum)
  https://delfusa.main.jp/delfusafloor/archive/www.nifty.ne.jp_forum_fdelphi/samples/00953.html
  Original Copyright by 本田勝彦
  Modified by INOUE, masahiro

  2025/09/11  終点タグがない全てのタグを処理するようにした
  2025/09/09  <brの処理がbodyタグ識別を妨げていた不具合を修正した
              <hr>タグの処理を追加した
  2025/09/06  メモリリークを修正した
  2025/08/24  タグ終端"/>"の処理を追加した
  2025/08/22  Lazarusでも使用出来るように小修整
*)
unit HParse;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}
{$V+,B-,X+,T-,P+,H+,J+}

interface

uses
  Classes, SysUtils;

{ THParser }

const
  toEof        = AnsiChar(0);
  toTag        = AnsiChar(25); { <xxxx }
  toOption     = AnsiChar(26); { xxxxxx }
  toParam      = AnsiChar(27); { ="xxxx" }
  toEndTag     = AnsiChar(28); { </xxxx> }
  toCommentTag = AnsiChar(29); { <!-- xx --> }
  toContext    = AnsiChar(30); { xxxx }

type
  THParser = class(TObject)
  protected
    FBuffer: PAnsiChar;
    FBufSize: Integer;
    FInTag: Boolean;
    FSourcePtr: PAnsiChar;
    FTokenPtr: PAnsiChar;
    FToken: AnsiChar;
    procedure SkipBlanks; virtual;
  public
    constructor Create(const S: String);
    destructor Destroy; override;
    function NextToken: AnsiChar; virtual;
    function SourcePos: Longint;
    function TokenString: String;
    property Token: AnsiChar read FToken;
  end;

implementation

{ THParser }

constructor THParser.Create(const S: String);
var
  str: AnsiString;
begin
  if Length(S) = 0 then
    Exit;
  str := StringReplace(S, #13#10, '', [rfReplaceAll]);
{$IFDEF FPC}
  FBufSize := Length(str) + 2;
{$ELSE}
  str := AnsiString(ss);
  FBufSize := Length(str) + 2; // Delphiはマルチバイト文字も1文字とカウントするためByteLengthを使用する
{$ENDIF}
  GetMem(FBuffer, FBufSize);
  FillByte(FBuffer^, FBufSize, 0);
  Move(str[1], FBuffer[0], FBufSize - 2);
  FSourcePtr := FBuffer;
  FTokenPtr := FBuffer;
  NextToken;
end;

destructor THParser.Destroy;
begin
  if Assigned(FBuffer) then
    FreeMem(FBuffer, FBufSize);
end;

procedure THParser.SkipBlanks;
begin
  while True do
  begin
    case FSourcePtr^ of
      #0:
        Exit;
      #33..#255:
        Exit;
    end;
    Inc(FSourcePtr);
  end;
end;

function THParser.SourcePos: Longint;
begin
  Result := FTokenPtr - FBuffer;
end;

function THParser.TokenString: string;
begin
  SetString(Result, FTokenPtr, FSourcePtr - FTokenPtr);
end;

function THParser.NextToken: AnsiChar;
var
  P: PAnsiChar;
  tag1, tag2:AnsiString;
  ps:integer;
begin
  SkipBlanks;
  P := FSourcePtr;
  FTokenPtr := P;
  if not FInTag then
    case P^ of
      '<':
        begin
          Inc(P);
          case P^ of
            '!':
              begin
                if Copy(String(P), 1, 3) = '!--' then
                begin
                  Result := toCommentTag;
                  Inc(P);
                  while True do
                  begin
                    if (P^ = #0) or
                       ((P^ = '-') and
                        (Copy(String(P), 1, 3) = '-->')) then
                    begin
                      while not (P^ in [#0, '>']) do Inc(P);
                      Break;
                    end;
                    Inc(P);
                  end;
                  if P^ = '>' then Inc(P);
                end else
                  Result := '<';
              end;
            '/':
              begin
                Result := toEndTag;
                //FInTag := True;
                while not (P^ in [#0, '>']) do Inc(P);
                if P^ = '>' then Inc(P);
              end;
            'A'..'Z', 'a'..'z':
              begin
                // 終了タグがないタグとscriptタグの場合はコメントと同じ扱いで一括りにする
                tag1 := LowerCase(P^ + (P+1)^);
                tag2 := LowerCase(P^ + (P+1)^ + (P+2)^);
                // 誤判定しないよう先頭からマッチしているかチェックする
                ps := Pos(tag2, 'script img    meta   input  embed  area   base   col    keygen link   param  source') mod 7;
                if (tag1 = 'br') or (tag1 = 'hr') or (ps = 1) then
                begin
                  Result := toCommentTag;
                  if tag2 = 'scr' then // <script>.....</script>を一纏めにする
                  begin
                    while ((P^ <> #0) and (LowerCase(P^ + (P+1)^ + (P+2)^ + (P+3)^) <> '</sc')) do Inc(P);
                    Inc(P); Inc(P); Inc(P);
                    while not (P^ in [#0, '>']) do Inc(P);
                    if P^ = '>' then Inc(P);
                  end else begin
                    while not (P^ in [#0, '>']) do Inc(P);
                    if P^ = '>' then Inc(P);
                  end;
                end else begin
                  Result := toTag;
                  FInTag := True;                  // <hの場合1～6が分離されないよう'1'..'6'を追加
                  while P^ in ['A'..'Z', 'a'..'z', '1'..'6'] do Inc(P);
                end;
              end;
            else
              Result := '<';
          end;
        end;
      '/':  // xzxx />の処理
        begin
          Result := toEndTag;
          while not (P^ in [#0, '>']) do Inc(P);
          if P^ = '>' then Inc(P);
        end;
      #33..#46, #48..#59, #61..#255:
        begin
          Result := toContext;
          while not (P^ in [#0, '<']) do Inc(P);
        end;
      else
        Result := P^;
      if Result <> toEof then Inc(P);
    end else begin
      case P^ of
        '/':  // タグ終端 />の処理
          begin
            Result := toEndTag;
            while not (P^ in [#0, '>']) do Inc(P);
            if P^ = '>' then Inc(P);
          end;
        'A'..'Z', 'a'..'z':
          begin
            Inc(P);
            Result := toOption;
            while P^ in ['A'..'Z', 'a'..'z'] do Inc(P);
          end;
        '=':
          begin
            Inc(P);
            Result := toParam;
            if P^ = '"' then
            begin
              Inc(P);
              while not (P^ in [#0, '"']) do Inc(P);
              if P^ = '"' then Inc(P);
            end else
              while P^ in [#33..#59, #61, #63..#126] do Inc(P);
          end;
        else
          Result := P^;
        if Result <> toEof then Inc(P);
      end;
    if Result in ['<', '>'] then FInTag := False;
  end;
  FSourcePtr := P;
  FToken := Result;
end;

end.

