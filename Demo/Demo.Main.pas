(* Copyright (c) 2026 Ian Branch. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style
 * license that can be found in the LICENSE file.
 *)

/// <summary>
///   Main form of the gllImage demo: a stand-alone TgllImageView on the first page, and a TgllDBImage bound to an
///   in-memory dataset on the second, both driven by the same toolbar.
/// </summary>
unit Demo.Main;

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Classes,
  Data.DB, Datasnap.DBClient,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.DBCtrls,
  Vcl.Mask,
  gllImage.Utils, gllImage.View, gllImage.DB;

type
  /// <summary>The demo's main form.</summary>
  TDemoMainForm = class( TForm )
    /// <summary>Toolbar panel holding the view buttons.</summary>
    pnlToolbar: TPanel;
    /// <summary>Opens a picture file into the active control.</summary>
    btnOpen: TButton;
    /// <summary>Saves the active control's picture to a file.</summary>
    btnSave: TButton;
    /// <summary>Toggles FitToWindow.</summary>
    chkFit: TCheckBox;
    /// <summary>Zooms in.</summary>
    btnZoomIn: TButton;
    /// <summary>Zooms out.</summary>
    btnZoomOut: TButton;
    /// <summary>Resets the view to 100%, no pan, no rotation.</summary>
    btnReset: TButton;
    /// <summary>Rotates the display anticlockwise.</summary>
    btnRotateLeft: TButton;
    /// <summary>Rotates the display clockwise.</summary>
    btnRotateRight: TButton;
    /// <summary>Flips the picture horizontally.</summary>
    btnFlipH: TButton;
    /// <summary>Flips the picture vertically.</summary>
    btnFlipV: TButton;
    /// <summary>Toggles ReadOnly on the active control.</summary>
    chkReadOnly: TCheckBox;
    /// <summary>Toggles ScrollBars on the active control.</summary>
    chkScrollBars: TCheckBox;
    /// <summary>Rotates the picture itself 90 degrees clockwise (RotatePicture), keeping its format.</summary>
    btnRotatePicture: TButton;
    /// <summary>The two demo pages.</summary>
    pgcDemo: TPageControl;
    /// <summary>Page holding the stand-alone viewer.</summary>
    tsViewer: TTabSheet;
    /// <summary>Page holding the data-aware control.</summary>
    tsDatabase: TTabSheet;
    /// <summary>Record navigation and caption editing above the data-aware control.</summary>
    pnlRecord: TPanel;
    /// <summary>Moves between, adds and deletes records.</summary>
    navRecords: TDBNavigator;
    /// <summary>Edits the record's caption.</summary>
    edtCaption: TDBEdit;
    /// <summary>Label for edtCaption.</summary>
    lblCaption: TLabel;
    /// <summary>Format, size, zoom and errors of the active control.</summary>
    sbStatus: TStatusBar;
    /// <summary>Data source the data-aware control is bound to.</summary>
    dsPictures: TDataSource;

    /// <summary>Creates the image controls and the in-memory dataset.</summary>
    /// <param name="Sender">The form.</param>
    procedure FormCreate( Sender: TObject );
    /// <summary>Opens a picture file into the active control.</summary>
    /// <param name="Sender">The button.</param>
    procedure btnOpenClick( Sender: TObject );
    /// <summary>Saves the active control's picture to a file.</summary>
    /// <param name="Sender">The button.</param>
    procedure btnSaveClick( Sender: TObject );
    /// <summary>Applies the Fit check box to the active control.</summary>
    /// <param name="Sender">The check box.</param>
    procedure chkFitClick( Sender: TObject );
    /// <summary>Zooms the active control in.</summary>
    /// <param name="Sender">The button.</param>
    procedure btnZoomInClick( Sender: TObject );
    /// <summary>Zooms the active control out.</summary>
    /// <param name="Sender">The button.</param>
    procedure btnZoomOutClick( Sender: TObject );
    /// <summary>Resets the active control's view.</summary>
    /// <param name="Sender">The button.</param>
    procedure btnResetClick( Sender: TObject );
    /// <summary>Rotates the active control's display anticlockwise.</summary>
    /// <param name="Sender">The button.</param>
    procedure btnRotateLeftClick( Sender: TObject );
    /// <summary>Rotates the active control's display clockwise.</summary>
    /// <param name="Sender">The button.</param>
    procedure btnRotateRightClick( Sender: TObject );
    /// <summary>Flips the active control's picture horizontally.</summary>
    /// <param name="Sender">The button.</param>
    procedure btnFlipHClick( Sender: TObject );
    /// <summary>Flips the active control's picture vertically.</summary>
    /// <param name="Sender">The button.</param>
    procedure btnFlipVClick( Sender: TObject );
    /// <summary>Applies the Read-only check box to the active control.</summary>
    /// <param name="Sender">The check box.</param>
    procedure chkReadOnlyClick( Sender: TObject );
    /// <summary>Syncs the toolbar and status bar with the newly active page.</summary>
    /// <param name="Sender">The page control.</param>
    procedure pgcDemoChange( Sender: TObject );
    /// <summary>Applies the Scroll bars check box to the active control.</summary>
    /// <param name="Sender">The check box.</param>
    procedure chkScrollBarsClick( Sender: TObject );
    /// <summary>Rotates the active control's picture itself, and posts it on the Database page.</summary>
    /// <param name="Sender">The button.</param>
    procedure btnRotatePictureClick( Sender: TObject );
  private
    /// <summary>The stand-alone viewer; owned by the form.</summary>
    FView: TgllImageView;
    /// <summary>The data-aware control; owned by the form.</summary>
    FDBImage: TgllDBImage;
    /// <summary>In-memory dataset with ID, Caption and Picture columns; owned by the form.</summary>
    FData: TClientDataSet;

    /// <summary>The control on the active page.</summary>
    /// <returns>FView on the Viewer page, FDBImage on the Database page.</returns>
    function ActiveImage: TgllCustomImageView;
    /// <summary>Shows the active control's format, size, zoom and last error in the status bar.</summary>
    procedure UpdateStatus;
    /// <summary>Refreshes the status bar after a load, a zoom, a rotation or a flip.</summary>
    /// <param name="Sender">The image control.</param>
    procedure ImageChanged( Sender: TObject );
    /// <summary>Creates the dataset and fills it with two sample records.</summary>
    procedure CreateSampleData;
    /// <summary>Posts the record when a change through the data-aware control left it in edit mode.</summary>
    procedure PostIfEditing;
  end;

