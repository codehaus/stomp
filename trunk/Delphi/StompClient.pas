unit StompClient;

// Author: Dingwen Yuan pdvyuan@hotmail.com
// Version: 0.1


interface

uses
  Windows, Messages, SysUtils, Classes, ScktComp, StompHelper;

type


  TAckMode = (AUTO, CLIENT);

  TStompClient = class;

  TStompConnectNotifyEvent = procedure (Client: TStompClient; SessionID: String) of object;
  TStompDisconnectNotifyEvent = procedure (Client: TStompClient) of object;
  TStompErrorNotifyEvent = procedure (Client: TStompClient; Msg: String; Content: String) of object;
  TStompReceiptNotifyEvent = procedure (Client: TStompClient; ReceiptID: String) of object;

  //Frame should be removed by client
  TStompMessageNotifyEvent = procedure (Client: TStompClient; Frame: TStompFrame) of object;

  TStompClient = class(TComponent)
  private
    { Private declarations }
    FTransport: TClientSocket;
    FUserName: String;
    FPassCode: String;
    FConnected: Boolean;
    FOnConnect: TStompConnectNotifyEvent;
    FOnMessage: TStompMessageNotifyEvent;
    //error message
    FOnError: TStompErrorNotifyEvent;
    FOnDisconnect: TStompDisconnectNotifyEvent;
    FOnTransportError: TSocketErrorEvent;
    FOnReceipt: TStompReceiptNotifyEvent;
    //Read message buffer
    FBuf: String;
    FSessionID: String;
    procedure SetHost(const Value: String);
    procedure SetPort(const Value: Integer);
    function GetHost: String;
    function GetPort: Integer;
    procedure SetPassCode(const Value: String);
    procedure SetUserName(const Value: String);
    procedure OnTransportRead(Sender: TObject; Socket: TCustomWinSocket);
    procedure OnTransportConnect(Sender: TObject; Socket: TCustomWinSocket);
    procedure OnTransportDisconnect(Sender: TObject; Socket: TCustomWinSocket);
    procedure Connect;
    procedure Disconnect;
    procedure Transmit(Frame: TStompFrame); overload;
    procedure Transmit(Frame: TStompFrame; Headers: array of TItem); overload;
    procedure Send(Dest: String; Body: String; IsText: Boolean; ReceiptID: String); overload;
    procedure Send(Dest: String; Body: String; Headers: array of TItem; IsText: Boolean; ReceiptID: String); overload;
  protected
    { Protected declarations }
  public
    { Public declarations }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    //Open connection and send connect frame
    procedure Open;
    //Send disconnect frame and close connection
    procedure Close;

    //Send send frame
    procedure SendText(Dest: String; Body: String; ReceiptID: String = ''); overload;
    procedure SendText(Dest: String; Body: String; Headers: array of TItem; ReceiptID: String = ''); overload;
    procedure SendBin(Dest: String; Body: String; ReceiptID: String = ''); overload;
    procedure SendBin(Dest: String; Body: String; Headers: array of TItem; ReceiptID: String = ''); overload;

    //Send subscribe frame
    procedure Subscribe(Dest: String; ackMode: TAckMode; ReceiptID: String = ''); overload;
    procedure Subscribe(Dest: String; ackMode: TAckMode; Headers: array of TItem; ReceiptID: String = ''); overload;

    //Send unsubscribe frame
    procedure UnsubscribeDest(Dest: String; ReceiptID: String = '');
    procedure UnsubscribeID(ID: String; ReceiptID: String = '');

    //Send begin Transaction frame
    procedure BeginTrans(TransID: String; ReceiptID: String = '');
    //Send commit Transaction frame
    procedure CommitTrans(TransID: String; ReceiptID: String = '');
    //Send abort Transaction frame
    procedure AbortTrans(TransID: String; ReceiptID: String = '');

    //Send Ack frame without transactionID
    procedure Ack(MessageID: String; ReceiptID: String = ''); overload;
    //Send Ack frame with transactionID
    procedure Ack(MessageID: String; transaction: String; ReceiptID: String = ''); overload;

    property Connected: Boolean read FConnected;
    property Transport: TClientSocket read FTransport write FTransport;
  published
    { Published declarations }
    property Host: String read GetHost write SetHost;
    property Port: Integer read GetPort write SetPort;
    property UserName: String read FUserName write SetUserName;
    property PassCode: String read FPassCode write SetPassCode;
    property OnConnect: TStompConnectNotifyEvent read FOnConnect write FOnConnect;
    property OnDisconnect: TStompDisconnectNotifyEvent read FOnDisconnect write FOnDisconnect;
    property OnTransportError: TSocketErrorEvent read FOnTransportError write FOnTransportError;
    property OnError: TStompErrorNotifyEvent read FOnError write FOnError;
    property OnMessage: TStompMessageNotifyEvent read FOnMessage write FOnMessage;
    property OnReceipt: TStompReceiptNotifyEvent read FOnReceipt write FOnReceipt;
    property SessionID: String read FSessionID;

  end;


