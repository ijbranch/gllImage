(* Copyright (c) 2026 Ian Branch. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style
 * license that can be found in the LICENSE file.
 *)
(*
  gllImage.Utils - gllImage Core Routines
  Version: 4.0

  Copyright (c) 2000-2025 Sebastián Mayorá, Argentina
  Original Author: Sebastián Mayorá (DelphiHelper@yahoo.com.ar)
  Further developed by Roy Lambert (EDBImage).

  Original licence: Freeware - Use at your own risk.  gllImage: BSD 3-Clause
  (see the LICENSE file).

  Description:
    Core image loading, scaling, and transformation routines for the
    TgllDBImage component. Provides format detection via magic bytes
    and async loading support.

  Version 4.0 Changes (GITLAK 2026-10-19):
    - JPEG XL: detected by its signature and decoded by TJxlImage (LibJxl, the one dependency beyond the RTL/VCL).
    - TIFF through the VCL's TWICImage (Windows Imaging Component); the optional GraphicEx support is removed.
    - Any other format registered with TPicture is tried when the signatures do not match.
    - The 8-byte header the VCL's own TDBImage once wrote before a bitmap is skipped.
    - One detection routine (CreateGraphicFromStream) serves LoadPictureEx and LoadPictureAsync.
    - Graphics that change (flip, rotate) keep their format (ReplaceGraphicKeepingFormat).

  Version 3.0 Changes:
    - Added TIFF format detection (little-endian and big-endian)
    - Added custom exception types for better error handling
    - Added async loading infrastructure
    - Added image transformation routines (rotate, flip)
    - Added thumbnail generation
    - Added plugin architecture for format extensibility
    - Added print support routines

    - Performance optimisation with TDictionary for extension lookup
    - Resource strings for localisation
*)

unit gllImage.Utils;

interface

uses
  Winapi.Windows,
  System.SysUtils, System.Classes, System.Generics.Collections, System.Threading,
  Data.DB,
  Vcl.Imaging.jpeg, Vcl.Imaging.pngimage, Vcl.Imaging.GIFImg, Vcl.Graphics, Vcl.Printers,
  Jxl.Graphic;

resourcestring
  /// <summary>Error message when the supplied field reference is nil.</summary>
  SFieldIsNil = 'Field is nil';
  /// <summary>Error message when the supplied field is not a BLOB field.</summary>
  SFieldNotBlob = 'Field is not a BLOB field';
  /// <summary>Error message when the image stream is too small to be valid.</summary>
  SStreamTooSmall = 'Stream too small or invalid';
  /// <summary>Format string for invalid field type errors. Argument: error message.</summary>
  SInvalidFieldType = 'Invalid field type: %s';
  /// <summary>Format string for field read errors. Argument: error message.</summary>
  SErrorReadingField = 'Error reading field: %s';
  /// <summary>Format string for invalid graphic format errors. Argument: error message.</summary>
  SInvalidGraphicFormat = 'Invalid graphic format: %s';
  /// <summary>Format string for image data read errors. Argument: error message.</summary>
  SErrorReadingImageData = 'Error reading image data: %s';
  /// <summary>Format string for general image load errors. Argument: error message.</summary>
  SErrorLoadingImage = 'Error loading image: %s';
  /// <summary>Format string for custom loader invalid graphic errors. Argument: error message.</summary>
  SCustomLoaderInvalidGraphic = 'Custom loader - invalid graphic: %s';
  /// <summary>Format string for general custom loader errors. Argument: error message.</summary>
  SCustomLoaderError = 'Custom loader error: %s';
  /// <summary>Error message when the image format cannot be detected.</summary>
  SUnknownFormat = 'Unknown or unsupported image format';
  /// <summary>Message reported when an async load operation is cancelled.</summary>
  SAsyncLoadCancelled = 'Async load cancelled';
  /// <summary>Format string for async load failures. Argument: error message.</summary>
  SAsyncLoadFailed = 'Async load failed: %s';
  /// <summary>Default print job name used when no caller-supplied title is provided.</summary>
  SPrintJobName = 'EDBImage Print';
  /// <summary>Format string for invalid rotation angle errors. Argument: angle in degrees.</summary>
  SRotationInvalidAngle = 'Invalid rotation angle: %d (must be 0, 90, 180, or 270)';

