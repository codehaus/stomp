unit StompClient;

// Author: Dingwen Yuan pdvyuan@hotmail.com
// Version: 0.2


interface

uses
  Windows, Messages, SysUtils, Classes, ScktComp, ExtCtrls;

const
  LINE_SEP: char = #10;
  END_SEP: char = #0;

type


  TAckMode = (AUTO, CLIENT);

  EStomp = class(Exception);

  TItem = record
    Key: String;
    Value: String;
  end;

  PItem = ^TItem;

  //Frame class
  TStompFrame = class(TObject)
  private
    FCommand: String;
    FHeader: TList;
    FBody: String;
  public
    constructor Create;
    destructor Destroy; override;
    property Command: String read FCommand write FCommand;
    property Body: String read FBody write FBody;
    procedure Add(Key: String; Value: String);
    //return '', when Key doesn't exist or Value of Key is ''
    //otherwise, return Value;
    function GetValue(Key: String): String;
    procedure Remove(Key: String);
    procedure ClearHeader;
    function output: String;
    function Count: Integer;
    function GetHeader(i: Integer): PItem;
  end;

  TAddress = record
    Host: String;
    Port: Integer;
    UserName: String;
    PassCode: String;
  end;

  TAddresses = array of TAddress;

  //process message in the buffer
  //return TFrame, when there is no complete frame in the buffer, return nil.
  //buf contains what left after processing.
  function CreateFrame(var Buf: String): TStompFrame;

type

  TStompClient = class;

  TStompConnectNotifyEvent = procedure (Client: TStompClient; Frame: TStompFrame) of object;
  TStompDisconnectNotifyEvent = procedure (Client: TStompClient) of object;
  TStompErrorNotifyEvent = procedure (Client: TStompClient; Msg: String; Content: String) of object;
  TStompReceiptNotifyEvent = procedure (Client: TStompClient; ReceiptID: String) of object;
  TSetOtherConnectHeaders = procedure (Host: String; Port: Integer; var ConnectFrame: TStompFrame) of object;

  //Frame should be removed by client
  TStompMessageNotifyEvent = procedure (Client: TStompClient; Frame: TStompFrame) of object;

  {
     This control implements a stomp client. It makes use of TClientSocket as its
     workhorse. TStompClient runs in nonblocking mode. Client should register events
     handlers to respond to the various events.
  }
  TStompClient = class(TComponent)
  private
    { Private declarations }
    FServerAddrs: TAddresses;
    FNextConnect: Integer;
    FTestConnection: boolean;
    FServerAddr: String;
    FTransport: TClientSocket;
    FConnected: Boolean;
    FOnConnect: TStompConnectNotifyEvent;
    FOnMessage: TStompMessageNotifyEvent;
    //error message
    FOnError: TStompErrorNotifyEvent;
    FOnDisconnect: TStompDisconnectNotifyEvent;
    FOnReceipt: TStompReceiptNotifyEvent;
    FOnSetOtherConnectHeaders: TSetOtherConnectHeaders;
    FTimer: TTimer;
    FConnectFrame: TStompFrame;
    //Read message buffer
    FBuf: String;
    procedure OnTransportRead(Sender: TObject; Socket: TCustomWinSocket);
    procedure OnTransportConnect(Sender: TObject; Socket: TCustomWinSocket);
    procedure OnTransportDisconnect(Sender: TObject; Socket: TCustomWinSocket);
    procedure OnTransportError(Sender: TObject; Socket: TCustomWinSocket;
      ErrorEvent: TErrorEvent; var ErrorCode: Integer);
    procedure OnTimer(Sender: TObject);
    procedure Connect;
    procedure Disconnect;
    procedure Transmit(Frame: TStompFrame); overload;
    procedure Transmit(Frame: TStompFrame; Headers: array of TItem); overload;
    procedure Send(Dest: String; Body: String; IsText: Boolean; ReceiptID: String); overload;
    procedure Send(Dest: String; Body: String; Headers: array of TItem; IsText: Boolean; ReceiptID: String); overload;
    function GetServerAddr: String;
    procedure SetServerAddr(const Value: String);

    procedure SplitAddrs(Addr: String);
    function GetTestConnection: boolean;
    procedure SetTestConnection(const Value: boolean);
    function GetTestConnectionInterval: Integer;
    procedure SetTestConnectionInterval(const Value: Integer);

    procedure DoClose;
    procedure DoOpen;
  protected
    { Protected declarations }
  public
    { Public declarations }
    constructor Create(AOwner: TComponent); override;
    {
    //clear all the items of CONNECT HEADERS except that of login and passcode, and set new.
    //login and passcode should be set in the ServerAddr property.
    procedure ClearAndSetSuppConnectHeaders(Headers: array of TItem);
    }
    destructor Destroy; override;
    //Open connection and send connect frame if connected.
    //connecting will be tested if TestConnection is true and connection will be tried in circular form .
    procedure Open;
    //disable connection timer, then send disconnect frame if possible and close connection
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
    function GetServerAddrs: TAddresses;
  published
    { Published declarations }

    //Stomp Server Address: ServerAddr should be in the form of host:port or host:port:user:passcode
    property ServerAddr: String read GetServerAddr write SetServerAddr;
    //fired after receive CONNECTED frame. client should be in charge of free StompFrame.
    property OnConnect: TStompConnectNotifyEvent read FOnConnect write FOnConnect;
    //If socket close operation is active, it is fired after sending DISCONNECT frame
    // and just before the socket is closed.
    //If socket close operation is passive, it is fired just before the socket is closed.
    property OnDisconnect: TStompDisconnectNotifyEvent read FOnDisconnect write FOnDisconnect;
    //fired on receiving error frame. Note the difference between this event and OnTransportError.
    property OnError: TStompErrorNotifyEvent read FOnError write FOnError;
    //fired on receiving message frame. client should be in charge of free StompFrame.
    property OnMessage: TStompMessageNotifyEvent read FOnMessage write FOnMessage;
    //fired on receiving receipt frame.
    property OnReceipt: TStompReceiptNotifyEvent read FOnReceipt write FOnReceipt;
    //Set headers other than login and passcode for CONNECT frame.
    property OnSetOtherConnectHeaders: TSetOtherConnectHeaders read FOnSetOtherConnectHeaders write FOnSetOtherConnectHeaders;
    //connection test set. default true; TestConnection should not be set between open and close,
    //because it will have no effect.
    property TestConnection: boolean read GetTestConnection write SetTestConnection;
    //connection test interval in ms. default 1000;
    property TestInterval: Integer read GetTestConnectionInterval write SetTestConnectionInterval;
  end;


