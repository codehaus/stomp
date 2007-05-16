
program TestStomp;

uses
  TestFramework,
  GUITestRunner,
  untTestStomp in 'untTestStomp.pas',
  StompClient in '..\source\StompClient.pas';

{$R *.res}

begin
  TGUITestRunner.runRegisteredTests;
end.

