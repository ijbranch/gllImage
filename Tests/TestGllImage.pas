(* Copyright (c) 2026 Ian Branch. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style
 * license that can be found in the LICENSE file.
 *)

/// <summary>
///   Tests for gllImage: the format-loader registry, the stand-alone TgllImageView, and the data link of
///   TgllDBImage over the viewer base it shares with TgllImageView.
/// </summary>
unit TestGllImage;

interface

uses
  System.Classes, System.SysUtils,
  Data.DB, Datasnap.DBClient,
  Winapi.Windows, Winapi.Messages, Winapi.ShlObj,
  Vcl.Graphics, Vcl.Imaging.Jpeg, Vcl.Forms,
  DUnitX.TestFramework,
  Jxl.Api.Types, Jxl.Graphic,
  gllImage.Utils, gllImage.View, gllImage.DB;

type
  /// <summary>Exposes the protected hooks of TgllImageView to the tests.</summary>
  TViewProbe = class( TgllImageView )
  public
    /// <summary>Calls the protected GetPlaceholderCaption.</summary>
    /// <returns>The caption the viewer draws before a picture loads.</returns>
    function PlaceholderCaption : string;
  end;

  /// <summary>Exposes the protected hooks of TgllDBImage to the tests.</summary>
  TDBImageProbe = class( TgllDBImage )
  public
    /// <summary>Calls the protected GetPlaceholderCaption.</summary>
    /// <returns>The caption the control draws before a picture loads.</returns>
    function PlaceholderCaption : string;
  end;

  /// <summary>Tests of TgllImageFormatRegistry.</summary>
  [TestFixture]
  TTestFormatRegistry = class
  public
    /// <summary>Proves unregistering one loader leaves another loader's extensions mapped (moved from GITLAKDB's
    ///   TestClientLayerFixes with the unit).</summary>
    [Test] procedure Unregister_KeepsOtherLoadersExtensions;
  end;

  /// <summary>Tests of the stand-alone viewer TgllImageView.</summary>
  [TestFixture]
  TTestImageView = class
  private
    /// <summary>The viewer under test; created per test.</summary>
    FView : TViewProbe;
    /// <summary>Number of OnImageError calls seen.</summary>
    FErrors : Integer;
    /// <summary>The file names the last OnFilesDropped received.</summary>
    FDropped : TArray<string>;
    /// <summary>Counts OnImageError calls.</summary>
    /// <param name="Sender">The viewer.</param>
    procedure ImageError( Sender : TObject );
    /// <summary>Records the dropped files and takes the drop over.</summary>
    /// <param name="Sender">The viewer.</param>
    /// <param name="FileNames">The dropped files.</param>
    /// <param name="Handled">Set True.</param>
    procedure FilesDropped( Sender : TObject; const FileNames : TArray<string>; var Handled : Boolean );
  public
    /// <summary>Creates the viewer.</summary>
    [Setup] procedure Setup;
    /// <summary>Frees the viewer.</summary>
    [TearDown] procedure TearDown;
    /// <summary>Proves LoadFromFile loads a PNG into the viewer's own picture: there is no field to go through.</summary>
    [Test] procedure LoadFromFile_Png_IsShown;
    /// <summary>Proves a read-only viewer refuses LoadFromFile with LastError and OnImageError and keeps its picture,
    ///   i.e. the base CanModify answers from ReadOnly.</summary>
    [Test] procedure LoadFromFile_ReadOnly_IsRefused;
    /// <summary>Proves FlipHorizontal changes the viewer's picture when it may be modified.</summary>
    [Test] procedure FlipHorizontal_Writable_MirrorsPixels;
    /// <summary>Proves FlipHorizontal leaves a read-only viewer's picture alone.</summary>
    [Test] procedure FlipHorizontal_ReadOnly_DoesNothing;
    /// <summary>Proves the viewer's placeholder caption is its Name (it has no field to name).</summary>
    [Test] procedure PlaceholderCaption_IsName;
    /// <summary>Proves a centred picture wider than the control pans exactly as far as its overhang, half each way,
    ///   and that the scroll position runs from 0 at its left edge.</summary>
    [Test] procedure Pan_Centred_StopsAtTheOverhang;
    /// <summary>Proves an uncentred picture pans only leftwards, by its whole overhang (the old clamp allowed half
    ///   each way, so half the picture could never be reached and an empty band could be dragged into view).</summary>
    [Test] procedure Pan_Uncentred_MovesOneWay;
    /// <summary>Proves the pan limits follow the display rotation: a landscape picture turned 90 degrees pans along
    ///   its new long side (the old clamp used the unrotated size).</summary>
    [Test] procedure Pan_Rotated90_FollowsTheLongSide;
    /// <summary>Proves a picture fitted to the window cannot be panned: it fills the control.</summary>
    [Test] procedure Pan_Fitted_IsZero;
    /// <summary>Proves RotatePicture turns the pixels themselves (not just the display) and keeps the PNG a PNG.</summary>
    [Test] procedure RotatePicture_TurnsPixelsAndKeepsPng;
    /// <summary>Proves RotatePicture leaves a read-only viewer's picture alone.</summary>
    [Test] procedure RotatePicture_ReadOnly_DoesNothing;
    /// <summary>Proves a flipped JPEG is still a JPEG (it used to become a bitmap, and so was stored as BMP).</summary>
    [Test] procedure FlipHorizontal_KeepsJpeg;
    /// <summary>Proves SaveToFile with a .jxl name writes JPEG XL even from a PNG: without a handler it wrote the
    ///   graphic's own format under the .jxl name. Needs the libjxl DLLs.</summary>
    [Test] procedure SaveToFile_Jxl_WritesJpegXl;
    /// <summary>Proves a zoom step on a fitted picture continues from the scale it is shown at (it used to do
    ///   nothing visible, the fit overriding the new ZoomFactor).</summary>
    [Test] procedure ZoomBy_FromFitted_ContinuesAtFittedScale;
    /// <summary>Proves RotatePicture turns the picture as seen: a display rotation already applied is baked in too.</summary>
    [Test] procedure RotatePicture_IncludesDisplayRotation;
    /// <summary>Proves RotatePicture( ro0 ) bakes in just the display rotation.</summary>
    [Test] procedure RotatePicture_Ra0_BakesDisplayRotation;
    /// <summary>Proves TDBImage's Stretch / Proportional map onto the fit properties as TDBImage draws them.</summary>
    [Test] procedure StretchProportional_MapToFitProperties;
    /// <summary>Proves a TDBImage-style form (Proportional, Stretch) streams into TgllDBImage and comes out fitted.</summary>
    [Test] procedure TDBImageStyleDfm_Streams;
    /// <summary>Proves a dropped file list reaches OnFilesDropped in full, and that Handled stops the control loading
    ///   the first file itself.</summary>
    [Test] procedure DropFiles_ReachesHandler;
  end;

  /// <summary>Tests of the format routines in gllImage.Utils.</summary>
  [TestFixture]
  TTestFormats = class
  public
    /// <summary>Proves both JPEG XL signatures (bare codestream and container) are detected as TJxlImage.</summary>
    [Test] procedure Detect_JxlSignatures_AreJxl;
    /// <summary>Proves a TIFF signature is detected as TWICImage (TIFF without GraphicEx).</summary>
    [Test] procedure Detect_TiffSignature_IsWic;
    /// <summary>Proves the old TDBImage header is removed from the front of a bitmap, leaving its bytes intact.</summary>
    [Test] procedure StripLegacyHeader_RemovesHeader;
    /// <summary>Proves a stream without the header is left exactly as it was.</summary>
    [Test] procedure StripLegacyHeader_LeavesOtherDataAlone;
  end;

  /// <summary>Tests of the data link TgllDBImage adds to the viewer base.</summary>
  [TestFixture]
  TTestDBImage = class
  private
    /// <summary>In-memory dataset with an ID and a BLOB column.</summary>
    FData : TClientDataSet;
    /// <summary>Data source the control is bound to.</summary>
    FSource : TDataSource;
    /// <summary>The control under test, bound to Pic.</summary>
    FImage : TDBImageProbe;
  public
    /// <summary>Creates the dataset holding one row whose Pic is a 2 x 1 bitmap (red, blue), and binds the control.</summary>
    [Setup] procedure Setup;
    /// <summary>Frees the control and the dataset.</summary>
    [TearDown] procedure TearDown;
    /// <summary>Proves the picture is loaded from the field when the record is shown (AutoDisplay).</summary>
    [Test] procedure Open_LoadsPictureFromField;
    /// <summary>Proves a flip puts the dataset into edit, marks the record modified and is written back to the field
    ///   on Post: TgllDBImage's CanModify and PictureModified overrides and UpdateData all take part.</summary>
    [Test] procedure FlipHorizontal_PostsMirroredPicture;
    /// <summary>Proves a read-only control neither edits the dataset nor changes the picture when asked to flip.</summary>
    [Test] procedure FlipHorizontal_ReadOnly_LeavesRecordAlone;
    /// <summary>Proves the placeholder caption is the linked field's DisplayLabel.</summary>
    [Test] procedure PlaceholderCaption_IsFieldDisplayLabel;
    /// <summary>Proves a picture stored behind the old TDBImage header is shown, not reported as unknown.</summary>
    [Test] procedure Open_LegacyHeader_LoadsPicture;
    /// <summary>Proves LoadFromFile stores the file's own bytes: before the fix the record was also marked modified,
    ///   so Post replaced them with the picture re-encoded.</summary>
    [Test] procedure LoadFromFile_StoresFileBytesVerbatim;
    /// <summary>Proves a JPEG XL BLOB is shown as JPEG XL, and that a saved rotation is written back as JPEG XL
    ///   with the pixels turned. Needs the libjxl DLLs beside the runner (the post-build step copies them).</summary>
    [Test] procedure Jxl_ShowsAndRotatesAsJxl;
    /// <summary>Proves a form that still names the old GITLAKDB class TGDBImage streams in as TgllDBImage.</summary>
    [Test] procedure OldClassName_IsAliased;
  end;