procedure Register;

implementation

uses Dialogs;


procedure Register;
begin
  RegisterComponents('Stomp', [TStompClient]);
end;

{ TStompClient }


procedure TStompClient.Close;
begin
  if self.FTransport.Active then
    Self.Disconnect;
  self.FTransport.Close;
end;

procedure TStompClient.Connect;
var
  frame: TStompFrame;
  s: String;
begin
  frame:= TStompFrame.Create;
  try
    frame.Command:= 'CONNECT';
    frame.Add('login', UserName);
    frame.Add('passcode', PassCode);
    s:= frame.output;
    FTransport.Socket.SendText(s);
  finally
    frame.Free;
  end;
end;

constructor TStompClient.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FTransport:= TClientSocket.Create(Self);
  FTransport.OnConnect:= OnTransportConnect;
  FTransport.OnDisconnect:= OnTransportDisconnect;
  FTransport.OnRead:= OnTransportRead;
  FTransport.OnError:= OnTransportError;
  FConnected:= false;
  FBuf:= '';
  self.FUserName:= '';
  self.FPassCode:= '';
  self.FSessionID:= '';
  self.FTransport.Port:= 61613;

end;

destructor TStompClient.Destroy;
begin
  inherited;
end;

procedure TStompClient.Disconnect;
var
  frame: TStompFrame;
  s: String;
begin
  frame:= TStompFrame.Create;
  try
    frame.Command:= 'DISCONNECT';
    s:= frame.output;
    FTransport.Socket.SendText(s);
  finally
    frame.Free;
  end;
end;


function TStompClient.GetHost: String;
begin
  result:= FTransport.Host;
end;

function TStompClient.GetPort: Integer;
begin
  result:= FTransport.Port;
end;

procedure TStompClient.OnTransportConnect(Sender: TObject;
  Socket: TCustomWinSocket);
begin
  Connect;
end;

procedure TStompClient.OnTransportRead(Sender: TObject;
  Socket: TCustomWinSocket);
var
  frame: TStompFrame;
  msg: String;
  content: String;
  freeFrame: boolean;
begin
  self.FBuf:= self.FBuf+Socket.ReceiveText;
  while (true) do
  begin
    freeFrame:= true;
    frame:= CreateFrame(self.FBuf);
    if (frame = nil) then
      break;
    if (frame.Command = 'CONNECTED') then
    begin
      self.FSessionID:= frame.GetValue('session');
      FConnected:= true;
      if Assigned(FOnConnect) then
         FOnConnect(Self, FSessionID);
    end
    else if (frame.Command = 'ERROR') then
    begin
      msg:= frame.GetValue('message');
      content:= frame.Body;
      if Assigned(FOnError) then
        FOnError(Self, msg, content);
    end
    else if (frame.Command = 'MESSAGE') then
    begin
      if Assigned(FOnMessage) then
      begin
        freeFrame:= false;
        FOnMessage(Self, frame);
      end;
    end
    else if (frame.Command = 'RECEIPT') then
    begin
      if Assigned(FOnReceipt) then
      begin
        FOnReceipt(Self, frame.GetValue('receipt-id'));
      end;
    end;
    if freeFrame then
      frame.Free;
  end;
