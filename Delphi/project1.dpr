program project1;

uses
  Forms, unit1,
  HParse in '..\hparse.pas',
  SHParser in '..\shparser.pas',
  WinHTML in '..\winhtml.pas';


{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.

