(* Copyright (c) 2026 Ian Branch. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style
 * license that can be found in the LICENSE file.
 *)

/// <summary>
///   Tests for RenderMode and the Skia renderer ( gllImage.Skia ): the default stays the VCL's StretchDraw, rmSkia
///   resamples a shrunk picture properly where StretchDraw drops pixels, a picture Skia should not draw is left to
///   StretchDraw, a missing renderer falls back cleanly, and a changed picture is never drawn from a stale cache.
/// </summary>
unit TestGllImageSkia;

interface

uses
  DUnitX.TestFramework;

type
  /// <summary>Pins RenderMode and TgllSkiaImageRenderer; expected values are typed out by hand.</summary>
  [TestFixture]
  TTestGllImageSkia = class
  public
    /// <summary>A new viewer draws the normal way: rmSkia must be opted into, per control, never on by default.</summary>
    [Test]
    procedure RenderMode_DefaultsToNormal;

    /// <summary>Skia takes opaque raster pictures and alpha PNGs, and leaves metafiles ( already sharp at any size ),
    /// icons, colour-keyed transparency, empty pictures and nil to StretchDraw.</summary>
    [Test]
    procedure CanRender_TakesRasterOnly;

    /// <summary>Drawing 1:1 is declined, because StretchDraw is an exact copy there and Skia would only cost time.</summary>
    [Test]
    procedure Draw_OneToOne_IsDeclined;

    /// <summary>The defect itself, measured: 1-px black and white stripes shrunk 4:1 must come out mid-grey with Skia
    /// ( each output pixel averages two black and two white columns ), not solid black or white.</summary>
    [Test]
    procedure Skia_ShrinkAveragesFineDetail;

    /// <summary>The real case: a large, non-integer shrink ( 13:1, a 12 MP photo fitted to a window is about 10:1 ).
    /// Sampling that reads only a few source pixels per output pixel ( nearest, or cubic without mipmaps ) aliases
    /// there, so this pins the mipmapped choice for shrinking, which the 4:1 test cannot tell from cubic.</summary>
    [Test]
    procedure Skia_LargeShrinkAveragesFineDetail;

    /// <summary>The control for the test above: the normal path really does drop columns on this picture, so the Skia
    /// test cannot pass by accident of the set-up.</summary>
    [Test]
    procedure Normal_ShrinkDropsColumns;

    /// <summary>rmSkia with no renderer registered ( gllImage.Skia not linked ) draws exactly as rmNormal, byte for
    /// byte, rather than drawing nothing.</summary>
    [Test]
    procedure Skia_WithoutRenderer_DrawsAsNormal;

    /// <summary>After the picture changes, the next paint shows the new picture, not the cached old one.</summary>
    [Test]
    procedure Skia_PictureChange_IsNotStale;
  end;

implementation

uses
  Winapi.Windows,
  System.Classes, System.SysUtils, System.Types, System.Math,
  Vcl.Graphics, Vcl.Forms, Vcl.Controls, Vcl.Imaging.pngimage,
  gllImage.View, gllImage.Skia;

const
  /// <summary>The viewer's size in the rendering tests: a quarter of the stripe picture in both directions.</summary>
  VIEW_WIDTH  = 100;
  /// <summary>See VIEW_WIDTH.</summary>
  VIEW_HEIGHT = 25;

/// <summary>A picture of alternating 1-px black and white vertical stripes, 400x100 unless sized otherwise.</summary>
/// <param name="AWidth">The width in pixels.</param>
/// <param name="AHeight">The height in pixels.</param>
/// <returns>The picture; the caller frees it.</returns>
function MakeStripes( AWidth : Integer = 400; AHeight : Integer = 100 ) : TBitmap;
begin

  Result := TBitmap.Create;
  Result.PixelFormat := pf24bit;
  Result.SetSize( AWidth, AHeight );

  for var lX := 0 to Result.Width - 1 do
  begin
    Result.Canvas.Pen.Color := if Odd( lX ) then clWhite else clBlack;
    Result.Canvas.MoveTo( lX, 0 );
    Result.Canvas.LineTo( lX, Result.Height );
  end;

end;

/// <summary>A 400x100 picture filled with one colour.</summary>
/// <param name="AColour">The fill colour.</param>
/// <returns>The picture; the caller frees it.</returns>
function MakeSolid( AColour : TColor ) : TBitmap;
begin

  Result := TBitmap.Create;
  Result.PixelFormat := pf24bit;
  Result.SetSize( 400, 100 );
  Result.Canvas.Brush.Color := AColour;
  Result.Canvas.FillRect( Rect( 0, 0, Result.Width, Result.Height ) );

end;

