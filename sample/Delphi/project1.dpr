program project1;

uses
  Forms,
  hparse in '..\hparse.pas',
  shparser in '..\shparser.pas',
  winhtml in '..\winhtml.pas',
  lazutf8wrap in '..\lazutf8wrap.pas',
  unit1 in 'unit1.pas' {Form1};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.

