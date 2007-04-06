unit StompHelper;

// Author: Dingwen Yuan pdvyuan@hotmail.com
// Version: 0.1

interface

uses Classes, SysUtils;

const
  LINE_SEP: char = #10;
  END_SEP: char = #0;
  
type

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
    procedure Clear;
    function output: String;
    function Count: Integer;
    function GetHeader(i: Integer): PItem;
  end;

  //process message in the buffer
  //return TFrame, when there is no complete frame in the buffer, return nil.
  //buf contains what left after processing.
  function CreateFrame(var Buf: String): TStompFrame;


implementation

{ TFrame }

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

procedure TStompFrame.Clear;
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
  Clear;
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
  
end.
