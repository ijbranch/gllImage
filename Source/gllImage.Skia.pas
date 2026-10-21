(* Copyright (c) 2026 Ian Branch. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style
 * license that can be found in the LICENSE file.
 *)

/// <summary>
///   The Skia renderer for gllImage's viewers: linking this unit makes RenderMode = rmSkia draw scaled pictures with
///   Skia's high-quality resampling instead of the VCL's StretchDraw.  It registers itself in
///   TgllCustomImageView.SkiaRenderer when the unit initialises, so an application only adds it to a uses clause.
/// </summary>
/// <remarks>
///   The core package ( gllImageR ) never depends on Skia; this unit is packaged separately in gllImageSkiaR.  The
///   picture is decoded the way the VCL shows it ( so EXIF orientation, colour handling and every format gllImage
///   reads are unchanged ), kept as a Skia image, and only the scaling is Skia's: trilinear filtering with mipmaps
///   when shrinking, cubic when enlarging.  Only the part of the picture that is visible is rendered, so a deep zoom
///   costs no more than the window.  Raster rendering only: no GPU context, so it is safe in remote and VirtualUI
///   sessions.
/// </remarks>
unit gllImage.Skia;

interface

uses
  { Delphi }
  Winapi.Windows, // before Vcl.Graphics: its TBitmap record must not shadow Vcl.Graphics.TBitmap
  System.Types,
  Vcl.Graphics,

  { gllImage }
  gllImage.View;

type
  /// <summary>
  ///   Draws a viewer's scaled picture with Skia ( see the unit summary ); registered as
  ///   TgllCustomImageView.SkiaRenderer by this unit's initialization.
  /// </summary>
  TgllSkiaImageRenderer = class( TgllImageRenderer )
  public
    /// <summary>
    ///   Whether Skia should draw this picture: a raster picture ( bitmap, JPEG, PNG, single-frame GIF, JPEG XL, WIC )
    ///   that is opaque ( a 32-bit bitmap with an alpha channel counts, and keeps its alpha ), or a PNG with
    ///   transparency.  Metafiles ( vector,
    ///   already sharp at any size ), icons, animated GIFs and colour-keyed transparency are left to StretchDraw.
    /// </summary>
    /// <param name="AGraphic">The picture, possibly nil.</param>
    /// <returns>True when Draw would handle it.</returns>
    class function CanRender( AGraphic : TGraphic ) : Boolean; static;
    /// <summary>
    ///   Whether drawing a picture of this size into ADest shrinks either side, which selects trilinear filtering with
    ///   mipmaps ( so a 12 MP photo fitted to a window does not alias ) instead of cubic resampling.
    /// </summary>
    /// <param name="ASourceWidth">The picture's width in pixels.</param>
    /// <param name="ASourceHeight">The picture's height in pixels.</param>
    /// <param name="ADest">Where the whole picture goes.</param>
    /// <returns>True for the shrinking ( mipmapped ) sampling, False for the enlarging ( cubic ) one.</returns>
    class function IsShrinking( ASourceWidth, ASourceHeight : Integer; const ADest : TRect ) : Boolean; static;
    /// <summary>Draws AGraphic scaled into ADest with Skia, or declines it ( see TgllImageRenderer.Draw ).</summary>
    /// <param name="ACanvas">The viewer's canvas.</param>
    /// <param name="ADest">Where the whole picture goes, in canvas coordinates; may extend beyond the control.</param>
    /// <param name="AGraphic">The picture to draw.</param>
    /// <param name="AGeneration">The viewer's picture generation, which keys the cache.</param>
    /// <param name="ACache">The viewer's cache slot; this renderer keeps its decoded picture and last output there.</param>
    /// <returns>False when the picture is declined ( CanRender is False, or the draw is 1:1 and so already exact ).</returns>
    function Draw( ACanvas : TCanvas; const ADest : TRect; AGraphic : TGraphic; AGeneration : Cardinal;
      var ACache : TObject ) : Boolean; override;
  end;

implementation

uses
  { Delphi }
  System.Classes, System.SysUtils,
  Vcl.Imaging.pngimage, Vcl.Imaging.GIFImg,

  { Skia }
  System.Skia, Vcl.Skia;

type
  /// <summary>One viewer's Skia cache: the decoded picture, and the last rendered output with what it was for.</summary>
  TSkiaRenderCache = class
  public
    /// <summary>The viewer's picture generation the decoded picture belongs to.</summary>
    Generation : Cardinal;
    /// <summary>The graphic the decoded picture was made from ( identity only, never dereferenced ).</summary>
    Graphic    : TGraphic;
    /// <summary>The picture, decoded once, as Skia draws it.</summary>
    Image      : ISkImage;
    /// <summary>The destination rectangle the last output was rendered for.</summary>
    OutDest    : TRect;
    /// <summary>The visible part of OutDest the last output covers.</summary>
    OutVisible : TRect;
    /// <summary>The last output, premultiplied 32-bit, the size of OutVisible; owned.</summary>
    OutBitmap  : TBitmap;
    /// <summary>Frees the last output.</summary>
    destructor Destroy; override;
  end;

destructor TSkiaRenderCache.Destroy;
begin

  OutBitmap.Free;
  inherited Destroy;

end;