end;



procedure TStompClient.Send(Dest, Body: String; IsText: Boolean; ReceiptID: String);
var
  frame: TStompFrame;
begin
  frame:= TStompFrame.Create;
  try
    frame.Command:= 'SEND';
    frame.Add('destination', Dest);
    if ReceiptID <> ''  then
      frame.Add('receipt-id', ReceiptID);
    if not IsText then
      frame.Add('content-length', IntToStr(Length(Body)));
    frame.Body:= Body;
    Transmit(frame);
  finally
    frame.Free;
  end;
end;

procedure TStompClient.Send(Dest, Body: String; Headers: array of TItem; IsText: Boolean; ReceiptID: String);
var
  frame: TStompFrame;
begin
  frame:= TStompFrame.Create;
  try
    frame.Command:= 'SEND';
    frame.Add('destination', Dest);
    if ReceiptID <> ''  then
      frame.Add('receipt-id', ReceiptID);
    if not IsText then
      frame.Add('content-length', IntToStr(Length(Body)));
    frame.Body:= Body;
    Transmit(frame, Headers);
  finally
    frame.Free;
  end;
end;


procedure TStompClient.Open;
begin
  FTransport.Open;
end;


procedure TStompClient.SetHost(const Value: String);
begin
  FTransport.Host:= Value;
end;

procedure TStompClient.SetPassCode(const Value: String);
begin
  if not (csLoading in ComponentState) and FConnected then
     raise EStomp.Create('cannot change Passcode when running.');
  FPassCode := Value;
end;

procedure TStompClient.SetPort(const Value: Integer);
begin
  FTransport.Port:= Value;
end;

procedure TStompClient.SetUserName(const Value: String);
begin
  if not (csLoading in ComponentState) and FConnected then
     raise EStomp.Create('cannot change Username when running.');
  FUserName := Value;
end;



procedure TStompClient.OnTransportDisconnect(Sender: TObject;
  Socket: TCustomWinSocket);
begin
  FConnected:= false;
  if Assigned(FOnDisconnect) then
    FOnDisconnect(Self);
end;



procedure TStompClient.Transmit(Frame: TStompFrame);
begin
  self.FTransport.Socket.SendText(Frame.output);
end;

procedure TStompClient.Transmit(Frame: TStompFrame; Headers: array of TItem);
var
  i: Integer;
begin
  for i:= low(Headers) to high(Headers) do
    Frame.Add(Headers[i].Key, Headers[i].Value);
  Transmit(Frame);
end;

procedure TStompClient.Subscribe(Dest: String; ackMode: TAckMode; ReceiptID: String = '');
var
  frame: TStompFrame;
  ack: String;
begin
  frame:= TStompFrame.Create;
  try
    frame.Command:= 'SUBSCRIBE';
    frame.Add('destination', Dest);
    if ackMode = AUTO then
      ack:= 'auto'
    else
      ack:= 'client';
    frame.Add('ack', ack);
    if (ReceiptID <> '') then
      frame.Add('receipt-id', ReceiptID);
    Transmit(frame);
  finally
    frame.Free;
  end;
end;

procedure TStompClient.Subscribe(Dest: String; ackMode: TAckMode;
  Headers: array of TItem; ReceiptID: String = '');
var
  frame: TStompFrame;
  ack: String;
begin
  frame:= TStompFrame.Create;
  try
    frame.Command:= 'SUBSCRIBE';
    frame.Add('destination', Dest);
    if ackMode = AUTO then
      ack:= 'auto'
    else
      ack:= 'client';
    frame.Add('ack', ack);
    if (ReceiptID <> '') then
      frame.Add('receipt-id', ReceiptID);
    Transmit(frame, Headers);
  finally
    frame.Free;
  end;