implementation

uses
  System.IOUtils,
  Vcl.Imaging.PngImage,
  gllImage.Consts,
  MidasLib;

type
  /// <summary>A loader stub that only reports the extensions it was created with.</summary>
  TStubLoader = class( TInterfacedObject, IgllImageLoader )
  private
    /// <summary>The extensions this stub claims.</summary>
    FExtensions : TArray<string>;
  public
    /// <summary>Creates a stub claiming the given extensions.</summary>
    /// <param name="AExtensions">Extensions including the leading dot.</param>
    constructor Create( const AExtensions : TArray<string> );
    /// <summary>Returns the claimed extensions.</summary>
    /// <returns>The extensions passed to the constructor.</returns>
    function GetExtensions : TArray<string>;
    /// <summary>Never recognises a stream.</summary>
    /// <param name="Stream">Ignored.</param>
    /// <returns>False.</returns>
    function CanLoad( Stream : TStream ) : Boolean;
    /// <summary>Never loads anything.</summary>
    /// <param name="Stream">Ignored.</param>
    /// <returns>nil.</returns>
    function Load( Stream : TStream ) : TGraphic;
    /// <summary>Returns a fixed name.</summary>
    /// <returns>'Stub'.</returns>
    function GetFormatName : string;
  end;

constructor TStubLoader.Create( const AExtensions : TArray<string> );
begin

  inherited Create;
  FExtensions := AExtensions;