type
  /// <summary>
  ///   Base exception class for gllImage errors.
  /// </summary>
  EgllImageException = class( Exception );

  /// <summary>
  ///   Exception raised when an unsupported or invalid image format is encountered.
  /// </summary>
  EgllImageFormatException = class( EgllImageException );

  /// <summary>
  ///   Exception raised when image dimensions exceed allowed limits.
  /// </summary>
  EgllImageSizeException = class( EgllImageException );

  /// <summary>
  ///   Exception raised when a database field error occurs.
  /// </summary>
  EgllImageFieldException = class( EgllImageException );

  /// <summary>
  ///   Exception raised during async loading operations.
  /// </summary>
  EgllImageAsyncException = class( EgllImageException );

  /// <summary>
  ///   Event type for handling custom image formats not natively supported.
  /// </summary>
  /// <param name="B">The graphic object to be created and loaded.</param>
  /// <param name="Stream">The stream containing the image data.</param>
  TLoadCustomImageEvent = procedure( var B : TGraphic; Stream : TStream ) of object;

  /// <summary>
  ///   Callback for async load completion.
  /// </summary>
  /// <param name="Graphic">The loaded graphic, or nil on failure.</param>
  /// <param name="ErrorMsg">Error message if loading failed.</param>
  TAsyncLoadCallback = reference to procedure( Graphic : TGraphic; const ErrorMsg : string );

  /// <summary>
  ///   Image rotation angles.
  /// </summary>
  TRotationAngle = ( ro0, ro90, ro180, ro270 );

  /// <summary>
  ///   Image flip direction.
  /// </summary>
  TFlipDirection = ( fdHorizontal, fdVertical );

  /// <summary>
  ///   Determines how transparent areas of images are displayed.
  /// </summary>
  TTransparentMode = ( tmSolidColour, tmCheckerboard );

  /// <summary>
  ///   Save format handler procedure type.
  /// </summary>
  TSaveFormatHandler = reference to procedure( const FileName : string; Source : TGraphic );

  /// <summary>
  ///   Interface for pluggable image format loaders.
  /// </summary>
  IgllImageLoader = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    /// <summary>Returns the file extensions handled by this loader (e.g. '.webp').</summary>
    /// <returns>Array of supported extensions including the leading dot.</returns>
    function GetExtensions : TArray<string>;
    /// <summary>Tests whether this loader can decode the supplied stream by inspecting its content.</summary>
    /// <param name="Stream">The stream to inspect; the loader must restore the original position.</param>
    /// <returns>True if the stream content is recognised by this loader.</returns>
    function CanLoad( Stream : TStream ) : Boolean;
    /// <summary>Loads a graphic from the supplied stream.</summary>
    /// <param name="Stream">The stream containing the encoded image.</param>
    /// <returns>A newly created TGraphic; the caller takes ownership.</returns>
    function Load( Stream : TStream ) : TGraphic;
    /// <summary>Returns a human-readable name describing the format handled by this loader.</summary>
    /// <returns>The format name (e.g. 'WebP Image').</returns>
    function GetFormatName : string;
  end;

  /// <summary>
  ///   Registry for pluggable image format loaders.
  /// </summary>
  TgllImageFormatRegistry = class
  private
    /// <summary>Registered loaders, in registration order; GetLoaderForStream asks them in this order.</summary>
    class var FLoaders : TList<IgllImageLoader>;
    /// <summary>Lower-case extension (with the leading dot) to the loader that registered it first.</summary>
    class var FExtensionMap : TDictionary<string, IgllImageLoader>;
  public
    /// <summary>Class constructor that initialises the internal loader list and extension lookup map.</summary>
    class constructor Create;
    /// <summary>Class destructor that frees the internal loader list and extension lookup map.</summary>
    class destructor Destroy;

    /// <summary>
    ///   Registers a format loader.
    /// </summary>
    /// <param name="Loader">The loader; nil or an already registered loader is ignored. An extension another loader
    /// already claims stays with that loader.</param>
    class procedure RegisterLoader( Loader : IgllImageLoader );

    /// <summary>
    ///   Unregisters a format loader.
    /// </summary>
    /// <param name="Loader">The loader; each extension it owned passes to the next registered loader that claims it.</param>
    class procedure UnregisterLoader( Loader : IgllImageLoader );

    /// <summary>
    ///   Gets a loader for the specified extension.
    /// </summary>
    /// <param name="Extension">The file extension, with or without the leading dot; case is ignored.</param>
    /// <returns>The loader that owns the extension, or nil.</returns>
    class function GetLoaderForExtension( const Extension : string ) : IgllImageLoader;

    /// <summary>
    ///   Gets a loader that can handle the stream content.
    /// </summary>
    /// <param name="Stream">The image data; each loader asked restores its position.</param>
    /// <returns>The first registered loader whose CanLoad accepts the stream, or nil.</returns>
    class function GetLoaderForStream( Stream : TStream ) : IgllImageLoader;

    /// <summary>
    ///   Gets all registered extensions.
    /// </summary>
    /// <returns>Every extension a registered loader owns, lower case with the leading dot.</returns>
    class function GetRegisteredExtensions : TArray<string>;
  end;

/// <summary>
///   Loads a picture from a database BLOB field with automatic format detection.
/// </summary>
/// <param name="Memoria">Memory stream used for temporary storage.</param>
/// <param name="Picture">The TPicture to load the image into.</param>
/// <param name="Field">The database field containing the image data.</param>
/// <param name="Evento">Optional event for handling custom image formats.</param>
/// <param name="Loaded">Indicates whether the picture has already been loaded.</param>
procedure LoadPictureEx( Memoria : TMemoryStream; Picture : TPicture; Field : TField;
  Evento : TLoadCustomImageEvent; Loaded : Boolean ); overload;

/// <summary>
///   Loads a picture from a database BLOB field with automatic format detection and error reporting.
/// </summary>
/// <param name="Memoria">Memory stream used for temporary storage.</param>
/// <param name="Picture">The TPicture to load the image into.</param>
/// <param name="Field">The database field containing the image data.</param>
/// <param name="Evento">Optional event for handling custom image formats.</param>
/// <param name="Loaded">Indicates whether the picture has already been loaded.</param>
/// <param name="ErrorMsg">Output parameter containing any error message.</param>
/// <returns>True if the image was loaded successfully, False otherwise.</returns>
function LoadPictureEx( Memoria : TMemoryStream; Picture : TPicture; Field : TField;
  Evento : TLoadCustomImageEvent; Loaded : Boolean; out ErrorMsg : string ) : Boolean; overload;

/// <summary>
///   Asynchronously loads a picture from a database BLOB field.
/// </summary>
/// <param name="Field">The database field containing the image data.</param>
/// <param name="Callback">Callback invoked when loading completes.</param>
/// <returns>IFuture that can be used to cancel the operation.</returns>
function LoadPictureAsync( Field : TField; Callback : TAsyncLoadCallback ) : IFuture<TGraphic>;

/// <summary>
///   Calculates a scaled rectangle maintaining aspect ratio.
/// </summary>
/// <param name="ARect">The target rectangle to scale into.</param>
/// <param name="DrawPict">The picture to be scaled.</param>
/// <returns>A rectangle that fits the picture within ARect while maintaining aspect ratio.</returns>
function Rescale( ARect : TRect; DrawPict : TPicture ) : TRect;

/// <summary>
///   Validates that a stream contains valid image data.
/// </summary>
/// <param name="Stream">The stream to validate.</param>
/// <returns>True if the stream appears to contain valid image data.</returns>
function ValidateImageStream( Stream : TStream ) : Boolean;

/// <summary>
///   Detects the image format from stream magic bytes.
/// </summary>
/// <param name="Stream">The stream containing image data.</param>
/// <returns>The detected graphic class, or nil if unknown.</returns>
function DetectImageFormat( Stream : TStream ) : TGraphicClass;

/// <summary>
///   Removes the 8-byte header the VCL's TDBImage once wrote before a bitmap in a BLOB (Count = 1, HType = $0100,
///   Size = the bytes that follow), so the picture after it can be detected.
/// </summary>
/// <remarks>TBlobField skips this header when it loads a TPicture through IStreamPersist; reading the raw bytes
/// does not, so a picture stored by an old TDBImage would otherwise be reported as an unknown format.</remarks>
/// <param name="Stream">The BLOB's bytes; rewritten in place without the header, and left at position 0.</param>
/// <returns>True when a header was found and removed.</returns>
function StripLegacyGraphicHeader( Stream : TMemoryStream ) : Boolean;