var
  /// <summary>The demo's main form instance.</summary>
  DemoMainForm: TDemoMainForm;

implementation

{$R *.dfm}

uses
  MidasLib;

const
  /// <summary>File filter for the Open dialog.</summary>
  OPEN_FILTER = 'All images|*.jxl;*.jpg;*.jpeg;*.png;*.bmp;*.gif;*.tif;*.tiff;*.ico;*.wmf;*.emf|All files|*.*';
  /// <summary>File filter for the Save dialog.</summary>
  SAVE_FILTER = 'JPEG XL|*.jxl|JPEG|*.jpg|PNG|*.png|Bitmap|*.bmp|GIF|*.gif';

/// <summary>Draws a sample picture: a gradient with a caption, so the demo has something to show at once.</summary>
/// <param name="ACaption">Text drawn in the middle.</param>
/// <param name="AColour">Colour the gradient runs to.</param>
/// <returns>The bitmap; the caller frees it.</returns>
function NewSampleBitmap( const ACaption: string; AColour: TColor ): TBitmap;
begin

  Result := TBitmap.Create;
  Result.PixelFormat := pf24bit;
  Result.SetSize( 800, 500 );

  for var lY := 0 to Result.Height - 1 do
  begin
    var lMix := lY / Result.Height;
    Result.Canvas.Pen.Color := RGB( Round( GetRValue( AColour ) * lMix + 255 * ( 1 - lMix ) ),
                                    Round( GetGValue( AColour ) * lMix + 255 * ( 1 - lMix ) ),
                                    Round( GetBValue( AColour ) * lMix + 255 * ( 1 - lMix ) ) );
    Result.Canvas.MoveTo( 0, lY );
    Result.Canvas.LineTo( Result.Width, lY );
  end;

  Result.Canvas.Brush.Style := bsClear;
  Result.Canvas.Font.Name   := 'Segoe UI';
  Result.Canvas.Font.Size   := 36;
  Result.Canvas.Font.Color  := clBlack;
  Result.Canvas.TextOut( ( Result.Width - Result.Canvas.TextWidth( ACaption ) ) div 2,
                         ( Result.Height - Result.Canvas.TextHeight( ACaption ) ) div 2, ACaption );

  // An arrow in the top-left corner, so rotation and flips are easy to follow.
  Result.Canvas.Pen.Color   := clBlack;
  Result.Canvas.Pen.Width   := 6;
  Result.Canvas.MoveTo( 30, 120 );
  Result.Canvas.LineTo( 30, 30 );
  Result.Canvas.LineTo( 120, 30 );
  Result.Canvas.MoveTo( 30, 30 );
  Result.Canvas.LineTo( 110, 110 );