end;

function TStubLoader.GetExtensions : TArray<string>;
begin

  Result := FExtensions;

end;

function TStubLoader.CanLoad( Stream : TStream ) : Boolean;
begin

  Result := False;

end;

function TStubLoader.Load( Stream : TStream ) : TGraphic;
begin

  Result := nil;

end;

function TStubLoader.GetFormatName : string;
begin

  Result := 'Stub';

end;

/// <summary>Creates a 2 x 1 bitmap: red on the left, blue on the right.</summary>
/// <returns>The bitmap; the caller frees it.</returns>
function NewRedBlueBitmap : TBitmap;
begin

  Result := TBitmap.Create;
  Result.PixelFormat := pf24bit;
  Result.SetSize( 2, 1 );
  Result.Canvas.Pixels[ 0, 0 ] := clRed;
  Result.Canvas.Pixels[ 1, 0 ] := clBlue;

end;

/// <summary>Reads pixel X of row 0 of a graphic, drawn onto a plain 24-bit bitmap.</summary>
/// <param name="AGraphic">The graphic.</param>
/// <param name="X">The column.</param>
/// <returns>The pixel's colour.</returns>
function PixelOf( AGraphic : TGraphic; X : Integer ) : TColor;
begin

  var lBmp := TBitmap.Create;

  try
    lBmp.PixelFormat := pf24bit;
    lBmp.SetSize( AGraphic.Width, AGraphic.Height );
    lBmp.Canvas.Draw( 0, 0, AGraphic );
    Result := lBmp.Canvas.Pixels[ X, 0 ];
  finally
    lBmp.Free;
  end;

end;

/// <summary>Reads pixel X, Y of a graphic, drawn onto a plain 24-bit bitmap.</summary>
/// <param name="AGraphic">The graphic.</param>
/// <param name="X">The column.</param>
/// <param name="Y">The row.</param>
/// <returns>The pixel's colour.</returns>
function PixelAt( AGraphic : TGraphic; X, Y : Integer ) : TColor;
begin

  var lBmp := TBitmap.Create;

  try
    lBmp.PixelFormat := pf24bit;
    lBmp.SetSize( AGraphic.Width, AGraphic.Height );
    lBmp.Canvas.Draw( 0, 0, AGraphic );
    Result := lBmp.Canvas.Pixels[ X, Y ];
  finally
    lBmp.Free;
  end;

end;

/// <summary>Creates a plain grey bitmap of the given size.</summary>
/// <param name="AWidth">Width in pixels.</param>
/// <param name="AHeight">Height in pixels.</param>
/// <returns>The bitmap; the caller frees it.</returns>
function NewBitmap( AWidth, AHeight : Integer ) : TBitmap;
begin

  Result := TBitmap.Create;
  Result.PixelFormat := pf24bit;
  Result.SetSize( AWidth, AHeight );
  Result.Canvas.Brush.Color := clGray;
  Result.Canvas.FillRect( Rect( 0, 0, AWidth, AHeight ) );

end;

/// <summary>Returns a stream's whole content.</summary>
/// <param name="AStream">The stream; its position is not restored.</param>
/// <returns>Every byte of the stream.</returns>
function StreamBytes( AStream : TStream ) : TBytes;
begin

  SetLength( Result, AStream.Size );
  AStream.Position := 0;

  if Length( Result ) > 0 then
    AStream.ReadBuffer( Result[ 0 ], Length( Result ) );

end;

/// <summary>Writes the old TDBImage header (Count 1, HType $0100, Size) and then a bitmap's bytes to a stream.</summary>
/// <param name="ABitmap">The bitmap.</param>
/// <param name="AStream">The stream to write.</param>
procedure WriteWithLegacyHeader( ABitmap : TBitmap; AStream : TStream );
begin

  var lBody := TMemoryStream.Create;

  try
    ABitmap.SaveToStream( lBody );

    var lCount : Word    := 1;
    var lHType : Word    := $0100;
    var lSize  : Integer := lBody.Size;

    AStream.WriteBuffer( lCount, SizeOf( lCount ) );
    AStream.WriteBuffer( lHType, SizeOf( lHType ) );
    AStream.WriteBuffer( lSize, SizeOf( lSize ) );
    lBody.Position := 0;
    AStream.CopyFrom( lBody, lBody.Size );
  finally
    lBody.Free;
  end;

