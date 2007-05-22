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
    Label3: TLabel;
    edPasscode: TEdit;
    btOpen: TButton;
    StompClient: TStompClient;
    btClose: TButton;
    btClear: TButton;
    Label2: TLabel;
    edDestName: TEdit;
    btSub: TButton;
    btUnsub: TButton;
    edMsg: TEdit;
    Label5: TLabel;
    Label6: TLabel;
    edDestToSend: TEdit;
    btSend: TButton;
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
    procedure StompClientSetOtherConnectHeaders(Host: String;
      Port: Integer; var ConnectFrame: TStompFrame);
    procedure btClearClick(Sender: TObject);
    procedure btSubClick(Sender: TObject);
    procedure btUnsubClick(Sender: TObject);
    procedure btSendClick(Sender: TObject);
  private
    { Private declarations }
    FQueueA: string;
    FTopicB: string;
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

  self.StompClient.ServerAddr:= edHost.Text;
  
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
  self.StompClient.SendText(FQueueA, 'hello A');
end;



procedure TForm1.Button1Click(Sender: TObject);
begin
  self.StompClient.SendText(FTopicB, 'hello B');
end;

procedure TForm1.StompClientConnect(Client: TStompClient;
  Frame: TStompFrame);
begin
  Memo.Lines.Add('connected, SessionID:'+Frame.GetValue('session'));
  Frame.Free;
end;

procedure TForm1.StompClientSetOtherConnectHeaders(Host: String;
  Port: Integer; var ConnectFrame: TStompFrame);
begin
  Memo.Lines.Add('On Set Other Connect Headers for '+Host+':'+IntToStr(Port));
  ConnectFrame.Add('hello', 'hello');
end;

procedure TForm1.btClearClick(Sender: TObject);
begin
  Memo.Lines.Clear;
end;

procedure TForm1.btSubClick(Sender: TObject);
begin
  Memo.Lines.Add('subscribe '+edDestName.Text);
  self.StompClient.Subscribe(edDestName.Text, AUTO);
end;

procedure TForm1.btUnsubClick(Sender: TObject);
begin
  Memo.Lines.Add('unsubscribe '+edDestName.Text);
  self.StompClient.UnsubscribeDest(edDestName.Text);
end;

procedure TForm1.btSendClick(Sender: TObject);
begin
  Memo.Lines.Add('send to '+edDestToSend.Text);
  self.StompClient.SendText(edDestToSend.Text, edMsg.Text);
end;

end.
                                                    