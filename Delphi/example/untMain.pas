unit untMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, StompClient, ScktComp;

type
  TForm1 = class(TForm)
    Memo: TMemo;
    GroupBox1: TGroupBox;
    Label1: TLabel;
    edHost: TEdit;
    Label4: TLabel;
    edUsername: TEdit;
    edPort: TEdit;
    Label2: TLabel;
    Label3: TLabel;
    edPasscode: TEdit;
    btOpen: TButton;
    StompClient: TStompClient;
    btClose: TButton;
    btSendQ: TButton;
    Button1: TButton;
    edQueueA: TEdit;
    Label5: TLabel;
    edTopicB: TEdit;
    Label6: TLabel;
    procedure btOpenClick(Sender: TObject);
    procedure StompClientDisconnect(Client: TStompClient);
    procedure StompClientError(Client: TStompClient; Msg, Content: String);
    procedure StompClientMessage(Client: TStompClient; Frame: TStompFrame);
    procedure StompClientReceipt(Client: TStompClient; ReceiptID: String);
    procedure StompClientTransportError(Sender: TObject;
      Socket: TCustomWinSocket; ErrorEvent: TErrorEvent;
      var ErrorCode: Integer);
    procedure btCloseClick(Sender: TObject);
    procedure btSendQClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure StompClientConnect(Client: TStompClient; Frame: TStompFrame);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

procedure TForm1.btCloseClick(Sender: TObject);
begin
  Memo.Lines.Add('close stomp client');
  StompClient.Close;
end;

var
  CONN_HEADERS: array of TItem = nil;

procedure TForm1.btOpenClick(Sender: TObject);
begin

  self.StompClient.Host:= edHost.Text;
  self.StompClient.Port:= StrToInt(edPort.Text);

  CONN_HEADERS:= nil;
  setLength(CONN_HEADERS, 2);
  CONN_HEADERS[0].Key:= 'login';
  CONN_HEADERS[0].Value:= 'me';
  CONN_HEADERS[1].Key:= 'passcode';
  CONN_HEADERS[1].Value:= 'pass';
  //set various other headers.
  StompClient.ClearAndSetConnectHeaders(CONN_HEADERS);

  Memo.Lines.Add('open stomp client');
  StompClient.Open;
end;



procedure TForm1.StompClientDisconnect(Client: TStompClient);
begin
  Memo.Lines.Add('disconnected');
end;

procedure TForm1.StompClientError(Client: TStompClient; Msg,
  Content: String);
begin
  Memo.Lines.Add('receive error frame - Message:'+Msg+', Content:'+Content);
end;

procedure TForm1.StompClientMessage(Client: TStompClient;
  Frame: TStompFrame);
begin
  Memo.Lines.Add('receive message frame - '+Frame.output);
  Frame.Free;
end;

procedure TForm1.StompClientReceipt(Client: TStompClient;
  ReceiptID: String);
begin
  Memo.Lines.Add('receive receipt frame - '+ReceiptID);
end;

procedure TForm1.StompClientTransportError(Sender: TObject;
  Socket: TCustomWinSocket; ErrorEvent: TErrorEvent;
  var ErrorCode: Integer);
begin
  Memo.Lines.Add('socket transport error - errorcode:'+IntToStr(ErrorCode));
  ErrorCode:= 0;
end;



procedure TForm1.btSendQClick(Sender: TObject);
begin
  self.StompClient.SendText('/queue/A', 'hello A');
end;



procedure TForm1.Button1Click(Sender: TObject);
begin
  self.StompClient.SendText('/topic/B', 'hello B');
end;

procedure TForm1.StompClientConnect(Client: TStompClient;
  Frame: TStompFrame);
begin
  Memo.Lines.Add('connected, SessionID:'+Frame.GetValue('session'));
  Memo.Lines.Add('subscribe queue A');
  StompClient.Subscribe('/queue/'+edQueueA.Text, AUTO);
  Memo.Lines.Add('subscribe topic B');
  StompClient.Subscribe('/topic/'+edTopicB.Text, AUTO);
  Frame.Free;
end;

end.
                                                    