end;

{ TViewProbe }

function TViewProbe.PlaceholderCaption : string;
begin

  Result := GetPlaceholderCaption;

end;

{ TDBImageProbe }

function TDBImageProbe.PlaceholderCaption : string;
begin

  Result := GetPlaceholderCaption;

end;

{ TTestFormatRegistry }

procedure TTestFormatRegistry.Unregister_KeepsOtherLoadersExtensions;
var
  lFirst  : IgllImageLoader;
  lSecond : IgllImageLoader;
begin

  lFirst  := TStubLoader.Create( [ '.zzq' ] );
  lSecond := TStubLoader.Create( [ '.zzq', '.zzr' ] );
  TgllImageFormatRegistry.RegisterLoader( lFirst );
  TgllImageFormatRegistry.RegisterLoader( lSecond );

  try
    TgllImageFormatRegistry.UnregisterLoader( lSecond );
    Assert.IsTrue( TgllImageFormatRegistry.GetLoaderForExtension( '.zzq' ) = lFirst,
      'The first loader must keep .zzq when the second is unregistered' );
    Assert.IsTrue( TgllImageFormatRegistry.GetLoaderForExtension( '.zzr' ) = nil,
      'The second loader''s own extension must go' );
  finally
    TgllImageFormatRegistry.UnregisterLoader( lFirst );
    TgllImageFormatRegistry.UnregisterLoader( lSecond );
  end;

end;

{ TTestImageView }

procedure TTestImageView.ImageError( Sender : TObject );
begin

  Inc( FErrors );

end;

procedure TTestImageView.Setup;
begin

  FView              := TViewProbe.Create( nil );
  FView.Name         := 'PhotoView';
  FView.OnImageError := ImageError;
  FErrors            := 0;

end;

procedure TTestImageView.TearDown;
begin

  FreeAndNil( FView );

end;

procedure TTestImageView.LoadFromFile_Png_IsShown;
begin

  var lFile := TPath.Combine( TPath.GetTempPath, 'gllImageTest-' + TGUID.NewGuid.ToString + '.png' );
  var lBmp  := NewRedBlueBitmap;

  try
    var lPng := TPngImage.Create;

    try
      lPng.Assign( lBmp );
      lPng.SaveToFile( lFile );
    finally
      lPng.Free;
    end;

    FView.LoadFromFile( lFile );

    Assert.IsTrue( FView.HasImage, 'The PNG must be shown' );
    Assert.AreEqual( 'PNG', FView.ImageFormat );
    Assert.AreEqual( 2, FView.ImageWidth );
    Assert.AreEqual( '', FView.LastError );
    Assert.AreEqual( 0, FErrors );
  finally
    lBmp.Free;
    TFile.Delete( lFile );
  end;

end;

procedure TTestImageView.LoadFromFile_ReadOnly_IsRefused;
begin

  FView.ReadOnly := True;
  FView.LoadFromFile( 'C:\does-not-matter.png' );

  Assert.IsFalse( FView.HasImage, 'A read-only viewer must not load' );
  // The read-only message itself: a missing-file error would also set LastError.
  Assert.AreEqual( SPictureReadOnly, FView.LastError, 'The refusal must be reported in LastError' );
  Assert.AreEqual( 1, FErrors, 'The refusal must raise OnImageError once' );

end;

procedure TTestImageView.FlipHorizontal_Writable_MirrorsPixels;
begin

  var lBmp := NewRedBlueBitmap;

  try
    FView.Picture.Assign( lBmp );
  finally
    lBmp.Free;
  end;

  FView.FlipHorizontal;

  Assert.AreEqual( Integer( clBlue ), Integer( PixelOf( FView.Picture.Graphic, 0 ) ), 'Left pixel after the flip' );
  Assert.AreEqual( Integer( clRed ), Integer( PixelOf( FView.Picture.Graphic, 1 ) ), 'Right pixel after the flip' );

end;

procedure TTestImageView.FlipHorizontal_ReadOnly_DoesNothing;
begin

  var lBmp := NewRedBlueBitmap;

  try
    FView.Picture.Assign( lBmp );
  finally
    lBmp.Free;
  end;

  FView.ReadOnly := True;
  FView.FlipHorizontal;

  Assert.AreEqual( Integer( clRed ), Integer( PixelOf( FView.Picture.Graphic, 0 ) ), 'Left pixel must not move' );

end;

procedure TTestImageView.PlaceholderCaption_IsName;
begin

  Assert.AreEqual( 'PhotoView', FView.PlaceholderCaption );

end;

procedure TTestImageView.Pan_Centred_StopsAtTheOverhang;
begin

  var lBmp := NewBitmap( 200, 100 );

  try
    FView.Picture.Assign( lBmp );
  finally
    lBmp.Free;
  end;

  FView.SetBounds( 0, 0, 100, 100 );   // no window handle: the client area is the bounds
  FView.PanBy( -1000, -1000 );
  Assert.AreEqual( -50, FView.PanOffset.X, 'Panned fully left' );
  Assert.AreEqual( 0, FView.PanOffset.Y, 'The height fits: no vertical pan' );
  Assert.AreEqual( 100, FView.ScrollPosition.X, 'Scrolled to the right edge' );

  FView.PanBy( 1000, 0 );
  Assert.AreEqual( 50, FView.PanOffset.X, 'Panned fully right' );
  Assert.AreEqual( 0, FView.ScrollPosition.X, 'Scrolled to the left edge' );