/// <summary>
///   Decodes a picture into a Skia image exactly as the VCL shows it: a bitmap directly ( its alpha kept ), a
///   transparent PNG from its own bytes ( its alpha kept ), anything else drawn opaque into a 32-bit bitmap first.
/// </summary>
/// <param name="AGraphic">A picture CanRender accepted.</param>
/// <returns>The image, or nil when it could not be made.</returns>
function MakeSkImage( AGraphic : TGraphic ) : ISkImage;
begin

  if ( AGraphic is TBitmap ) then
    Exit( TBitmap( AGraphic ).ToSkImage );

  if ( AGraphic is TPngImage ) and AGraphic.Transparent then
  begin
    var lStream := TMemoryStream.Create;

    try
      AGraphic.SaveToStream( lStream );
      lStream.Position := 0;
      Exit( TSkImage.MakeFromEncodedStream( lStream ) );
    finally
      lStream.Free;
    end;
  end;

  var lBitmap := TBitmap.Create;

  try
    lBitmap.PixelFormat := pf32bit;
    lBitmap.AlphaFormat := afIgnored;
    lBitmap.SetSize( AGraphic.Width, AGraphic.Height );
    lBitmap.Canvas.Draw( 0, 0, AGraphic );
    Result := lBitmap.ToSkImage;
  finally
    lBitmap.Free;
  end;

end;

{ TgllSkiaImageRenderer }

class function TgllSkiaImageRenderer.CanRender( AGraphic : TGraphic ) : Boolean;
begin

  if ( AGraphic = nil ) or AGraphic.Empty then
    Exit( False );

  if ( AGraphic is TMetafile ) or ( AGraphic is TIcon ) then
    Exit( False );

  if ( AGraphic is TGIFImage ) and ( TGIFImage( AGraphic ).Images.Count > 1 ) then
    Exit( False );

  if ( not AGraphic.Transparent ) then
    Exit( True );

  // Transparent: only a PNG, whose alpha survives its own decode.  Colour-keyed transparency ( a TBitmap with
  // Transparent set, a GIF with a transparent colour ) is left to StretchDraw, which honours it.  A 32-bit bitmap with
  // an alpha channel reports itself as not Transparent, so it took the opaque path above, and ToSkImage keeps its alpha.
  Result := ( AGraphic is TPngImage );

end;

class function TgllSkiaImageRenderer.IsShrinking( ASourceWidth, ASourceHeight : Integer; const ADest : TRect ) : Boolean;
begin

  Result := ( ADest.Width < ASourceWidth ) or ( ADest.Height < ASourceHeight );

end;

function TgllSkiaImageRenderer.Draw( ACanvas : TCanvas; const ADest : TRect; AGraphic : TGraphic;
  AGeneration : Cardinal; var ACache : TObject ) : Boolean;
var
  lClip    : TRect;
  lVisible : TRect;
begin

  Result := False;

  if ( not CanRender( AGraphic ) ) or ADest.IsEmpty then
    Exit;

  // 1:1 is already exact, and StretchDraw is a plain copy there.
  if ( ADest.Width = AGraphic.Width ) and ( ADest.Height = AGraphic.Height ) then
    Exit;

  if ( GetClipBox( ACanvas.Handle, lClip ) = NULLREGION ) or ( not IntersectRect( lVisible, ADest, lClip ) ) then
    Exit( True );

  if ( not ( ACache is TSkiaRenderCache ) ) then
  begin
    FreeAndNil( ACache );
    ACache := TSkiaRenderCache.Create;
  end;

  var lCache := TSkiaRenderCache( ACache );

  if ( lCache.Image = nil ) or ( lCache.Generation <> AGeneration ) or ( lCache.Graphic <> AGraphic ) then
  begin
    lCache.Image      := MakeSkImage( AGraphic );
    lCache.Generation := AGeneration;
    lCache.Graphic    := AGraphic;
    FreeAndNil( lCache.OutBitmap );
  end;

  if ( lCache.Image = nil ) then
    Exit;

  if ( lCache.OutBitmap = nil ) or ( lCache.OutDest <> ADest ) or ( lCache.OutVisible <> lVisible ) then
  begin
    FreeAndNil( lCache.OutBitmap );

    var lImage    := lCache.Image;
    var lSampling := if IsShrinking( lImage.Width, lImage.Height, ADest ) then
      TSkSamplingOptions.Create( TSkFilterMode.Linear, TSkMipmapMode.Linear ) else TSkSamplingOptions.High;
    var lTarget   := RectF( ADest.Left - lVisible.Left, ADest.Top - lVisible.Top, ADest.Right - lVisible.Left,
      ADest.Bottom - lVisible.Top );
    var lOutput   := TBitmap.Create;

    try
      lOutput.PixelFormat := pf32bit;
      lOutput.AlphaFormat := afPremultiplied;
      lOutput.SetSize( lVisible.Width, lVisible.Height );
      lOutput.SkiaDraw(
        procedure( const ASkCanvas : ISkCanvas )
        begin
          ASkCanvas.DrawImageRect( lImage, RectF( 0, 0, lImage.Width, lImage.Height ), lTarget, lSampling );
        end, True );
    except
      lOutput.Free;
      raise;
    end;

    lCache.OutBitmap  := lOutput;
    lCache.OutDest    := ADest;
    lCache.OutVisible := lVisible;
  end;

  ACanvas.Draw( lVisible.Left, lVisible.Top, lCache.OutBitmap );
  Result := True;

end;

initialization
  TgllCustomImageView.SkiaRenderer := TgllSkiaImageRenderer.Create;

finalization
  begin
    var lRenderer := TgllCustomImageView.SkiaRenderer;

    TgllCustomImageView.SkiaRenderer := nil;
    lRenderer.Free;
  end;

end.