/// <summary>
///   Creates the graphic held in a stream: by signature first (BMP, JPEG, PNG, GIF, ICO, WMF, EMF, TIFF, JPEG XL),
///   then through the formats registered with TPicture.
/// </summary>
/// <remarks>Safe on a worker thread for the built-in formats. A failure is reported through ErrorMsg, not
/// raised.</remarks>
/// <param name="Stream">The image data, read from position 0.</param>
/// <param name="ErrorMsg">Empty on success; otherwise why no graphic was created.</param>
/// <returns>A new graphic the caller owns, or nil.</returns>
function CreateGraphicFromStream( Stream : TStream; out ErrorMsg : string ) : TGraphic;

/// <summary>
///   Replaces a picture's graphic with new pixels while keeping its format, so a flipped or rotated JPEG, PNG, GIF
///   or JPEG XL is still stored as one.
/// </summary>
/// <remarks>The new graphic is an instance of the old graphic's class, assigned from ABitmap. A class that cannot
/// take a bitmap (an icon or a metafile) is replaced by the bitmap itself, as the VCL would.</remarks>
/// <param name="Picture">The picture whose graphic is replaced.</param>
/// <param name="ABitmap">The new pixels; copied, not owned.</param>
procedure ReplaceGraphicKeepingFormat( Picture : TPicture; ABitmap : TBitmap );

/// <summary>
///   Rotates a bitmap by the specified angle.
/// </summary>
/// <param name="Source">The source bitmap to rotate.</param>
/// <param name="Angle">The rotation angle (90, 180, or 270 degrees).</param>
/// <returns>A new rotated bitmap. Caller is responsible for freeing.</returns>
function RotateBitmap( Source : TBitmap; Angle : TRotationAngle ) : TBitmap;

/// <summary>
///   Flips a bitmap in the specified direction.
/// </summary>
/// <param name="Source">The source bitmap to flip.</param>
/// <param name="Direction">The flip direction (horizontal or vertical).</param>
/// <returns>A new flipped bitmap. Caller is responsible for freeing.</returns>
function FlipBitmap( Source : TBitmap; Direction : TFlipDirection ) : TBitmap;

/// <summary>
///   Creates a thumbnail of the specified graphic.
/// </summary>
/// <param name="Source">The source graphic.</param>
/// <param name="MaxWidth">Maximum thumbnail width.</param>
/// <param name="MaxHeight">Maximum thumbnail height.</param>
/// <param name="MaintainAspect">Whether to maintain aspect ratio.</param>
/// <returns>A new thumbnail bitmap. Caller is responsible for freeing.</returns>
function CreateThumbnail( Source : TGraphic; MaxWidth, MaxHeight : Integer;
  MaintainAspect : Boolean = True ) : TBitmap;

/// <summary>
///   Prints a graphic to the default printer.
/// </summary>
/// <param name="Source">The graphic to print.</param>
/// <param name="Title">The print job title.</param>
/// <param name="FitToPage">Whether to scale to fit the page.</param>
/// <param name="CenterOnPage">Whether to centre the image on the page.</param>
procedure PrintGraphic( Source : TGraphic; const Title : string = '';
  FitToPage : Boolean = True; CenterOnPage : Boolean = True );

/// <summary>
///   Checks if an extension is supported for loading.
/// </summary>
/// <param name="Extension">The file extension (with or without dot).</param>
/// <returns>True if the extension is supported.</returns>
function IsSupportedExtension( const Extension : string ) : Boolean;

/// <summary>
///   Gets all supported file extensions.
/// </summary>
/// <returns>Array of supported extensions.</returns>
function GetSupportedExtensions : TArray<string>;

/// <summary>
///   The file extension for a graphic class: what a file of its format is called.
/// </summary>
/// <remarks>TWICImage is taken to be TIFF (the format DetectImageFormat gives it); use GraphicFileExtension when
/// the graphic itself is to hand.</remarks>
/// <param name="AClass">The graphic class.</param>
/// <returns>The extension with its dot, e.g. '.jxl'; '.bmp' for an unknown TBitmap descendant, and the extension
/// registered with TPicture (or '.img') for any other class.</returns>
function GraphicClassExtension( AClass : TGraphicClass ) : string;

/// <summary>
///   The file extension for a graphic: what a file written by its SaveToFile is called.
/// </summary>
/// <param name="AGraphic">The graphic.</param>
/// <returns>The extension with its dot; it follows a TWICImage's ImageFormat and a TMetafile's Enhanced.</returns>
function GraphicFileExtension( AGraphic : TGraphic ) : string;

/// <summary>
///   Converts a graphic to a bitmap for manipulation.
/// </summary>
/// <param name="Source">The source graphic.</param>
/// <returns>A new bitmap. Caller is responsible for freeing.</returns>
function GraphicToBitmap( Source : TGraphic ) : TBitmap;

/// <summary>
///   Saves a graphic as JPEG format.
/// </summary>
/// <param name="FileName">The destination file path.</param>
/// <param name="Source">The graphic to save.</param>
procedure SaveAsJpeg( const FileName : string; Source : TGraphic );

/// <summary>
///   Saves a graphic as PNG format.
/// </summary>
/// <param name="FileName">The destination file path.</param>
/// <param name="Source">The graphic to save.</param>
procedure SaveAsPng( const FileName : string; Source : TGraphic );

/// <summary>
///   Saves a graphic as BMP format.
/// </summary>
/// <param name="FileName">The destination file path.</param>
/// <param name="Source">The graphic to save.</param>
procedure SaveAsBmp( const FileName : string; Source : TGraphic );

/// <summary>
///   Saves a graphic as GIF format.
/// </summary>
/// <param name="FileName">The destination file path.</param>
/// <param name="Source">The graphic to save.</param>
procedure SaveAsGif( const FileName : string; Source : TGraphic );

/// <summary>
///   Gets the default save handler for a file extension.
/// </summary>
/// <param name="Extension">The file extension (with or without dot).</param>
/// <returns>The save handler, or nil if not found.</returns>
function GetDefaultSaveHandler( const Extension : string ) : TSaveFormatHandler;

implementation

uses
  System.Math, System.StrUtils;

