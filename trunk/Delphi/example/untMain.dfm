object Form1: TForm1
  Left = 192
  Top = 114
  Width = 696
  Height = 480
  Caption = 'Form1'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Scaled = False
  OnCreate = FormCreate
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
      Left = 64
      Top = 56
      Width = 22
      Height = 13
      Caption = 'Host'
    end
    object Label4: TLabel
      Left = 208
      Top = 56
      Width = 48
      Height = 13
      Caption = 'Username'
    end
    object Label2: TLabel
      Left = 64
      Top = 112
      Width = 19
      Height = 13
      Caption = 'Port'
    end
    object Label3: TLabel
      Left = 208
      Top = 112
      Width = 47
      Height = 13
      Caption = 'Passcode'
    end
    object edHost: TEdit
      Left = 64
      Top = 80
      Width = 129
      Height = 21
      TabOrder = 0
      Text = '127.0.0.1'
    end
    object edUsername: TEdit
      Left = 208
      Top = 80
      Width = 129
      Height = 21
      TabOrder = 1
    end
    object edPort: TEdit
      Left = 64
      Top = 136
      Width = 129
      Height = 21
      TabOrder = 2
      Text = '61613'
    end
    object edPasscode: TEdit
      Left = 208
      Top = 136
      Width = 129
      Height = 21
      TabOrder = 3
    end
    object btOpen: TButton
      Left = 48
      Top = 280
      Width = 129
      Height = 25
      Caption = 'Open connection'
      TabOrder = 4
      OnClick = btOpenClick
    end
    object btClose: TButton
      Left = 48
      Top = 336
      Width = 129
      Height = 25
      Caption = 'Close connection'
      TabOrder = 5
      OnClick = btCloseClick
    end
    object btSendQ: TButton
      Left = 208
      Top = 280
      Width = 121
      Height = 25
      Caption = 'send hello to queue A'
      TabOrder = 6
      OnClick = btSendQClick
    end
    object Button1: TButton
      Left = 208
      Top = 336
      Width = 121
      Height = 25
      Caption = 'send hello to topic B'
      TabOrder = 7
      OnClick = Button1Click
    end
  end
  object StompClient: TStompClient
    Port = 61613
    OnConnect = StompClientConnect
    OnDisconnect = StompClientDisconnect
    OnTransportError = StompClientTransportError
    OnError = StompClientError
    OnMessage = StompClientMessage
    OnReceipt = StompClientReceipt
    Left = 24
    Top = 96
  end
end
