object Form1: TForm1
  Left = 192
  Top = 114
  Width = 696
  Height = 480
  Caption = 'test stomp'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Scaled = False
  PixelsPerInch = 96
  TextHeight = 13
  object Memo: TMemo
    Left = 353
    Top = 0
    Width = 335
    Height = 446
    Align = alClient
    ScrollBars = ssVertical
    TabOrder = 0
  end
  object GroupBox1: TGroupBox
    Left = 0
    Top = 0
    Width = 353
    Height = 446
    Align = alLeft
    TabOrder = 1
    object Label1: TLabel
      Left = 56
      Top = 16
      Width = 22
      Height = 13
      Caption = 'Addr'
    end
    object Label4: TLabel
      Left = 56
      Top = 72
      Width = 48
      Height = 13
      Caption = 'Username'
    end
    object Label3: TLabel
      Left = 200
      Top = 72
      Width = 47
      Height = 13
      Caption = 'Passcode'
    end
    object Label2: TLabel
      Left = 56
      Top = 184
      Width = 102
      Height = 13
      Caption = 'Queue or topic name:'
    end
    object Label5: TLabel
      Left = 8
      Top = 280
      Width = 83
      Height = 13
      Caption = 'message to send:'
    end
    object Label6: TLabel
      Left = 8
      Top = 320
      Width = 102
      Height = 13
      Caption = 'Queue or topic name:'
    end
    object edHost: TEdit
      Left = 56
      Top = 40
      Width = 241
      Height = 21
      TabOrder = 0
      Text = '127.0.0.1:61613;128.64.7.111:61613'
    end
    object edUsername: TEdit
      Left = 56
      Top = 96
      Width = 129
      Height = 21
      TabOrder = 1
    end
    object edPasscode: TEdit
      Left = 200
      Top = 96
      Width = 129
      Height = 21
      TabOrder = 2
    end
    object btOpen: TButton
      Left = 56
      Top = 128
      Width = 129
      Height = 25
      Caption = 'Open connection'
      TabOrder = 3
      OnClick = btOpenClick
    end
    object btClose: TButton
      Left = 200
      Top = 128
      Width = 129
      Height = 25
      Caption = 'Close connection'
      TabOrder = 4
      OnClick = btCloseClick
    end
    object btClear: TButton
      Left = 56
      Top = 408
      Width = 129
      Height = 25
      Caption = 'clear memo'
      TabOrder = 5
      OnClick = btClearClick
    end
    object edDestName: TEdit
      Left = 168
      Top = 184
      Width = 153
      Height = 21
      TabOrder = 6
      Text = '/queue/a'
    end
    object btSub: TButton
      Left = 56
      Top = 216
      Width = 75
      Height = 25
      Caption = 'Subscribe'
      TabOrder = 7
      OnClick = btSubClick
    end
    object btUnsub: TButton
      Left = 216
      Top = 216
      Width = 75
      Height = 25
      Caption = 'Unsubscribe'
      TabOrder = 8
      OnClick = btUnsubClick
    end
    object edMsg: TEdit
      Left = 96
      Top = 280
      Width = 241
      Height = 21
      TabOrder = 9
      Text = 'hello'
    end
    object edDestToSend: TEdit
      Left = 128
      Top = 320
      Width = 153
      Height = 21
      TabOrder = 10
      Text = '/queue/a'
    end
    object btSend: TButton
      Left = 32
      Top = 360
      Width = 75
      Height = 25
      Caption = 'Send'
      TabOrder = 11
      OnClick = btSendClick
    end
  end
  object StompClient: TStompClient
    ServerAddr = '127.0.0.1:61613'
    OnConnect = StompClientConnect
    OnDisconnect = StompClientDisconnect
    OnError = StompClientError
    OnMessage = StompClientMessage
    OnReceipt = StompClientReceipt
    OnSetOtherConnectHeaders = StompClientSetOtherConnectHeaders
    TestConnection = True
    TestInterval = 1000
    Left = 24
    Top = 96
  end
end