end;

procedure TTestImageView.Pan_Uncentred_MovesOneWay;
begin

  var lBmp := NewBitmap( 200, 100 );

  try
    FView.Picture.Assign( lBmp );
  finally
    lBmp.Free;
  end;

  FView.Center := False;
  FView.SetBounds( 0, 0, 100, 100 );
  FView.PanBy( 1000, 0 );
  Assert.AreEqual( 0, FView.PanOffset.X, 'The left edge is already at the left: no further right' );

  FView.PanBy( -1000, 0 );
  Assert.AreEqual( -100, FView.PanOffset.X, 'The whole overhang is reachable' );
  Assert.AreEqual( 100, FView.ScrollPosition.X );

end;

procedure TTestImageView.Pan_Rotated90_FollowsTheLongSide;
begin

  var lBmp := NewBitmap( 200, 100 );

  try
    FView.Picture.Assign( lBmp );
  finally
    lBmp.Free;
  end;

  FView.SetBounds( 0, 0, 100, 100 );
  FView.Rotation := ro90;   // drawn 100 wide, 200 tall
  FView.PanBy( -1000, -1000 );
  Assert.AreEqual( 0, FView.PanOffset.X, 'The rotated width fits' );
  Assert.AreEqual( -50, FView.PanOffset.Y, 'The rotated height overhangs by 100' );

end;

procedure TTestImageView.Pan_Fitted_IsZero;
begin

  var lBmp := NewBitmap( 200, 100 );

  try
    FView.Picture.Assign( lBmp );
  finally
    lBmp.Free;
  end;

  FView.SetBounds( 0, 0, 100, 100 );
  FView.FitToWindow := True;
  FView.PanBy( -1000, -1000 );
  Assert.AreEqual( 0, FView.PanOffset.X );
  Assert.AreEqual( 0, FView.PanOffset.Y );

end;

procedure TTestImageView.RotatePicture_TurnsPixelsAndKeepsPng;
begin

  var lBmp := NewRedBlueBitmap;
  var lPng := TPngImage.Create;

  try
    lPng.Assign( lBmp );
    FView.Picture.Assign( lPng );
  finally
    lPng.Free;
    lBmp.Free;
  end;

  FView.RotatePicture( ro90 );

  Assert.AreEqual( 'PNG', FView.ImageFormat, 'Still a PNG' );
  Assert.AreEqual( 1, FView.ImageWidth, 'The 2 x 1 picture is now 1 x 2' );
  Assert.AreEqual( 2, FView.ImageHeight );
  Assert.AreEqual( Integer( clRed ), Integer( PixelAt( FView.Picture.Graphic, 0, 0 ) ), 'Clockwise: left goes to top' );
  Assert.AreEqual( Integer( clBlue ), Integer( PixelAt( FView.Picture.Graphic, 0, 1 ) ) );
  Assert.AreEqual( ro0, FView.Rotation, 'The display rotation is not stacked on top' );

end;

procedure TTestImageView.RotatePicture_ReadOnly_DoesNothing;
begin

  var lBmp := NewRedBlueBitmap;

  try
    FView.Picture.Assign( lBmp );
  finally
    lBmp.Free;
  end;

  FView.ReadOnly := True;
  FView.RotatePicture( ro90 );
  Assert.AreEqual( 2, FView.ImageWidth, 'A read-only picture keeps its shape' );

end;

procedure TTestImageView.FlipHorizontal_KeepsJpeg;
begin

  var lBmp := NewBitmap( 16, 8 );
  var lJpg := TJPEGImage.Create;

  try
    lJpg.Assign( lBmp );
    FView.Picture.Assign( lJpg );
  finally
    lJpg.Free;
    lBmp.Free;
  end;

  FView.FlipHorizontal;
  Assert.AreEqual( 'JPEG', FView.ImageFormat );

end;

procedure TTestImageView.FilesDropped( Sender : TObject; const FileNames : TArray<string>; var Handled : Boolean );
begin

  FDropped := FileNames;
  Handled  := True;

end;

procedure TTestImageView.ZoomBy_FromFitted_ContinuesAtFittedScale;
begin

  var lBmp := NewBitmap( 200, 100 );

  try
    FView.Picture.Assign( lBmp );
  finally
    lBmp.Free;
  end;

  FView.SetBounds( 0, 0, 100, 100 );
  FView.FitToWindow := True;   // shown at 0.5
  FView.ZoomBy( 2.0 );

  Assert.IsFalse( FView.FitToWindow, 'Zooming leaves fit mode' );
  Assert.AreEqual( 1.0, FView.ZoomFactor, 0.0001, 'Twice the fitted 0.5, not twice the old 1.0' );

end;

procedure TTestImageView.RotatePicture_IncludesDisplayRotation;
begin

  var lBmp := NewRedBlueBitmap;

  try
    FView.Picture.Assign( lBmp );
  finally
    lBmp.Free;
  end;

  FView.Rotation := ro90;           // shown turned 90
  FView.RotatePicture( ro90 );      // a further 90: 180 in all

  Assert.AreEqual( 2, FView.ImageWidth, 'Turned 180: still 2 x 1' );
  Assert.AreEqual( Integer( clBlue ), Integer( PixelAt( FView.Picture.Graphic, 0, 0 ) ), 'Turned 180: blue now left' );
  Assert.AreEqual( ro0, FView.Rotation );

