unit untTestStomp;

interface

uses StompClient, TestFrameWork;

type

  TTestStomp = class(TTestCase)
  private
    FClient: TStompClient;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure testSingle;
    procedure testMulti;
  end;



implementation

{ TTestStomp }

procedure TTestStomp.SetUp;
begin
  FClient:= TStompClient.Create(nil);
end;

procedure TTestStomp.TearDown;
begin
  FClient.Free;
end;

procedure TTestStomp.testMulti;
var
  addrs: TAddresses;
begin
  FClient.ServerAddr:= '127.0.0.1:61614;127.0.0.2:61613:pdv:hello;127.0.0.3:61613:man';
  addrs:= FClient.GetServerAddrs;
  checkEquals(3, Length(addrs));
  checkEquals('127.0.0.1', addrs[0].Host);
  checkEquals(61614, addrs[0].Port);
  checkEquals('', addrs[0].UserName);
  checkEquals('', addrs[0].PassCode);

  checkEquals('127.0.0.2', addrs[1].Host);
  checkEquals(61613, addrs[1].Port);
  checkEquals('pdv', addrs[1].UserName);
  checkEquals('hello', addrs[1].PassCode);

  checkEquals('127.0.0.3', addrs[2].Host);
  checkEquals(61613, addrs[2].Port);
  checkEquals('man', addrs[2].UserName);
  checkEquals('', addrs[21].PassCode);
end;

procedure TTestStomp.testSingle;
var
  addrs: TAddresses;
begin
  FClient.ServerAddr:= '127.0.0.1:61614';
  addrs:= FClient.GetServerAddrs;
  checkEquals(1, Length(addrs));
  checkEquals('127.0.0.1', addrs[0].Host);
  checkEquals(61614, addrs[0].Port);
  checkEquals('', addrs[0].UserName);
  checkEquals('', addrs[0].PassCode);
end;

initialization
  RegisterTest('', TTestStomp.suite);

end.