/// <summary>Paints a borderless, shrink-to-fit viewer showing the given pictures, in turn, into a 32-bit bitmap.</summary>
/// <param name="AMode">The viewer's RenderMode.</param>
/// <param name="APictures">The pictures to assign; the viewer is painted after each, so a later one tests the cache.</param>
/// <returns>The last paint; the caller frees it.</returns>
function RenderView( AMode : TgllImageRenderMode; const APictures : array of TGraphic ) : TBitmap;
begin

  Result := nil;
  var lForm := TForm.CreateNew( nil );

  try
    var lView := TgllImageView.Create( lForm );

    lView.Parent      := lForm;
    lView.BorderStyle := bsNone;
    lView.SetBounds( 0, 0, VIEW_WIDTH, VIEW_HEIGHT );
    lView.ShrinkToFit := True;
    lView.RenderMode  := AMode;
    lView.HandleNeeded;

    for var lPicture in APictures do
    begin
      lView.Picture.Assign( lPicture );
      FreeAndNil( Result );
      Result := TBitmap.Create;
      Result.PixelFormat := pf32bit;
      Result.SetSize( VIEW_WIDTH, VIEW_HEIGHT );
      lView.PaintTo( Result.Canvas.Handle, 0, 0 );
    end;
  finally
    lForm.Free;
  end;

end;

/// <summary>The grey level ( 0..255, the mean of B, G and R ) of one pixel of a 32-bit bitmap.</summary>
/// <param name="ABitmap">A pf32bit bitmap.</param>
/// <param name="AX">The column.</param>
/// <param name="AY">The row.</param>
/// <returns>The grey level.</returns>
function GreyAt( ABitmap : TBitmap; AX, AY : Integer ) : Integer;
begin

  var lPixel := PByte( ABitmap.ScanLine[ AY ] ) + AX * 4;
  Result := ( lPixel[ 0 ] + lPixel[ 1 ] + lPixel[ 2 ] ) div 3;

end;

/// <summary>The lowest and highest grey levels inside the bitmap, a 2-px margin excluded ( edge pixels blend with
/// the background ).</summary>
/// <param name="ABitmap">A pf32bit bitmap.</param>
/// <param name="AMin">Receives the lowest level.</param>
/// <param name="AMax">Receives the highest level.</param>
procedure GreyRange( ABitmap : TBitmap; out AMin, AMax : Integer );
begin

  AMin := 255;
  AMax := 0;

  for var lY := 2 to ABitmap.Height - 3 do
    for var lX := 2 to ABitmap.Width - 3 do
    begin
      var lGrey := GreyAt( ABitmap, lX, lY );
      AMin := Min( AMin, lGrey );
      AMax := Max( AMax, lGrey );
    end;

end;

{ TTestGllImageSkia }

procedure TTestGllImageSkia.RenderMode_DefaultsToNormal;
begin

  var lView := TgllImageView.Create( nil );

  try
    Assert.AreEqual( Ord( rmNormal ), Ord( lView.RenderMode ), 'a new viewer must draw the normal way' );
  finally
    lView.Free;
  end;

end;

procedure TTestGllImageSkia.CanRender_TakesRasterOnly;
begin

  var lBitmap   := TBitmap.Create;
  var lKeyed    := TBitmap.Create;
  var lPng      := TPngImage.CreateBlank( COLOR_RGBALPHA, 8, 10, 10 );
  var lMetafile := TMetafile.Create;
  var lIcon     := TIcon.Create;
  var lEmpty    := TBitmap.Create;

  try
    lBitmap.SetSize( 10, 10 );
    lKeyed.SetSize( 10, 10 );
    lKeyed.Transparent := True;
    lMetafile.SetSize( 10, 10 );

    var lCanvas := TMetafileCanvas.Create( lMetafile, 0 );

    try
      lCanvas.Rectangle( 0, 0, 5, 5 );
    finally
      lCanvas.Free;
    end;

    lIcon.Handle := LoadIcon( 0, IDI_APPLICATION );

    Assert.IsTrue( TgllSkiaImageRenderer.CanRender( lBitmap ), 'an opaque bitmap' );
    Assert.IsTrue( TgllSkiaImageRenderer.CanRender( lPng ), 'a PNG with an alpha channel' );
    Assert.IsFalse( TgllSkiaImageRenderer.CanRender( lKeyed ), 'a colour-keyed transparent bitmap' );
    Assert.IsFalse( TgllSkiaImageRenderer.CanRender( lMetafile ), 'a metafile, which is vector' );
    Assert.IsFalse( TgllSkiaImageRenderer.CanRender( lIcon ), 'an icon' );
    Assert.IsFalse( TgllSkiaImageRenderer.CanRender( lEmpty ), 'an empty picture' );
    Assert.IsFalse( TgllSkiaImageRenderer.CanRender( nil ), 'nil' );
  finally
    lEmpty.Free;
    lIcon.Free;
    lMetafile.Free;
    lPng.Free;
    lKeyed.Free;
    lBitmap.Free;
  end;