procedure Register;

implementation

uses Dialogs;


procedure Register;
begin
  RegisterComponents('Stomp', [TStompClient]);
end;

{ TStompFrame }

procedure TStompFrame.Add(Key, Value: String);
var
  p: PItem;
  i: Integer;
  pp: PItem;
begin
  for i:= 0 to FHeader.Count-1 do
  begin
    pp:= FHeader.Items[i];
    if (pp^.Key = Key) then
    begin
      pp^.Value:= Value;
      exit;
    end;
  end;
  New(p);
  p^.Key:= Key;
  p^.Value:= Value;
  FHeader.Add(p);
end;

procedure TStompFrame.ClearHeader;
var
  i: Integer;
  p: PItem;
begin
  for i:= 0 to FHeader.Count-1 do
  begin
    p:= FHeader.Items[i];
    Dispose(p);
  end;
  FHeader.Clear;
end;

function TStompFrame.Count: Integer;
begin
  result:= self.FHeader.Count;
end;

constructor TStompFrame.Create;
begin
  FHeader:= TList.Create;
  self.FCommand:= '';
  self.FBody:= '';
end;

destructor TStompFrame.Destroy;
begin
  ClearHeader;
  FHeader.Free;
  inherited;
end;

function TStompFrame.GetHeader(i: Integer): PItem;
begin
  if (i < 0) or (i > FHeader.Count-1) then
  begin
    raise EStomp.Create('index out of bound');
  end;
  result:= FHeader.Items[i];
end;

function TStompFrame.GetValue(Key: String): String;
var
  i: Integer;
  p: PItem;
begin
  for i:= 0 to FHeader.Count-1 do
  begin
    p:= FHeader.Items[i];
    if (p^.Key = Key) then
    begin
      result:= p^.Value;
      exit;
    end;
  end;
  result:= '';
end;

function TStompFrame.output: String;
var
  s: String;
  i: Integer;
  p: PItem;
begin
  s:= FCommand+LINE_SEP;
  for i:= 0 to FHeader.Count-1 do
  begin
    p:= FHeader.Items[i];
    s:= s+p^.Key+':'+p^.Value+LINE_SEP;
  end;
  s:= s+LINE_SEP+FBody+END_SEP+LINE_SEP;
  result:= s;
end;

procedure TStompFrame.Remove(Key: String);
var
  i: Integer;
  p: PItem;
begin
  for i:= 0 to FHeader.Count-1 do
  begin
    p:= FHeader.Items[i];
    if (p^.Key = Key) then
    begin
      FHeader.Delete(i);
      Dispose(p);
      break;
    end;
  end;