const
  /// <summary>PNG file signature (first 4 bytes: 89 50 4E 47)</summary>
  PNG_SIGNATURE = $474E5089;

  /// <summary>BMP file signature (BM)</summary>
  BMP_SIGNATURE = $4D42;

  /// <summary>JPEG file signature (FF D8)</summary>
  JPEG_SIGNATURE = $D8FF;

  /// <summary>GIF signature (GI) - covers both GIF87a and GIF89a</summary>
  GIF_SIGNATURE = $4947;

  /// <summary>Windows Metafile signature</summary>
  WMF_SIGNATURE = $CDD7;

  /// <summary>Enhanced Metafile record type (EMR_HEADER = 1)</summary>
  EMF_RECORD_TYPE = $00000001;

  /// <summary>Icon file - first word is 0, second word is 1</summary>
  ICO_SIGNATURE_WORD1 = $0000;
  ICO_SIGNATURE_WORD2 = $0001;

  /// <summary>TIFF little-endian signature (II)</summary>
  TIFF_SIGNATURE_LE = $4949;

  /// <summary>TIFF big-endian signature (MM)</summary>
  TIFF_SIGNATURE_BE = $4D4D;

  /// <summary>TIFF magic number (42)</summary>
  TIFF_MAGIC = $002A;

  /// <summary>Minimum valid image stream size</summary>
  MIN_IMAGE_SIZE = 8;

var
  GSupportedExtensions : TDictionary<string, Boolean>;

procedure InitialiseSupportedExtensions;
begin

  GSupportedExtensions := TDictionary<string, Boolean>.Create;
  GSupportedExtensions.Add( '.bmp', True );
  GSupportedExtensions.Add( '.jpg', True );
  GSupportedExtensions.Add( '.jpeg', True );
  GSupportedExtensions.Add( '.png', True );
  GSupportedExtensions.Add( '.gif', True );
  GSupportedExtensions.Add( '.ico', True );
  GSupportedExtensions.Add( '.wmf', True );
  GSupportedExtensions.Add( '.emf', True );
  GSupportedExtensions.Add( '.tif', True );
  GSupportedExtensions.Add( '.tiff', True );
  GSupportedExtensions.Add( '.jxl', True );

end;

procedure FinaliseSupportedExtensions;
begin

  FreeAndNil( GSupportedExtensions );

end;

function IsSupportedExtension( const Extension : string ) : Boolean;
var
  lExt : string;
begin

  lExt := LowerCase( Extension );

  if ( lExt <> '' ) and ( lExt[ 1 ] <> '.' ) then
    lExt := '.' + lExt;

  Result := GSupportedExtensions.ContainsKey( lExt );

end;

function GetSupportedExtensions : TArray<string>;
begin

  Result := GSupportedExtensions.Keys.ToArray;

end;

function GraphicClassExtension( AClass : TGraphicClass ) : string;
begin

  // TJxlImage descends from TBitmap, so it is tested first.
  if ( AClass = nil ) then
    Result := '.img'
  else if AClass.InheritsFrom( TJxlImage ) then
    Result := '.jxl'
  else if AClass.InheritsFrom( TJPEGImage ) then
    Result := '.jpg'
  else if AClass.InheritsFrom( TPngImage ) then
    Result := '.png'
  else if AClass.InheritsFrom( TGIFImage ) then
    Result := '.gif'
  else if AClass.InheritsFrom( TWICImage ) then
    Result := '.tif'
  else if AClass.InheritsFrom( TMetafile ) then
    Result := '.emf'
  else if AClass.InheritsFrom( TIcon ) then
    Result := '.ico'
  else if AClass.InheritsFrom( TBitmap ) then
    Result := '.bmp'
  else
  begin
    Result := GraphicExtension( AClass );

    Result := if Result = '' then '.img' else '.' + Result;
  end;

end;

function GraphicFileExtension( AGraphic : TGraphic ) : string;
begin

  if ( AGraphic = nil ) then
    Exit( '.img' );

  if AGraphic is TWICImage then
    case TWICImage( AGraphic ).ImageFormat of
      wifBmp     : Result := '.bmp';
      wifPng     : Result := '.png';
      wifJpeg    : Result := '.jpg';
      wifGif     : Result := '.gif';
      wifWMPhoto : Result := '.wdp';
    else
      Result := '.tif';
    end
  else if ( AGraphic is TMetafile ) and ( not TMetafile( AGraphic ).Enhanced ) then
    Result := '.wmf'
  else
    Result := GraphicClassExtension( TGraphicClass( AGraphic.ClassType ) );

end;

{ TgllImageFormatRegistry }

class constructor TgllImageFormatRegistry.Create;
begin

  FLoaders      := TList<IgllImageLoader>.Create;
  FExtensionMap := TDictionary<string, IgllImageLoader>.Create;

end;

class destructor TgllImageFormatRegistry.Destroy;
begin

  FreeAndNil( FExtensionMap );
  FreeAndNil( FLoaders );

end;

class procedure TgllImageFormatRegistry.RegisterLoader( Loader : IgllImageLoader );
var
  lExt  : string;
  lExts : TArray<string>;
begin

  if ( Loader = nil ) or FLoaders.Contains( Loader ) then
    Exit;

  FLoaders.Add( Loader );
  lExts := Loader.GetExtensions;

  for lExt in lExts do
  begin

    if ( not FExtensionMap.ContainsKey( LowerCase( lExt ) ) ) then
      FExtensionMap.Add( LowerCase( lExt ), Loader );
  end;

end;

class procedure TgllImageFormatRegistry.UnregisterLoader( Loader : IgllImageLoader );
var
  lExt  : string;
  lExts : TArray<string>;
begin

  if ( Loader = nil ) then
    Exit;

  FLoaders.Remove( Loader );
  lExts := Loader.GetExtensions;

  // GITLAK 2026-09-30: remove only the extensions this loader actually owns, and hand
  // each one to the next registered loader that claims it. It removed every extension
  // the loader listed, including ones another loader had registered first.
  for lExt in lExts do
  begin
    var lKey := LowerCase( lExt );
    var lOwner: IgllImageLoader;

    if FExtensionMap.TryGetValue( lKey, lOwner ) and ( lOwner = Loader ) then
    begin
      FExtensionMap.Remove( lKey );

      for var lOther in FLoaders do
        if ( not FExtensionMap.ContainsKey( lKey ) ) and ( IndexText( lKey, lOther.GetExtensions ) >= 0 ) then
          FExtensionMap.Add( lKey, lOther );
    end;
  end;

end;

class function TgllImageFormatRegistry.GetLoaderForExtension( const Extension : string ) : IgllImageLoader;
var
  lExt : string;
begin

  lExt := LowerCase( Extension );

  if ( lExt <> '' ) and ( lExt[ 1 ] <> '.' ) then
    lExt := '.' + lExt;

  if ( not FExtensionMap.TryGetValue( lExt, Result ) ) then
    Result := nil;

end;

class function TgllImageFormatRegistry.GetLoaderForStream( Stream : TStream ) : IgllImageLoader;
var
  lLoader : IgllImageLoader;