end;

/// <summary>Finds a sample file shipped beside the demo: next to the exe, or in the Demo folder two levels up
/// (Win64\Release).</summary>
/// <param name="AName">The file name.</param>
/// <returns>The full path, or empty when it is in neither place.</returns>
function FindSample( const AName: string ): string;
begin

  var lExeDir := ExtractFilePath( ParamStr( 0 ) );

  for var lCandidate in [ lExeDir + AName, ExpandFileName( lExeDir + '..\..\' + AName ) ] do
    if FileExists( lCandidate ) then
      Exit( lCandidate );

  Result := '';

end;

procedure TDemoMainForm.FormCreate( Sender: TObject );
begin

  FView                := TgllImageView.Create( Self );
  FView.Parent         := tsViewer;
  FView.Align          := alClient;
  FView.FitToWindow    := True;
  FView.NoPicture      := 'Open a picture, or drop an image file here';
  FView.EnableDragOut  := True;   // drag the picture out to Explorer (Ctrl+drag while it can be panned)
  FView.OnImageLoaded  := ImageChanged;
  FView.OnImageError   := ImageChanged;
  FView.OnZoomChanged  := ImageChanged;
  FView.OnRotated      := ImageChanged;
  FView.OnFlipped      := ImageChanged;

  var lSample := FindSample( 'Sample-Landscape.jxl' );

  if lSample <> '' then
    FView.LoadFromFile( lSample )
  else
  begin
    var lBmp := NewSampleBitmap( 'TgllImageView', clSkyBlue );

    try
      FView.Picture.Assign( lBmp );
    finally
      lBmp.Free;
    end;
  end;

  CreateSampleData;

  FDBImage               := TgllDBImage.Create( Self );
  FDBImage.Parent        := tsDatabase;
  FDBImage.Align         := alClient;
  FDBImage.FitToWindow   := True;
  FDBImage.EnableDragOut := True;
  FDBImage.DataSource    := dsPictures;
  FDBImage.DataField     := 'Picture';
  FDBImage.OnImageLoaded := ImageChanged;
  FDBImage.OnImageError  := ImageChanged;
  FDBImage.OnZoomChanged := ImageChanged;
  FDBImage.OnRotated     := ImageChanged;
  FDBImage.OnFlipped     := ImageChanged;

  pgcDemo.ActivePage := tsViewer;
  pgcDemoChange( pgcDemo );

end;

procedure TDemoMainForm.CreateSampleData;
begin

  FData := TClientDataSet.Create( Self );
  FData.FieldDefs.Add( 'ID', ftAutoInc );
  FData.FieldDefs.Add( 'Caption', ftString, 60 );
  FData.FieldDefs.Add( 'Picture', ftBlob );
  FData.CreateDataSet;
  FData.FieldByName( 'Picture' ).DisplayLabel := 'Picture';
  dsPictures.DataSet := FData;

  // The first record holds the portrait JPEG XL sample exactly as stored on disk; the second a drawn bitmap.
  var lPortrait := FindSample( 'Sample-Portrait.jxl' );

  if lPortrait <> '' then
  begin
    FData.Append;
    FData.FieldByName( 'Caption' ).AsString := 'JPEG XL record (Sample-Portrait.jxl)';
    TBlobField( FData.FieldByName( 'Picture' ) ).LoadFromFile( lPortrait );
    FData.Post;
  end;

  var lBmp := NewSampleBitmap( 'Bitmap record', clMoneyGreen );
  var lMs  := TMemoryStream.Create;

  try
    lBmp.SaveToStream( lMs );
    lMs.Position := 0;
    FData.Append;
    FData.FieldByName( 'Caption' ).AsString := 'Bitmap record';
    TBlobField( FData.FieldByName( 'Picture' ) ).LoadFromStream( lMs );
    FData.Post;
  finally
    lMs.Free;
    lBmp.Free;
  end;

  FData.First;

end;

function TDemoMainForm.ActiveImage: TgllCustomImageView;
begin

  Result := if pgcDemo.ActivePage = tsDatabase then TgllCustomImageView( FDBImage ) else FView;

end;

procedure TDemoMainForm.UpdateStatus;
begin

  var lImage := ActiveImage;

  if lImage = nil then
    Exit;

  if lImage.HasImage then
    sbStatus.Panels[ 0 ].Text := Format( '%s  %d x %d', [ lImage.ImageFormat, lImage.ImageWidth, lImage.ImageHeight ] )
  else
    sbStatus.Panels[ 0 ].Text := 'No picture';

  sbStatus.Panels[ 1 ].Text := if lImage.FitToWindow then 'Fit to window'
                               else Format( 'Zoom %d%%', [ Round( lImage.ZoomFactor * 100 ) ] );
  sbStatus.Panels[ 2 ].Text := lImage.LastError;

end;

procedure TDemoMainForm.ImageChanged( Sender: TObject );
begin

  if Sender = ActiveImage then
    UpdateStatus;

end;

procedure TDemoMainForm.pgcDemoChange( Sender: TObject );
begin

  var lImage := ActiveImage;

  if lImage = nil then
    Exit;

  chkFit.Checked        := lImage.FitToWindow;
  chkReadOnly.Checked   := lImage.ReadOnly;
  chkScrollBars.Checked := lImage.ScrollBars;
  UpdateStatus;

end;

procedure TDemoMainForm.btnOpenClick( Sender: TObject );
begin

  var lDialog := TOpenDialog.Create( nil );

  try
    lDialog.Filter := OPEN_FILTER;

    if lDialog.Execute then
    begin
      ActiveImage.LoadFromFile( lDialog.FileName );

      PostIfEditing;
    end;
  finally
    lDialog.Free;
  end;

  UpdateStatus;

end;

procedure TDemoMainForm.btnSaveClick( Sender: TObject );
begin

  if not ActiveImage.HasImage then
    Exit;

  var lDialog := TSaveDialog.Create( nil );

  try
    lDialog.Filter     := SAVE_FILTER;
    lDialog.DefaultExt := 'jxl';
    lDialog.Options    := lDialog.Options + [ ofOverwritePrompt ];

    if lDialog.Execute then
      ActiveImage.SaveToFile( lDialog.FileName );
  finally
    lDialog.Free;
  end;

  UpdateStatus;

end;

procedure TDemoMainForm.chkFitClick( Sender: TObject );
begin

  ActiveImage.FitToWindow := chkFit.Checked;
  UpdateStatus;

end;

procedure TDemoMainForm.btnZoomInClick( Sender: TObject );
begin

  // Zooming needs FitToWindow off, or the picture keeps being fitted.
  chkFit.Checked := False;
  ActiveImage.ZoomIn;

end;

procedure TDemoMainForm.btnZoomOutClick( Sender: TObject );
begin

  chkFit.Checked := False;
  ActiveImage.ZoomOut;

end;

procedure TDemoMainForm.btnResetClick( Sender: TObject );
begin

  ActiveImage.ResetView;

end;

procedure TDemoMainForm.btnRotateLeftClick( Sender: TObject );
begin

  ActiveImage.RotateCounterClockwise;

end;

procedure TDemoMainForm.btnRotateRightClick( Sender: TObject );
begin

  ActiveImage.RotateClockwise;

end;

procedure TDemoMainForm.btnFlipHClick( Sender: TObject );
begin

  ActiveImage.FlipHorizontal;

  PostIfEditing;

end;

procedure TDemoMainForm.btnFlipVClick( Sender: TObject );
begin

  ActiveImage.FlipVertical;

  PostIfEditing;

end;

procedure TDemoMainForm.chkReadOnlyClick( Sender: TObject );
begin

  ActiveImage.ReadOnly := chkReadOnly.Checked;

end;

procedure TDemoMainForm.PostIfEditing;
begin

  // A change through the data-aware control puts the record into edit mode; post it so the picture is stored.
  if ( ActiveImage = FDBImage ) and ( FData.State in [ dsEdit, dsInsert ] ) then
    FData.Post;

end;

procedure TDemoMainForm.chkScrollBarsClick( Sender: TObject );
begin

  ActiveImage.ScrollBars := chkScrollBars.Checked;

end;

procedure TDemoMainForm.btnRotatePictureClick( Sender: TObject );
begin

  ActiveImage.RotatePicture( ro90 );
  PostIfEditing;
  UpdateStatus;

end;

end.
