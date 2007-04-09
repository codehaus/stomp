program StompExample;

uses
  Forms,
  untMain in 'untMain.pas' {Form1},
  StompClient in '..\source\StompClient.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
