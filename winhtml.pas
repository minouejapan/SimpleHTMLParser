unit WinHTML;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  Classes, SysUtils, Windows, WinINet;

const
  UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';

function GetHTML(const AURL: string): string;
function SetCookie(const AURL, CookieName, CookieData: string): Boolean;

implementation

// WinINetを用いたHTMLファイルのダウンロード
function GetHTML(const AURL: string): string;
var
  hSession    : HINTERNET;
  hService    : HINTERNET;
  dwBytesRead : DWORD;
  dwFlag      : DWORD;
  lpBuffer    : PChar;
  RBuff       : TMemoryStream;
  TBuff       : TStringList;
begin
  Result   := '';
  hSession := InternetOpen(PChar(UA), INTERNET_OPEN_TYPE_PRECONFIG, nil, nil, 0);
  if Assigned(hSession) then
  begin
    InternetSetOption(hSession, INTERNET_OPTION_USER_AGENT, PChar(ua), Length(ua));
    dwFlag   := INTERNET_FLAG_RELOAD;
    hService := InternetOpenUrl(hSession, PChar(AURL), nil, 0, dwFlag, 0);
    if Assigned(hService ) then
    begin
      RBuff := TMemoryStream.Create;
      try
        lpBuffer := AllocMem(65536);
        try
          dwBytesRead := 65535;
          while True do
          begin
            if InternetReadFile(hService, lpBuffer, 65535,{SizeOf(lpBuffer),}dwBytesRead) then
            begin
              if dwBytesRead = 0 then
                break;
              RBuff.WriteBuffer(lpBuffer^, dwBytesRead);
            end else
              break;
          end;
        finally
          FreeMem(lpBuffer);
        end;
        TBuff := TStringList.Create;
        try
          RBuff.Position := 0;
          TBuff.LoadFromStream(RBuff, TEncoding.UTF8);
          Result := TBuff.Text;
        finally
          TBuff.Free;
        end;
      finally
        RBuff.Free;
      end;
    end;
    InternetCloseHandle(hService);
  end;
end;

function SetCookie(const AURL, CookieName, CookieData: string):Boolean;
begin
  Result := InternetSetCookieW(PWideChar(AURL), PWideChar(CookieName), PWideChar(CookieData));
end;

end.