begin

  Result := nil;

  for lLoader in FLoaders do
  begin

    if lLoader.CanLoad( Stream ) then
    begin
      Result := lLoader;
      Exit;
    end;
  end;

end;

class function TgllImageFormatRegistry.GetRegisteredExtensions : TArray<string>;
begin

  Result := FExtensionMap.Keys.ToArray;

end;

function ValidateImageStream( Stream : TStream ) : Boolean;
begin

  Result := ( Stream <> nil ) and ( Stream.Size >= MIN_IMAGE_SIZE );

end;

function DetectImageFormat( Stream : TStream ) : TGraphicClass;
var
  lSavedPos : Int64;
  lBuf4     : Cardinal;
  lBuf8     : array[ 0..7 ] of Byte;
  lWord2    : Word;
begin

  Result := nil;

  if ( not ValidateImageStream( Stream ) ) then
    Exit;

  lSavedPos := Stream.Position;

  try
    Stream.Position := 0;

    if Stream.Read( lBuf8, SizeOf( lBuf8 ) ) < SizeOf( lBuf8 ) then
      Exit;

    lBuf4 := PCardinal( @lBuf8[ 0 ] )^;

    if lBuf4 = PNG_SIGNATURE then
    begin
      Result := TPngImage;
      Exit;
    end;

    if lBuf4 = EMF_RECORD_TYPE then
    begin
      Result := TMetafile;
      Exit;
    end;

    // JPEG XL: a bare codestream (FF 0A) or the ISO BMFF container (00 00 00 0C 'JXL ' ...).
    Stream.Position := 0;

    if TJxlImage.CanLoadFromStream( Stream ) then
    begin
      Result := TJxlImage;
      Exit;
    end;

    case Word( lBuf4 ) of
      BMP_SIGNATURE :
        Result := TBitmap;

      JPEG_SIGNATURE :
        Result := TJPEGImage;

      GIF_SIGNATURE :
        if ( lBuf8[ 2 ] = Ord( 'F' ) ) and ( lBuf8[ 3 ] in [ Ord( '8' ), Ord( '9' ) ] ) then
          Result := TGIFImage;

      WMF_SIGNATURE :
        Result := TMetafile;

      ICO_SIGNATURE_WORD1 :
        begin
          lWord2 := Word( lBuf4 shr 16 );

          if lWord2 = ICO_SIGNATURE_WORD2 then
            Result := TIcon;
        end;

      TIFF_SIGNATURE_LE, TIFF_SIGNATURE_BE :
        begin
          lWord2 := PWord( @lBuf8[ 2 ] )^;

          if ( lWord2 = TIFF_MAGIC ) or ( lWord2 = Swap( TIFF_MAGIC ) ) then
            Result := TWICImage;
        end;
    end;

  finally
    Stream.Position := lSavedPos;
  end;

end;

type
  /// <summary>The header the VCL's TDBImage once wrote before a bitmap (Data.DB declares it in its implementation
  /// section, so it is repeated here with the same layout).</summary>
  TLegacyGraphicHeader = packed record
    /// <summary>Always 1.</summary>
    Count : Word;
    /// <summary>Always $0100.</summary>
    HType : Word;
    /// <summary>Bytes that follow the header.</summary>
    Size  : Integer;
  end;

function StripLegacyGraphicHeader( Stream : TMemoryStream ) : Boolean;
var
  lHeader : TLegacyGraphicHeader;
begin

  Stream.Position := 0;

  // The same test TBlobField.SaveToStreamPersist applies before it hands a stream to a TPicture.
  Result := ( Stream.Size > SizeOf( lHeader ) ) and ( Stream.Read( lHeader, SizeOf( lHeader ) ) = SizeOf( lHeader ) ) and
            ( lHeader.Count = 1 ) and ( lHeader.HType = $0100 ) and ( lHeader.Size = Stream.Size - SizeOf( lHeader ) );

  if Result then
  begin
    var lRest := Stream.Size - SizeOf( lHeader );

    Move( PByte( Stream.Memory )[ SizeOf( lHeader ) ], Stream.Memory^, lRest );
    Stream.Size := lRest;
  end;

  Stream.Position := 0;

end;

/// <summary>Loads a graphic through the formats registered with TPicture (TPicture.RegisterFileFormat), for data
/// none of the signatures in DetectImageFormat matched.</summary>
/// <param name="Stream">The image data, read from position 0.</param>
/// <returns>A new graphic of the registered class, or nil when no registered format recognises the data.</returns>
function CreateRegisteredGraphic( Stream : TStream ) : TGraphic;
begin

  Result := nil;

  var lPicture := TPicture.Create;

  try
    Stream.Position := 0;

    try
      lPicture.LoadFromStream( Stream );
    except
      on EInvalidGraphic do
        Exit;   // no registered format recognises it: the caller reports SUnknownFormat
    end;

    if ( lPicture.Graphic <> nil ) and ( not lPicture.Graphic.Empty ) then
    begin
      Result := TGraphicClass( lPicture.Graphic.ClassType ).Create;
      Result.Assign( lPicture.Graphic );
    end;
  finally
    lPicture.Free;
  end;

end;

function CreateGraphicFromStream( Stream : TStream; out ErrorMsg : string ) : TGraphic;
begin

  Result   := nil;
  ErrorMsg := '';

  var lGraphicClass := DetectImageFormat( Stream );

  try

    if ( lGraphicClass <> nil ) then
    begin
      Result          := lGraphicClass.Create;
      Stream.Position := 0;
      Result.LoadFromStream( Stream );
    end
    else
      Result := CreateRegisteredGraphic( Stream );

  except
    on E : EInvalidGraphic do
    begin
      ErrorMsg := Format( SInvalidGraphicFormat, [ E.Message ] );
      FreeAndNil( Result );
    end;

    on E : EReadError do
    begin
      ErrorMsg := Format( SErrorReadingImageData, [ E.Message ] );
      FreeAndNil( Result );
    end;

    on E : Exception do
    begin
      ErrorMsg := Format( SErrorLoadingImage, [ E.Message ] );
      FreeAndNil( Result );
    end;
  end;

  if ( Result = nil ) and ( ErrorMsg = '' ) then
    ErrorMsg := SUnknownFormat;

end;

