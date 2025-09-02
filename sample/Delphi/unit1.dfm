object Form1: TForm1
  Left = 297
  Top = 190
  Caption = 'Form1'
  ClientHeight = 513
  ClientWidth = 544
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = True
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 14
    Top = 13
    Width = 23
    Height = 13
    Caption = '&URL:'
    FocusControl = URL
  end
  object Button1: TButton
    Left = 232
    Top = 472
    Width = 75
    Height = 25
    Caption = '&Download'
    TabOrder = 0
    OnClick = Button1Click
  end
  object Memo1: TMemo
    Left = 12
    Top = 44
    Width = 521
    Height = 416
    Font.Charset = SHIFTJIS_CHARSET
    Font.Color = clBlack
    Font.Height = -13
    Font.Name = #28216#12468#12471#12483#12463
    Font.Pitch = fpVariable
    Font.Style = []
    Font.Quality = fqDraft
    Lines.Strings = (
      'URL'#12395#23567#35500#23478#12395#12394#12429#12358#20316#21697#12488#12483#12503#12506#12540#12472#12398'URL'#12434#20837#21147#12375#12390'Download'#12508#12479#12531#12434#25276#12377
      #12392#12381#12398#20316#21697#12434#12480#12454#12531#12525#12540#12489#12375#12414#12377#12290
      #23578#12289#12469#12531#12503#12523#12394#12398#12391#31456#12479#12452#12488#12523#12289#21069#26360#12365#12289#24460#26360#12365#12399#21462#24471#12375#12390#12356#12414#12379#12435#12290#30701#32232#12418#21462#24471
      #20986#26469#12414#12379#12435#12290
      #12414#12383#12289'HTML'#12497#12540#12469#12540#33258#20307#12364#31777#26131#30340#12394#12418#12398#12394#12398#12391#12289#12523#12499#12420#25407#32117#24773#22577#12434#21462#24471#12377#12427#12371#12392
      #12418#20986#26469#12414#12379#12435#12290)
    ParentFont = False
    ScrollBars = ssVertical
    TabOrder = 1
  end
  object URL: TEdit
    Left = 53
    Top = 10
    Width = 479
    Height = 21
    TabOrder = 2
  end
end
