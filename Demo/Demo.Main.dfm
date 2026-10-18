object DemoMainForm: TDemoMainForm
  Left = 0
  Top = 0
  Caption = 'gllImage demo - TgllImageView and TgllDBImage'
  ClientHeight = 640
  ClientWidth = 1060
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  TextHeight = 15
  object pnlToolbar: TPanel
    Left = 0
    Top = 0
    Width = 1060
    Height = 41
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object btnOpen: TButton
      Left = 8
      Top = 8
      Width = 75
      Height = 25
      Caption = '&Open...'
      TabOrder = 0
      OnClick = btnOpenClick
    end
    object btnSave: TButton
      Left = 88
      Top = 8
      Width = 75
      Height = 25
      Caption = '&Save...'
      TabOrder = 1
      OnClick = btnSaveClick
    end
    object chkFit: TCheckBox
      Left = 180
      Top = 12
      Width = 49
      Height = 17
      Caption = '&Fit'
      Checked = True
      State = cbChecked
      TabOrder = 2
      OnClick = chkFitClick
    end
    object btnZoomIn: TButton
      Left = 232
      Top = 8
      Width = 60
      Height = 25
      Caption = 'Zoom +'
      TabOrder = 3
      OnClick = btnZoomInClick
    end
    object btnZoomOut: TButton
      Left = 296
      Top = 8
      Width = 60
      Height = 25
      Caption = 'Zoom -'
      TabOrder = 4
      OnClick = btnZoomOutClick
    end
    object btnReset: TButton
      Left = 360
      Top = 8
      Width = 60
      Height = 25
      Caption = '&Reset'
      TabOrder = 5
      OnClick = btnResetClick
    end
    object btnRotateLeft: TButton
      Left = 436
      Top = 8
      Width = 75
      Height = 25
      Caption = 'Rotate left'
      TabOrder = 6
      OnClick = btnRotateLeftClick
    end
    object btnRotateRight: TButton
      Left = 515
      Top = 8
      Width = 75
      Height = 25
      Caption = 'Rotate right'
      TabOrder = 7
      OnClick = btnRotateRightClick
    end
    object btnFlipH: TButton
      Left = 606
      Top = 8
      Width = 60
      Height = 25
      Caption = 'Flip H'
      TabOrder = 8
      OnClick = btnFlipHClick
    end
    object btnFlipV: TButton
      Left = 670
      Top = 8
      Width = 60
      Height = 25
      Caption = 'Flip V'
      TabOrder = 9
      OnClick = btnFlipVClick
    end
    object chkReadOnly: TCheckBox
      Left = 748
      Top = 12
      Width = 89
      Height = 17
      Caption = 'Read-&only'
      TabOrder = 10
      OnClick = chkReadOnlyClick
    end
    object btnRotatePicture: TButton
      Left = 840
      Top = 8
      Width = 100
      Height = 25
      Hint = 'Rotates the picture itself (RotatePicture), keeping its format'
      Caption = 'Rotate picture'
      ParentShowHint = False
      ShowHint = True
      TabOrder = 11
      OnClick = btnRotatePictureClick
    end
    object chkScrollBars: TCheckBox
      Left = 952
      Top = 12
      Width = 89
      Height = 17
      Caption = 'Scroll &bars'
      TabOrder = 12
      OnClick = chkScrollBarsClick
    end
  end
  object pgcDemo: TPageControl
    Left = 0
    Top = 41
    Width = 1060
    Height = 580
    ActivePage = tsViewer
    Align = alClient
    TabOrder = 1
    OnChange = pgcDemoChange
    object tsViewer: TTabSheet
      Caption = 'TgllImageView (stand-alone)'
    end
    object tsDatabase: TTabSheet
      Caption = 'TgllDBImage (data-aware)'
      ImageIndex = 1
      object pnlRecord: TPanel
        Left = 0
        Top = 0
        Width = 972
        Height = 37
        Align = alTop
        BevelOuter = bvNone
        TabOrder = 0
        object lblCaption: TLabel
          Left = 264
          Top = 10
          Width = 42
          Height = 15
          Caption = 'Caption'
        end
        object navRecords: TDBNavigator
          Left = 4
          Top = 6
          Width = 240
          Height = 25
          DataSource = dsPictures
          VisibleButtons = [nbFirst, nbPrior, nbNext, nbLast, nbInsert, nbDelete, nbPost, nbCancel]
          TabOrder = 0
        end
        object edtCaption: TDBEdit
          Left = 312
          Top = 7
          Width = 250
          Height = 23
          DataField = 'Caption'
          DataSource = dsPictures
          TabOrder = 1
        end
      end
    end
  end
  object sbStatus: TStatusBar
    Left = 0
    Top = 621
    Width = 1060
    Height = 19
    Panels = <
      item
        Width = 220
      end
      item
        Width = 160
      end
      item
        Width = 50
      end>
  end
  object dsPictures: TDataSource
    Left = 840
    Top = 120
  end
end