procedure ReplaceGraphicKeepingFormat( Picture : TPicture; ABitmap : TBitmap );
begin

  var lOld := Picture.Graphic;

  // A bitmap, an empty picture, or a class that cannot take pixels from a bitmap: store the bitmap itself.
  if ( lOld = nil ) or ( lOld.ClassType = TBitmap ) or ( lOld is TIcon ) or ( lOld is TMetafile ) then
  begin
    Picture.Bitmap.Assign( ABitmap );
    Exit;
  end;

  var lNew := TGraphicClass( lOld.ClassType ).Create;

  try
    // Copy the old graphic first, so its encoder settings (TJPEGImage.CompressionQuality, TJxlImage.Lossless /
    // Distance / Effort) carry over to the re-encode; then take the new pixels.
    lNew.Assign( lOld );
    lNew.Assign( ABitmap );
    Picture.Graphic := lNew;   // TPicture copies the graphic
  finally
    lNew.Free;
  end;

end;

procedure LoadPictureEx( Memoria : TMemoryStream; Picture : TPicture; Field : TField;
  Evento : TLoadCustomImageEvent; Loaded : Boolean );
var
  lErrorMsg : string;
begin

  LoadPictureEx( Memoria, Picture, Field, Evento, Loaded, lErrorMsg );

end;

function LoadPictureEx( Memoria : TMemoryStream; Picture : TPicture; Field : TField;
  Evento : TLoadCustomImageEvent; Loaded : Boolean; out ErrorMsg : string ) : Boolean;
var
  lGraphic      : TGraphic;
  lPluginLoader : IgllImageLoader;
  lDetectError  : string;
begin

  Result   := False;
  ErrorMsg := '';

  if ( Field = nil ) then
  begin
    ErrorMsg := SFieldIsNil;
    Picture.Assign( nil );
    Exit;
  end;

  if ( not Field.IsBlob ) then
  begin
    ErrorMsg := SFieldNotBlob;
    Picture.Assign( nil );
    Exit;
  end;

  if Field.IsNull then
  begin
    Picture.Assign( nil );
    Result := True;
    Exit;
  end;

  if Loaded then
  begin
    Result := True;
    Exit;
  end;

  lGraphic := nil;

  try
    Memoria.Clear;

    try
      ( Field as TBlobField ).SaveToStream( Memoria );
    except
      on E : EInvalidCast do
      begin
        ErrorMsg := Format( SInvalidFieldType, [ E.Message ] );
        Picture.Assign( nil );
        Exit;
      end;

      on E : Exception do
      begin
        ErrorMsg := Format( SErrorReadingField, [ E.Message ] );
        Picture.Assign( nil );
        Exit;
      end;
    end;

    if ( not ValidateImageStream( Memoria ) ) then
    begin
      ErrorMsg := SStreamTooSmall;
      Picture.Assign( nil );
      Exit;
    end;

    StripLegacyGraphicHeader( Memoria );
    Memoria.Position := 0;

    lPluginLoader := TgllImageFormatRegistry.GetLoaderForStream( Memoria );

    if ( lPluginLoader <> nil ) then
    begin
      Memoria.Position := 0;

      try
        lGraphic := lPluginLoader.Load( Memoria );
        Result   := ( lGraphic <> nil );
      except
        on E : Exception do
        begin
          ErrorMsg := Format( SErrorLoadingImage, [ E.Message ] );
          FreeAndNil( lGraphic );
        end;
      end;
    end;

    if ( lGraphic = nil ) then
    begin
      lGraphic := CreateGraphicFromStream( Memoria, lDetectError );

      if ( lGraphic <> nil ) then
      begin
        Result   := True;
        ErrorMsg := '';
      end
      // An unrecognised format leaves ErrorMsg empty, so OnLoadCustomImage still gets its turn below.
      else if ( ErrorMsg = '' ) and ( lDetectError <> SUnknownFormat ) then
        ErrorMsg := lDetectError;
    end;

    if ( lGraphic = nil ) and Assigned( Evento ) then
    begin
      Memoria.Position := 0;

      try
        Evento( lGraphic, Memoria );

        if ( lGraphic <> nil ) then
          Result := True;
      except
        on E : EInvalidGraphic do
        begin
          ErrorMsg := Format( SCustomLoaderInvalidGraphic, [ E.Message ] );
          FreeAndNil( lGraphic );
        end;

        on E : Exception do
        begin
          ErrorMsg := Format( SCustomLoaderError, [ E.Message ] );
          FreeAndNil( lGraphic );
        end;
      end;
    end;

    if ( lGraphic = nil ) and ( ErrorMsg = '' ) then
      ErrorMsg := SUnknownFormat;

    Picture.Assign( lGraphic );

  finally
    lGraphic.Free;
    Memoria.Clear;
  end;

end;

function LoadPictureAsync( Field : TField; Callback : TAsyncLoadCallback ) : IFuture<TGraphic>;
var
  lFieldData : TBytes;
begin

  if ( Field = nil ) or ( not Field.IsBlob ) or Field.IsNull then
  begin

    if Assigned( Callback ) then
      TThread.Queue( nil,
        procedure
        begin
          Callback( nil, '' );
        end );

    Result := nil;
    Exit;
  end;

  lFieldData := ( Field as TBlobField ).AsBytes;

  Result := TTask.Future<TGraphic>(
    function : TGraphic
    var
      lStream   : TMemoryStream;
      lErrorMsg : string;
    begin

      Result    := nil;
      lErrorMsg := '';

      lStream := TMemoryStream.Create;

      try
        lStream.WriteBuffer( lFieldData[ 0 ], Length( lFieldData ) );
        lStream.Position := 0;

        if ( not ValidateImageStream( lStream ) ) then
          lErrorMsg := SStreamTooSmall
        else
        begin
          StripLegacyGraphicHeader( lStream );
          Result := CreateGraphicFromStream( lStream, lErrorMsg );
        end;

        if Assigned( Callback ) then
        begin

          var lResult   := Result;
          var lError    := lErrorMsg;

          TThread.Queue( nil,
            procedure
            begin
              Callback( lResult, lError );
            end );
        end;

      finally
        lStream.Free;
      end;

    end );

end;

function Rescale( ARect : TRect; DrawPict : TPicture ) : TRect;
var
  lWidthRatio   : Double;
  lHeightRatio  : Double;
  lClientWidth  : Integer;
  lClientHeight : Integer;
  lScaledSize   : Integer;
  lOffset       : Integer;