end;

//return a line without \n, From increased to start of next Line;
//throws ENoMoreLine
function GetLine(Buf: String; var From: Integer): String;
var
  i: Integer;
begin
  if (From > Length(Buf)) then
  begin
    raise EStomp.Create('From out of bound.');
  end;
  i:= From;
  while (i <= Length(Buf)) do
  begin
    if (Buf[i] <> LINE_SEP) then
      inc(i)
    else
    begin
      break;
    end;
  end;
  if (Buf[i] = LINE_SEP) then
  begin
    result:= Copy(Buf, From, i-From);
    From:= i+1;
    exit;
  end
  else
    raise EStomp.Create('End of Line not found.');
end;

function CreateFrame(var Buf: String): TStompFrame;
var
  line: String;
  i: Integer;
  p: Integer;
  key, value: String;
  other: String;
  contLen: Integer;
  sContLen: String;
begin
  result:= TStompFrame.Create;
  i:= 1;
  try
    result.Command:= GetLine(Buf, i);
    while (true)  do
    begin
      line:= GetLine(Buf, i);
      if (line = '') then
        break;
      p:= Pos(':', line);
      if (p = 0) then
        raise Exception.Create('header line error');
      key:= Copy(line, 1, p-1);
      value:= Copy(line, p+1, Length(Line)-p);
      result.Add(key, value);
    end;
    other:= Copy(Buf, i, High(Integer));
    sContLen:= result.GetValue('content-length');
    if (sContLen <> '') then
    begin
      contLen:= StrToInt(sContLen);
      if Length(other) < contLen+2 then
        raise EStomp.Create('frame too short');
      if Copy(other, contLen+1, 2) <> END_SEP+LINE_SEP then
        raise Exception.Create('frame ending error');
      result.Body:= Copy(other, 1, contLen);
      Buf:= Copy(other, contLen+3, High(Integer));
    end
    else
    begin
      p:= Pos(END_SEP+LINE_SEP, other);
      if (p = 0) then
        raise EStomp.Create('frame no ending');
      result.Body:= Copy(other, 1, p-1);
      Buf:= Copy(other, p+2, High(Integer));
    end;
  except
    on EStomp do
    begin
      //ignore
      result.Free;
      result:= nil;
    end;
    on e: Exception do
    begin
      result.Free;
      raise EStomp.Create(e.Message);
    end;
  end;
end;

{ TStompClient }


procedure TStompClient.Close;
begin
  self.FTimer.Enabled:= false;
  DoClose;
end;

procedure TStompClient.Connect;
begin
  FTransport.Socket.SendText(FConnectFrame.output);
end;

constructor TStompClient.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FConnectFrame:= TStompFrame.Create;
  FConnectFrame.FCommand:= 'CONNECT';
  FConnectFrame.Add('login', '');
  FConnectFrame.Add('passcode', '');
  FTransport:= TClientSocket.Create(Self);
  FTransport.OnConnect:= OnTransportConnect;
  FTransport.OnError:= OnTransportError;
  FTransport.OnDisconnect:= OnTransportDisconnect;
  FTransport.OnRead:= OnTransportRead;
  FConnected:= false;
  FTimer:= TTimer.Create(self);
  FTimer.OnTimer:= OnTimer;
  FTimer.Enabled:= false;
  TestConnection:= true;
  TestInterval:= 1000;
  FBuf:= '';
  self.ServerAddr:= '127.0.0.1:61613';
end;

destructor TStompClient.Destroy;
begin
  self.FConnectFrame.Free;
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


procedure TStompClient.OnTransportConnect(Sender: TObject;
  Socket: TCustomWinSocket);
var
  index: Integer;
  Host: String;
  Port: Integer;
begin
  index:= FNextConnect-1;
  if (index < 0) then
    index:= Length(FServerAddrs)+index;
  Host:= FServerAddrs[index].Host;
  Port:= FServerAddrs[index].Port;
  FConnectFrame.ClearHeader;
  FConnectFrame.Add('login', FServerAddrs[index].UserName);
  FConnectFrame.Add('passcode', FServerAddrs[index].PassCode);
  if Assigned(FOnSetOtherConnectHeaders) then
    FOnSetOtherConnectHeaders(Host, Port, FConnectFrame);
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
      FConnected:= true;
      if Assigned(FOnConnect) then
      begin
        freeFrame:= false;
        FOnConnect(Self, Frame);
      end;
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


procedure TStompClient.DoOpen;
var
  Host: String;
  Port: Integer;