end;

procedure TTestImageView.RotatePicture_Ra0_BakesDisplayRotation;
begin

  var lBmp := NewRedBlueBitmap;

  try
    FView.Picture.Assign( lBmp );
  finally
    lBmp.Free;
  end;

  FView.Rotation := ro90;
  FView.RotatePicture( ro0 );

  Assert.AreEqual( 1, FView.ImageWidth, 'The display rotation is now in the pixels: 1 x 2' );
  Assert.AreEqual( ro0, FView.Rotation );

end;

procedure TTestImageView.StretchProportional_MapToFitProperties;
begin

  FView.Proportional := True;
  FView.Stretch      := True;
  Assert.IsTrue( FView.FitToWindow and FView.MaintainAspectRatio, 'Stretch + Proportional: fit both ways, aspect kept' );

  FView.Proportional := False;
  Assert.IsTrue( FView.ShrinkToFit and FView.ZoomToFit and not FView.MaintainAspectRatio, 'Stretch alone: fill' );

  FView.Stretch      := False;
  FView.Proportional := True;
  Assert.IsTrue( FView.ShrinkToFit and not FView.ZoomToFit and FView.MaintainAspectRatio, 'Proportional alone: shrink' );

end;

procedure TTestImageView.DropFiles_ReachesHandler;
var
  lDrop : TDropFiles;
begin

  var lForm := TForm.CreateNew( nil );

  try
    FView.Parent         := lForm;
    FView.OnFilesDropped := FilesDropped;
    FView.HandleNeeded;

    // A real WM_DROPFILES: a DROPFILES header followed by the double-NUL-terminated wide file list.
    var lList  := 'C:\one.png'#0'C:\two.jxl'#0#0;
    var lBytes := SizeOf( lDrop ) + Length( lList ) * SizeOf( Char );
    var lMem   := GlobalAlloc( GHND, lBytes );
    var lPtr   := PByte( GlobalLock( lMem ) );

    lDrop        := Default( TDropFiles );
    lDrop.pFiles := SizeOf( lDrop );
    lDrop.fWide  := True;
    Move( lDrop, lPtr^, SizeOf( lDrop ) );
    Move( PChar( lList )^, ( lPtr + SizeOf( lDrop ) )^, Length( lList ) * SizeOf( Char ) );
    GlobalUnlock( lMem );

    SendMessage( FView.Handle, WM_DROPFILES, WPARAM( lMem ), 0 );   // the control's DragFinish frees lMem

    Assert.AreEqual( 2, Length( FDropped ), 'Every dropped file reaches the handler' );
    Assert.AreEqual( 'C:\two.jxl', FDropped[ 1 ] );
    Assert.AreEqual( 0, FErrors, 'Handled: the control did not try to load C:\one.png itself' );
  finally
    FView.Parent := nil;
    lForm.Free;
  end;

end;

procedure TTestImageView.SaveToFile_Jxl_WritesJpegXl;
begin

  Assert.IsTrue( JxlLibraryAvailable, 'The libjxl DLLs must be beside the test runner (CopyJxlDlls.ps1)' );

  var lFile := TPath.Combine( TPath.GetTempPath, 'gllImageTest-' + TGUID.NewGuid.ToString + '.jxl' );
  var lBmp  := NewRedBlueBitmap;
  var lPng  := TPngImage.Create;

  try
    lPng.Assign( lBmp );
    FView.Picture.Assign( lPng );
    FView.SaveToFile( lFile );

    var lStream := TFileStream.Create( lFile, fmOpenRead or fmShareDenyWrite );

    try
      Assert.IsTrue( TJxlImage.CanLoadFromStream( lStream ), 'The file must be JPEG XL, not a PNG under a .jxl name' );
    finally
      lStream.Free;
    end;

  finally
    lPng.Free;
    lBmp.Free;

    if TFile.Exists( lFile ) then
      TFile.Delete( lFile );
  end;

end;

procedure TTestImageView.TDBImageStyleDfm_Streams;
const
  // An old form: the GITLAKDB class name and TDBImage's two scaling properties.
  DFM = 'object Photo: TGDBImage'#13#10'  Proportional = True'#13#10'  Stretch = True'#13#10'end';
begin

  var lText   := TStringStream.Create( DFM );
  var lBinary := TMemoryStream.Create;

  try
    ObjectTextToBinary( lText, lBinary );
    lBinary.Position := 0;

    var lImage := lBinary.ReadComponent( nil ) as TgllDBImage;

    try
      Assert.IsTrue( lImage.FitToWindow, 'Stretch + Proportional load as FitToWindow' );
      Assert.IsTrue( lImage.MaintainAspectRatio );
    finally
      lImage.Free;
    end;

  finally
    lBinary.Free;
    lText.Free;
  end;

end;

procedure TTestDBImage.OldClassName_IsAliased;
begin

  Assert.IsTrue( GetClass( 'TGDBImage' ) = TgllDBImage, 'TGDBImage must resolve to TgllDBImage' );

end;

{ TTestFormats }