begin

  lClientWidth  := ARect.Right - ARect.Left;
  lClientHeight := ARect.Bottom - ARect.Top;

  if ( DrawPict.Width <= 0 ) or ( DrawPict.Height <= 0 ) or
     ( lClientWidth <= 0 ) or ( lClientHeight <= 0 ) then
  begin
    Result := ARect;
    Exit;
  end;

  lWidthRatio  := DrawPict.Width / lClientWidth;
  lHeightRatio := DrawPict.Height / lClientHeight;

  if lWidthRatio > lHeightRatio then
  begin
    lScaledSize := Trunc( DrawPict.Height * lClientWidth / DrawPict.Width );
    lOffset     := ( lClientHeight - lScaledSize ) div 2;
    Result      := Rect( ARect.Left, ARect.Top + lOffset,
                         ARect.Left + lClientWidth, ARect.Top + lOffset + lScaledSize );
  end
  else
  begin
    lScaledSize := Trunc( DrawPict.Width * lClientHeight / DrawPict.Height );
    lOffset     := ( lClientWidth - lScaledSize ) div 2;
    Result      := Rect( ARect.Left + lOffset, ARect.Top,
                         ARect.Left + lOffset + lScaledSize, ARect.Top + lClientHeight );
  end;

end;

function GraphicToBitmap( Source : TGraphic ) : TBitmap;
begin

  Result := TBitmap.Create;

  try
    Result.PixelFormat := pf32bit;
    Result.AlphaFormat := afDefined;
    Result.SetSize( Source.Width, Source.Height );
    Result.Canvas.Brush.Color := clWhite;
    Result.Canvas.FillRect( Rect( 0, 0, Result.Width, Result.Height ) );
    Result.Canvas.Draw( 0, 0, Source );
  except
    FreeAndNil( Result );
    raise;
  end;

end;

function RotateBitmap( Source : TBitmap; Angle : TRotationAngle ) : TBitmap;
var
  lX, lY       : Integer;
  lNewWidth    : Integer;
  lNewHeight   : Integer;
  lSrcScanLine : PByteArray;
  lDstScanLine : PByteArray;
  lPixelSize   : Integer;
begin

  if ( Angle = ro0 ) then
  begin
    Result := TBitmap.Create;
    Result.Assign( Source );
    Exit;
  end;

  Result := TBitmap.Create;

  try
    Result.PixelFormat := pf32bit;

    case Angle of
      ro90, ro270 :
        begin
          lNewWidth  := Source.Height;
          lNewHeight := Source.Width;
        end;
    else
      begin
        lNewWidth  := Source.Width;
        lNewHeight := Source.Height;
      end;
    end;

    Result.SetSize( lNewWidth, lNewHeight );

    if Source.PixelFormat <> pf32bit then
    begin

      var lTemp := TBitmap.Create;

      try
        lTemp.PixelFormat := pf32bit;
        lTemp.SetSize( Source.Width, Source.Height );
        lTemp.Canvas.Draw( 0, 0, Source );

        for lY := 0 to Source.Height - 1 do
        begin
          lSrcScanLine := lTemp.ScanLine[ lY ];

          for lX := 0 to Source.Width - 1 do
          begin

            case Angle of
              ro90 :
                begin
                  lDstScanLine := Result.ScanLine[ lX ];
                  Move( lSrcScanLine[ lX * 4 ], lDstScanLine[ ( Source.Height - 1 - lY ) * 4 ], 4 );
                end;

              ro180 :
                begin
                  lDstScanLine := Result.ScanLine[ Source.Height - 1 - lY ];
                  Move( lSrcScanLine[ lX * 4 ], lDstScanLine[ ( Source.Width - 1 - lX ) * 4 ], 4 );
                end;

              ro270 :
                begin
                  lDstScanLine := Result.ScanLine[ Source.Width - 1 - lX ];
                  Move( lSrcScanLine[ lX * 4 ], lDstScanLine[ lY * 4 ], 4 );
                end;
            end;
          end;
        end;

      finally
        lTemp.Free;
      end;
    end
    else
    begin
      lPixelSize := 4;

      for lY := 0 to Source.Height - 1 do
      begin
        lSrcScanLine := Source.ScanLine[ lY ];

        for lX := 0 to Source.Width - 1 do
        begin

          case Angle of
            ro90 :
              begin
                lDstScanLine := Result.ScanLine[ lX ];
                Move( lSrcScanLine[ lX * lPixelSize ], lDstScanLine[ ( Source.Height - 1 - lY ) * lPixelSize ], lPixelSize );
              end;

            ro180 :
              begin
                lDstScanLine := Result.ScanLine[ Source.Height - 1 - lY ];
                Move( lSrcScanLine[ lX * lPixelSize ], lDstScanLine[ ( Source.Width - 1 - lX ) * lPixelSize ], lPixelSize );
              end;

            ro270 :
              begin
                lDstScanLine := Result.ScanLine[ Source.Width - 1 - lX ];
                Move( lSrcScanLine[ lX * lPixelSize ], lDstScanLine[ lY * lPixelSize ], lPixelSize );
              end;
          end;
        end;
      end;
    end;

  except
    FreeAndNil( Result );
    raise;
  end;

end;

function FlipBitmap( Source : TBitmap; Direction : TFlipDirection ) : TBitmap;
var
  lX, lY       : Integer;
  lSrcScanLine : PByteArray;
  lDstScanLine : PByteArray;
  lPixelSize   : Integer;
  lTemp        : TBitmap;
begin

  Result := TBitmap.Create;

  try
    Result.PixelFormat := pf32bit;
    Result.SetSize( Source.Width, Source.Height );

    if Source.PixelFormat <> pf32bit then
    begin
      lTemp := TBitmap.Create;

      try
        lTemp.PixelFormat := pf32bit;
        lTemp.SetSize( Source.Width, Source.Height );
        lTemp.Canvas.Draw( 0, 0, Source );

        case Direction of
          fdHorizontal :
            for lY := 0 to Source.Height - 1 do
            begin
              lSrcScanLine := lTemp.ScanLine[ lY ];
              lDstScanLine := Result.ScanLine[ lY ];

              for lX := 0 to Source.Width - 1 do
                Move( lSrcScanLine[ lX * 4 ], lDstScanLine[ ( Source.Width - 1 - lX ) * 4 ], 4 );
            end;

          fdVertical :
            for lY := 0 to Source.Height - 1 do
            begin
              lSrcScanLine := lTemp.ScanLine[ lY ];
              lDstScanLine := Result.ScanLine[ Source.Height - 1 - lY ];
              Move( lSrcScanLine^, lDstScanLine^, Source.Width * 4 );
            end;
        end;

      finally
        lTemp.Free;
      end;
    end
    else
    begin
      lPixelSize := 4;

      case Direction of
        fdHorizontal :
          for lY := 0 to Source.Height - 1 do
          begin
            lSrcScanLine := Source.ScanLine[ lY ];
            lDstScanLine := Result.ScanLine[ lY ];

            for lX := 0 to Source.Width - 1 do
              Move( lSrcScanLine[ lX * lPixelSize ], lDstScanLine[ ( Source.Width - 1 - lX ) * lPixelSize ], lPixelSize );
          end;

        fdVertical :
          for lY := 0 to Source.Height - 1 do
          begin
            lSrcScanLine := Source.ScanLine[ lY ];
            lDstScanLine := Result.ScanLine[ Source.Height - 1 - lY ];
            Move( lSrcScanLine^, lDstScanLine^, Source.Width * lPixelSize );
          end;
      end;
    end;

  except
    FreeAndNil( Result );
    raise;
  end;