begin
  Host:= FServerAddrs[FNextConnect].Host;
  Port:= FServerAddrs[FNextConnect].Port;
  FTransport.Host:= Host;
  FTransport.Port:= Port;
  Inc(FNextConnect);
  FNextConnect:= FNextConnect mod Length(FServerAddrs);
  FTransport.Open;
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

{
procedure TStompClient.ClearAndSetSuppConnectHeaders(Headers: array of TItem);
var
  login: String;
  passcode: String;
  i: Integer;
begin
  login:= FConnectFrame.GetValue('login');
  passcode:= FConnectFrame.GetValue('passcode');
  FConnectFrame.ClearHeader;
  FConnectFrame.Add('login', login);
  FConnectFrame.Add('passcode', passcode);
  for i:= low(Headers) to high(Headers) do
  begin
    FConnectFrame.Add(Headers[i].Key, Headers[i].Value);
  end;
end;
}


function TStompClient.GetServerAddr: String;
begin
  result:= Self.FServerAddr;
end;

procedure TStompClient.SetServerAddr(const Value: String);
begin
  SplitAddrs(Value);
  Self.FServerAddr:= Value;
end;

procedure TStompClient.SplitAddrs(Addr: String);
var
  i, j, k: Integer;
  sAddr: String;
  guess, actual: Integer;
  from: Integer;
  buf: String;
begin
  try
    if not (Length(Addr) > 0) then
    begin
      raise EStomp('invalid address:'+Addr);
    end
    else
    begin
      if (Addr[Length(Addr)] <> ';') then
        Addr:= Addr+';';
    end;
    guess:= 1;
    actual:= 0;
    from:= 1;
    SetLength(FServerAddrs, guess);

    for i:=1 to Length(Addr) do
    begin
      if (Addr[i] = ';') then
      begin
        sAddr:= Copy(Addr, from, i-from);
        from:= i+1;
        if (actual > guess-1) then
        begin
          guess:= guess*2;
          SetLength(FServerAddrs, guess);
        end;

        if (sAddr[Length(sAddr)] <> ':') then
          sAddr:= sAddr+':';
        FServerAddrs[actual].Host:= '';
        FServerAddrs[actual].Port:= 61613;
        FServerAddrs[actual].UserName:= '';
        FServerAddrs[actual].PassCode:= '';
        buf:= '';
        k:= 0;
        for j:= 1 to Length(sAddr) do
        begin
          if (sAddr[j] <> ':') then
            buf:= buf+sAddr[j]
          else
          begin
            if (k = 0) then
              FServerAddrs[actual].Host:= buf
            else if (k = 1) then
              FServerAddrs[actual].Port:= StrToInt(buf)
            else if (k = 2) then
              FServerAddrs[actual].UserName:= buf
            else if (k = 3) then
              FServerAddrs[actual].PassCode:= buf
            else
              raise EStomp.Create('invalid address:'+Addr);
            inc(k);
            buf:= '';
          end;
        end;

        if (FServerAddrs[actual].Host = '') then
          raise EStomp.Create('invalid address:'+Addr);

        Inc(actual);
      end;
    end;
    SetLength(FServerAddrs, actual);
    FNextConnect:= 0;
  except
    on e: Exception do
    begin
      FServerAddrs:= nil;
      raise EStomp.Create(e.Message);
    end;
  end;
end;

procedure TStompClient.OnTransportError(Sender: TObject; Socket: TCustomWinSocket;
  ErrorEvent: TErrorEvent; var ErrorCode: Integer);
begin
  try
    self.FTransport.Close;
    ErrorCode:= 0;
  except
  end;
end;

function TStompClient.GetTestConnection: boolean;
begin
  result:= FTestConnection;
end;

procedure TStompClient.SetTestConnection(const Value: boolean);
begin
  FTestConnection:= Value;
end;

function TStompClient.GetTestConnectionInterval: Integer;
begin
  result:= FTimer.Interval;
end;

procedure TStompClient.SetTestConnectionInterval(const Value: Integer);
begin
  FTimer.Interval:= Value;
end;

procedure TStompClient.OnTimer(Sender: TObject);
begin
  if not self.FTransport.Active then
  begin
    self.DoOpen;
  end;
end;

procedure TStompClient.DoClose;
begin
  if self.FTransport.Active then
    Self.Disconnect;
  self.FTransport.Close;
end;

procedure TStompClient.Open;
begin
  self.FTimer.Enabled:= self.FTestConnection;
  DoOpen;
end;

function TStompClient.GetServerAddrs: TAddresses;
begin
  result:= FServerAddrs;
end;

end.