procedure TTestFormats.Detect_JxlSignatures_AreJxl;
const
  CODESTREAM : array[ 0..11 ] of Byte = ( $FF, $0A, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 );
  CONTAINER  : array[ 0..15 ] of Byte = ( 0, 0, 0, $0C, $4A, $58, $4C, $20, $0D, $0A, $87, $0A, 0, 0, 0, 0 );
begin

  var lStream := TMemoryStream.Create;

  try
    lStream.WriteBuffer( CODESTREAM, SizeOf( CODESTREAM ) );
    Assert.IsTrue( DetectImageFormat( lStream ) = TJxlImage, 'Bare codestream' );

    lStream.Clear;
    lStream.WriteBuffer( CONTAINER, SizeOf( CONTAINER ) );
    Assert.IsTrue( DetectImageFormat( lStream ) = TJxlImage, 'Container' );
  finally
    lStream.Free;
  end;

end;

procedure TTestFormats.Detect_TiffSignature_IsWic;
const
  TIFF : array[ 0..11 ] of Byte = ( $49, $49, $2A, 0, 8, 0, 0, 0, 0, 0, 0, 0 );
begin

  var lStream := TMemoryStream.Create;

  try
    lStream.WriteBuffer( TIFF, SizeOf( TIFF ) );
    Assert.IsTrue( DetectImageFormat( lStream ) = TWICImage );
  finally
    lStream.Free;
  end;

end;

procedure TTestFormats.StripLegacyHeader_RemovesHeader;
begin

  var lBmp     := NewRedBlueBitmap;
  var lPlain   := TMemoryStream.Create;
  var lWrapped := TMemoryStream.Create;

  try
    lBmp.SaveToStream( lPlain );
    WriteWithLegacyHeader( lBmp, lWrapped );

    Assert.IsTrue( StripLegacyGraphicHeader( lWrapped ), 'The header must be recognised' );
    Assert.AreEqual<Byte>( StreamBytes( lPlain ), StreamBytes( lWrapped ), 'What is left must be the bitmap' );
  finally
    lWrapped.Free;
    lPlain.Free;
    lBmp.Free;
  end;

end;

procedure TTestFormats.StripLegacyHeader_LeavesOtherDataAlone;
begin

  var lBmp   := NewRedBlueBitmap;
  var lPlain := TMemoryStream.Create;

  try
    lBmp.SaveToStream( lPlain );

    var lBefore := StreamBytes( lPlain );

    Assert.IsFalse( StripLegacyGraphicHeader( lPlain ) );
    Assert.AreEqual<Byte>( lBefore, StreamBytes( lPlain ), 'The stream must be unchanged' );
  finally
    lPlain.Free;
    lBmp.Free;
  end;

end;

{ TTestDBImage }

procedure TTestDBImage.Setup;
begin

  FData := TClientDataSet.Create( nil );
  FData.FieldDefs.Add( 'ID', ftInteger );
  FData.FieldDefs.Add( 'Pic', ftBlob );
  FData.CreateDataSet;
  FData.FieldByName( 'Pic' ).DisplayLabel := 'Photograph';

  var lBmp := NewRedBlueBitmap;
  var lMs  := TMemoryStream.Create;

  try
    lBmp.SaveToStream( lMs );
    lMs.Position := 0;
    FData.Append;
    FData.FieldByName( 'ID' ).AsInteger := 1;
    TBlobField( FData.FieldByName( 'Pic' ) ).LoadFromStream( lMs );
    FData.Post;
  finally
    lMs.Free;
    lBmp.Free;
  end;

  FSource         := TDataSource.Create( nil );
  FSource.DataSet := FData;

  FImage            := TDBImageProbe.Create( nil );
  FImage.DataSource := FSource;
  FImage.DataField  := 'Pic';

end;

procedure TTestDBImage.TearDown;
begin

  FreeAndNil( FImage );
  FreeAndNil( FSource );
  FreeAndNil( FData );

end;

procedure TTestDBImage.Open_LoadsPictureFromField;
begin

  Assert.IsTrue( FImage.HasImage, 'The field''s picture must be loaded' );
  Assert.AreEqual( 'Bitmap', FImage.ImageFormat );
  Assert.AreEqual( Integer( clRed ), Integer( PixelOf( FImage.Picture.Graphic, 0 ) ) );

end;

procedure TTestDBImage.FlipHorizontal_PostsMirroredPicture;
begin

  FImage.FlipHorizontal;

  Assert.AreEqual( dsEdit, FData.State, 'The flip must put the dataset into edit' );

  FData.Post;

  var lStored := TBitmap.Create;
  var lMs     := TMemoryStream.Create;

  try
    TBlobField( FData.FieldByName( 'Pic' ) ).SaveToStream( lMs );
    lMs.Position := 0;
    lStored.LoadFromStream( lMs );
    Assert.AreEqual( Integer( clBlue ), Integer( PixelOf( lStored, 0 ) ), 'The stored picture must be mirrored' );
    Assert.AreEqual( Integer( clRed ), Integer( PixelOf( lStored, 1 ) ), 'The stored picture must be mirrored' );
  finally
    lMs.Free;
    lStored.Free;
  end;

end;