end;

function CreateThumbnail( Source : TGraphic; MaxWidth, MaxHeight : Integer;
  MaintainAspect : Boolean ) : TBitmap;
var
  lScale       : Double;
  lScaleWidth  : Double;
  lScaleHeight : Double;
  lNewWidth    : Integer;
  lNewHeight   : Integer;
  lDestRect    : TRect;
begin

  Result := TBitmap.Create;

  try
    Result.PixelFormat := pf32bit;

    if MaintainAspect then
    begin
      lScaleWidth  := MaxWidth / Source.Width;
      lScaleHeight := MaxHeight / Source.Height;
      lScale       := Min( lScaleWidth, lScaleHeight );
      lNewWidth    := Round( Source.Width * lScale );
      lNewHeight   := Round( Source.Height * lScale );
    end
    else
    begin
      lNewWidth  := MaxWidth;
      lNewHeight := MaxHeight;
    end;

    Result.SetSize( lNewWidth, lNewHeight );
    Result.Canvas.Brush.Color := clWhite;
    Result.Canvas.FillRect( Rect( 0, 0, lNewWidth, lNewHeight ) );

    lDestRect := Rect( 0, 0, lNewWidth, lNewHeight );
    Result.Canvas.StretchDraw( lDestRect, Source );

  except
    FreeAndNil( Result );
    raise;
  end;

end;

procedure PrintGraphic( Source : TGraphic; const Title : string;
  FitToPage : Boolean; CenterOnPage : Boolean );
var
  lPrintRect   : TRect;
  lScale       : Double;
  lScaleWidth  : Double;
  lScaleHeight : Double;
  lPrintWidth  : Integer;
  lPrintHeight : Integer;
  lOffsetX     : Integer;
  lOffsetY     : Integer;
  lPageWidth   : Integer;
  lPageHeight  : Integer;
  lPrintTitle  : string;
begin

  if ( Source = nil ) or Source.Empty then
    Exit;

  if Title = '' then
    lPrintTitle := SPrintJobName
  else
    lPrintTitle := Title;

  Printer.Title := lPrintTitle;
  Printer.BeginDoc;

  try
    lPageWidth  := Printer.PageWidth;
    lPageHeight := Printer.PageHeight;

    if FitToPage then
    begin
      lScaleWidth  := lPageWidth / Source.Width;
      lScaleHeight := lPageHeight / Source.Height;
      lScale       := Min( lScaleWidth, lScaleHeight );
      lPrintWidth  := Round( Source.Width * lScale );
      lPrintHeight := Round( Source.Height * lScale );
    end
    else
    begin
      lPrintWidth  := Source.Width;
      lPrintHeight := Source.Height;
    end;

    if CenterOnPage then
    begin
      lOffsetX := ( lPageWidth - lPrintWidth ) div 2;
      lOffsetY := ( lPageHeight - lPrintHeight ) div 2;
    end
    else
    begin
      lOffsetX := 0;
      lOffsetY := 0;
    end;

    lPrintRect := Rect( lOffsetX, lOffsetY, lOffsetX + lPrintWidth, lOffsetY + lPrintHeight );
    Printer.Canvas.StretchDraw( lPrintRect, Source );

  finally
    Printer.EndDoc;
  end;

end;

procedure SaveAsJpeg( const FileName : string; Source : TGraphic );
var
  lTemp : TBitmap;
  lJpg  : TJPEGImage;
begin

  if ( Source is TJPEGImage ) then
    Source.SaveToFile( FileName )
  else
  begin
    lTemp := TBitmap.Create;

    try
      lTemp.Assign( Source );
      lJpg := TJPEGImage.Create;

      try
        lJpg.Assign( lTemp );
        lJpg.SaveToFile( FileName );
      finally
        lJpg.Free;
      end;

    finally
      lTemp.Free;
    end;
  end;

end;

procedure SaveAsPng( const FileName : string; Source : TGraphic );
var
  lPng : TPngImage;
begin

  if ( Source is TPngImage ) then
    Source.SaveToFile( FileName )
  else
  begin
    lPng := TPngImage.Create;

    try
      lPng.Assign( Source );
      lPng.SaveToFile( FileName );
    finally
      lPng.Free;
    end;
  end;

end;

procedure SaveAsBmp( const FileName : string; Source : TGraphic );
var
  lBmp : TBitmap;
begin

  if ( Source is TBitmap ) then
    Source.SaveToFile( FileName )
  else
  begin
    lBmp := TBitmap.Create;

    try
      lBmp.Assign( Source );
      lBmp.SaveToFile( FileName );
    finally
      lBmp.Free;
    end;
  end;

end;

procedure SaveAsGif( const FileName : string; Source : TGraphic );
var
  lGif : TGIFImage;
begin

  if ( Source is TGIFImage ) then
    Source.SaveToFile( FileName )
  else
  begin
    lGif := TGIFImage.Create;

    try
      lGif.Assign( Source );
      lGif.SaveToFile( FileName );
    finally
      lGif.Free;
    end;
  end;

end;

function GetDefaultSaveHandler( const Extension : string ) : TSaveFormatHandler;
var
  lExt : string;
begin

  Result := nil;
  lExt   := LowerCase( Extension );

  if ( lExt <> '' ) and ( lExt[ 1 ] <> '.' ) then
    lExt := '.' + lExt;

  if ( lExt = '.jpg' ) or ( lExt = '.jpeg' ) then
    Result := SaveAsJpeg
  else if ( lExt = '.png' ) then
    Result := SaveAsPng
  else if ( lExt = '.bmp' ) then
    Result := SaveAsBmp
  else if ( lExt = '.gif' ) then
    Result := SaveAsGif;

end;

initialization

  InitialiseSupportedExtensions;

finalization

  FinaliseSupportedExtensions;

end.