end;
procedure TStompClient.UnsubscribeDest(Dest: String; ReceiptID: String = '');
var
  frame: TStompFrame;
begin
  frame:= TStompFrame.Create;
  try
    frame.Command:= 'UNSUBSCRIBE';
    frame.Add('destination', Dest);
    if (ReceiptID <> '') then
      frame.Add('receipt-id', ReceiptID);
    Transmit(frame);
  finally
    frame.Free;
  end;
end;

procedure TStompClient.UnsubscribeID(ID: String; ReceiptID: String = '');
var
  frame: TStompFrame;
begin
  frame:= TStompFrame.Create;
  try
    frame.Command:= 'UNSUBSCRIBE';
    frame.Add('id', ID);
    if (ReceiptID <> '') then
      frame.Add('receipt-id', ReceiptID);
    Transmit(frame);
  finally
    frame.Free;
  end;
end;

procedure TStompClient.BeginTrans(TransID: String; ReceiptID: String = '');
var
  frame: TStompFrame;
begin
  frame:= TStompFrame.Create;
  try
    frame.Command:= 'BEGIN';
    frame.Add('transaction', TransID);
    if (ReceiptID <> '') then
      frame.Add('receipt-id', ReceiptID);
    Self.Transmit(frame);
  finally
    frame.Free;
  end;
end;

procedure TStompClient.CommitTrans(TransID: String; ReceiptID: String = '');
var
  frame: TStompFrame;
begin
  frame:= TStompFrame.Create;
  try
    frame.Command:= 'COMMIT';
    frame.Add('transaction', TransID);
    if (ReceiptID <> '') then
      frame.Add('receipt-id', ReceiptID);
    Self.Transmit(frame);
  finally
    frame.Free;
  end;
end;

procedure TStompClient.AbortTrans(TransID: String; ReceiptID: String = '');
var
  frame: TStompFrame;
begin
  frame:= TStompFrame.Create;
  try
    frame.Command:= 'ABORT';
    frame.Add('transaction', TransID);
    if (ReceiptID <> '') then
      frame.Add('receipt-id', ReceiptID);
    Self.Transmit(frame);
  finally
    frame.Free;
  end;
end;

procedure TStompClient.Ack(MessageID: String; ReceiptID: String = '');
var
  frame: TStompFrame;
begin
  frame:= TStompFrame.Create;
  try
    frame.Command:= 'ACK';
    frame.Add('message-id', MessageID);
    if (ReceiptID <> '') then
      frame.Add('receipt-id', ReceiptID);
    Self.Transmit(frame);
  finally
    frame.Free;
  end;
end;


procedure TStompClient.Ack(MessageID, transaction: String; ReceiptID: String = '');
var
  frame: TStompFrame;
begin
  frame:= TStompFrame.Create;
  try
    frame.Command:= 'ACK';
    frame.Add('message-id', MessageID);
    frame.Add('transaction', transaction);
    if (ReceiptID <> '') then
      frame.Add('receipt-id', ReceiptID);
    Self.Transmit(frame);
  finally
    frame.Free;
  end;
end;

procedure TStompClient.SendBin(Dest, Body, ReceiptID: String);
begin
  Send(Dest, Body, false, ReceiptID);
end;

procedure TStompClient.SendBin(Dest, Body: String; Headers: array of TItem;
  ReceiptID: String);
begin
  Send(Dest, Body, Headers, false, ReceiptID);
end;

procedure TStompClient.SendText(Dest, Body, ReceiptID: String);
begin
  Send(Dest, Body, true, ReceiptID);
end;

procedure TStompClient.SendText(Dest, Body: String;
  Headers: array of TItem; ReceiptID: String);
begin
  Send(Dest, Body, Headers, true, ReceiptID);
end;

end.