procedure TTestDBImage.FlipHorizontal_ReadOnly_LeavesRecordAlone;
begin

  FImage.ReadOnly := True;
  FImage.FlipHorizontal;

  Assert.AreEqual( dsBrowse, FData.State, 'A read-only control must not edit the dataset' );
  Assert.AreEqual( Integer( clRed ), Integer( PixelOf( FImage.Picture.Graphic, 0 ) ), 'Left pixel must not move' );

end;

procedure TTestDBImage.PlaceholderCaption_IsFieldDisplayLabel;
begin

  Assert.AreEqual( 'Photograph', FImage.PlaceholderCaption );

end;

procedure TTestDBImage.Open_LegacyHeader_LoadsPicture;
begin

  var lBmp := NewRedBlueBitmap;
  var lMs  := TMemoryStream.Create;

  try
    WriteWithLegacyHeader( lBmp, lMs );
    lMs.Position := 0;
    FData.Edit;
    TBlobField( FData.FieldByName( 'Pic' ) ).LoadFromStream( lMs );
    FData.Post;
  finally
    lMs.Free;
    lBmp.Free;
  end;

  Assert.AreEqual( '', FImage.LastError, 'The header must not make the picture unreadable' );
  Assert.IsTrue( FImage.HasImage );
  Assert.AreEqual( Integer( clRed ), Integer( PixelOf( FImage.Picture.Graphic, 0 ) ) );

end;

procedure TTestDBImage.LoadFromFile_StoresFileBytesVerbatim;
begin

  var lFile := TPath.Combine( TPath.GetTempPath, 'gllImageTest-' + TGUID.NewGuid.ToString + '.png' );
  var lBmp  := NewBitmap( 64, 64 );

  try
    lBmp.Canvas.Pen.Color := clRed;
    lBmp.Canvas.Ellipse( 4, 4, 60, 60 );

    // Saved at compression level 1: a re-encode by TPngImage (level 7 by default) produces different bytes.
    var lPng := TPngImage.Create;

    try
      lPng.Assign( lBmp );
      lPng.CompressionLevel := 1;
      lPng.SaveToFile( lFile );
    finally
      lPng.Free;
    end;

    FImage.LoadFromFile( lFile );
    Assert.AreEqual( '', FImage.LastError );
    FData.Post;

    var lStored := TMemoryStream.Create;

    try
      TBlobField( FData.FieldByName( 'Pic' ) ).SaveToStream( lStored );
      Assert.AreEqual<Byte>( TFile.ReadAllBytes( lFile ), StreamBytes( lStored ), 'The stored bytes must be the file''s' );
    finally
      lStored.Free;
    end;

    Assert.AreEqual( 'PNG', FImage.ImageFormat );
  finally
    lBmp.Free;
    TFile.Delete( lFile );
  end;

end;

procedure TTestDBImage.Jxl_ShowsAndRotatesAsJxl;
begin

  Assert.IsTrue( JxlLibraryAvailable, 'The libjxl DLLs must be beside the test runner (CopyJxlDlls.ps1)' );

  var lBmp := NewRedBlueBitmap;
  var lMs  := TMemoryStream.Create;

  try
    var lJxl := TJxlImage.Create;

    try
      lJxl.Assign( lBmp );
      lJxl.Lossless := True;
      lJxl.SaveToStream( lMs );
    finally
      lJxl.Free;
    end;

    lMs.Position := 0;
    FData.Edit;
    TBlobField( FData.FieldByName( 'Pic' ) ).LoadFromStream( lMs );
    FData.Post;
  finally
    lMs.Free;
    lBmp.Free;
  end;

  Assert.AreEqual( 'JPEG XL', FImage.ImageFormat );
  Assert.AreEqual( Integer( clRed ), Integer( PixelOf( FImage.Picture.Graphic, 0 ) ), 'Lossless JPEG XL keeps the pixels' );

  FImage.RotatePicture( ro180 );
  Assert.AreEqual( dsEdit, FData.State, 'The rotation must put the dataset into edit' );
  FData.Post;

  var lStored := TMemoryStream.Create;

  try
    TBlobField( FData.FieldByName( 'Pic' ) ).SaveToStream( lStored );
    lStored.Position := 0;
    Assert.IsTrue( TJxlImage.CanLoadFromStream( lStored ), 'The rotated picture must be stored as JPEG XL' );

    var lBack := TJxlImage.Create;

    try
      lBack.LoadFromStream( lStored );

      // A decoded image does not know how its file was encoded, so the rotation is re-encoded at libjxl's default
      // (visually lossless) distance: the colours are near, not exact.
      var lLeft  := ColorToRGB( PixelOf( lBack, 0 ) );
      var lRight := ColorToRGB( PixelOf( lBack, 1 ) );

      Assert.IsTrue( ( GetBValue( lLeft ) > 180 ) and ( GetRValue( lLeft ) < 80 ), 'Rotated 180: the blue pixel is now left' );
      Assert.IsTrue( ( GetRValue( lRight ) > 180 ) and ( GetBValue( lRight ) < 80 ), 'and the red one right' );
    finally
      lBack.Free;
    end;

  finally
    lStored.Free;
  end;

end;

initialization

  TDUnitX.RegisterTestFixture( TTestFormatRegistry );
  TDUnitX.RegisterTestFixture( TTestImageView );
  TDUnitX.RegisterTestFixture( TTestDBImage );
  TDUnitX.RegisterTestFixture( TTestFormats );

end.
