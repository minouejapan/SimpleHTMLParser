unit UniHtml;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, fphttpclient, openssl, opensslsockets;

const
  UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';

function GetHTML(const AURL: string; const CookieName: string = ''; const CookieData: string = ''): string;

implementation

//
function GetHTML(const AURL: string; const CookieName: string = ''; const CookieData: string = ''): string;
var
  Client: TFPHttpClient;

begin
  Result := '';
  InitSSLInterface;

  Client := TFPHttpClient.Create(nil);
  try
    if (CookieName <> '') and (CookieData <> '') then
      Client.Cookies.Add(CookieName + '=' + CookieData);
    Client.AddHeader('User-Agent', UA);
    Client.AllowRedirect := true;
    Result := Client.Get(AURL);
  finally
    Client.Free;
  end;
end;

end.