end;

procedure TTestGllImageSkia.Draw_OneToOne_IsDeclined;
var
  lCache : TObject;
begin

  lCache := nil;
  var lSource := MakeStripes;
  var lTarget := TBitmap.Create;

  try
    lTarget.SetSize( lSource.Width, lSource.Height );
    Assert.IsFalse( TgllCustomImageView.SkiaRenderer.Draw( lTarget.Canvas, Rect( 0, 0, lSource.Width, lSource.Height ),
      lSource, 1, lCache ), 'a 1:1 draw must be left to StretchDraw' );
  finally
    lCache.Free;
    lTarget.Free;
    lSource.Free;
  end;

end;

procedure TTestGllImageSkia.Skia_ShrinkAveragesFineDetail;
var
  lMin : Integer;
  lMax : Integer;
begin

  var lStripes := MakeStripes;

  try
    var lOut := RenderView( rmSkia, [ lStripes ] );

    try
      GreyRange( lOut, lMin, lMax );
      Assert.IsTrue( ( lMin >= 100 ) and ( lMax <= 155 ), Format( 'Skia should average the stripes to mid-grey, got ' +
        '%d..%d', [ lMin, lMax ] ) );
    finally
      lOut.Free;
    end;
  finally
    lStripes.Free;
  end;

end;

procedure TTestGllImageSkia.Skia_LargeShrinkAveragesFineDetail;
var
  lMin : Integer;
  lMax : Integer;
begin

  var lStripes := MakeStripes( VIEW_WIDTH * 13, VIEW_HEIGHT * 13 );

  try
    var lOut := RenderView( rmSkia, [ lStripes ] );

    try
      GreyRange( lOut, lMin, lMax );
      Assert.IsTrue( ( lMin >= 100 ) and ( lMax <= 155 ), Format( 'a 13:1 shrink should average the stripes to ' +
        'mid-grey, got %d..%d', [ lMin, lMax ] ) );
    finally
      lOut.Free;
    end;
  finally
    lStripes.Free;
  end;

end;

procedure TTestGllImageSkia.Normal_ShrinkDropsColumns;
var
  lMin : Integer;
  lMax : Integer;
begin

  var lStripes := MakeStripes;

  try
    var lOut := RenderView( rmNormal, [ lStripes ] );

    try
      GreyRange( lOut, lMin, lMax );
      Assert.IsTrue( ( lMax < 60 ) or ( lMin > 195 ), Format( 'StretchDraw was expected to keep whole columns ( solid ' +
        'black or white ), got %d..%d: the Skia test above would not discriminate', [ lMin, lMax ] ) );
    finally
      lOut.Free;
    end;
  finally
    lStripes.Free;
  end;

end;

procedure TTestGllImageSkia.Skia_WithoutRenderer_DrawsAsNormal;
begin

  var lStripes  := MakeStripes;
  var lRenderer := TgllCustomImageView.SkiaRenderer;
  var lNormal   : TBitmap := nil;
  var lFallback : TBitmap := nil;

  try
    lNormal := RenderView( rmNormal, [ lStripes ] );
    TgllCustomImageView.SkiaRenderer := nil;
    lFallback := RenderView( rmSkia, [ lStripes ] );

    for var lY := 0 to VIEW_HEIGHT - 1 do
      Assert.IsTrue( CompareMem( lNormal.ScanLine[ lY ], lFallback.ScanLine[ lY ], VIEW_WIDTH * 4 ),
        Format( 'row %d differs from the normal draw', [ lY ] ) );
  finally
    TgllCustomImageView.SkiaRenderer := lRenderer;
    lFallback.Free;
    lNormal.Free;
    lStripes.Free;
  end;

end;

procedure TTestGllImageSkia.Skia_PictureChange_IsNotStale;
begin

  var lBlack := MakeSolid( clBlack );
  var lWhite := MakeSolid( clWhite );

  try
    var lOut := RenderView( rmSkia, [ lBlack, lWhite ] );

    try
      Assert.AreEqual( 255, GreyAt( lOut, VIEW_WIDTH div 2, VIEW_HEIGHT div 2 ),
        'the second picture ( white ) must be shown, not the cached first ( black )' );
    finally
      lOut.Free;
    end;
  finally
    lWhite.Free;
    lBlack.Free;
  end;

end;

initialization
  TDUnitX.RegisterTestFixture( TTestGllImageSkia );

end.
