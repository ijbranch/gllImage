(* Copyright (c) 2026 Ian Branch. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style
 * license that can be found in the LICENSE file.
 *)
(*
  gllImage.DB - TgllDBImage, the enhanced database image component
  Version: 4.0

  Original Copyright (c) 2000-2025 Sebastián Mayorá, Argentina
  Original Author: Sebastián Mayorá (DelphiHelper@yahoo.com.ar)
  Further developed by Roy Lambert (EDBImage).

  Original licence: Freeware - Use at your own risk.  gllImage: BSD 3-Clause
  (see the LICENSE file).

  Description:
    TgllDBImage is an enhanced version of the standard TDBImage component
    providing support for multiple image formats and improved scaling options.

  Supported Formats:
    Native: .ico .jpg .jpeg .wmf .emf .bmp .png .gif
    Extended (via GraphicEx): .tiff .tif and more

  Version 4.0 Changes (GITLAK 2026-10-19):
    - Moved from gdbximage (GITLAKDB) into the gllImage project.
    - The viewer (scaling, zoom, pan, rotation, flip, animation, clipboard, print, context menu) moved into
      TgllCustomImageView (gllImage.View), which TgllImageView also descends from; TgllDBImage keeps the data link.

  Version 3.0 Enhancements:
    - Image rotation (90/180/270 degrees)
    - Image flip (horizontal/vertical)
    - Pan and scroll when zoomed
    - Thumbnail generation on demand

    - Print support
    - Async loading for large images
    - Animated GIF playback
    - Plugin architecture for format extensibility
    - Resource strings for localisation
    - Performance optimisations

  Version 2.0 Enhancements:
    - Native PNG support
    - Mouse wheel zoom
    - Drag and drop file support
    - Built-in context menu
    - Image information properties
    - Transparent background with checkerboard pattern
    - Optimised paint caching
    - Error state display
    - Improved exception handling

  Contributors:
    - Liliana Troncoso (ShrinkToFit/ZoomToFit)
    - Shraga Milon (WMClear/WMUndo)
    - Mike Lischke (GraphicEx library)
    - Ian Branch (Version 2.0, 3.0 and 4.0 enhancements)
*)

unit gllImage.DB;

{$D-}

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Classes, System.Threading,
  Data.DB,
  Vcl.DBCtrls, Vcl.Graphics, Vcl.Controls,

  gllImage.Consts,
  gllImage.Utils,
  gllImage.View;

type
  /// <summary>
  ///   Enhanced database-aware image component with multi-format support.
  /// </summary>
  /// <remarks>
  ///   The viewer behaviour (scaling, clipboard, drag and drop, mouse wheel zoom, rotation, flip, pan, print,
  ///   animated GIF playback) comes from TgllCustomImageView; this class links it to a BLOB field. Supported formats
  ///   include JPEG, PNG, BMP, GIF, ICO, WMF, EMF, and optionally TIFF via GraphicEx.
  /// </remarks>
  /// <example>
  ///   <code>
  ///   // Basic usage
  ///   gllImage1.DataSource := DataSource1;
  ///   gllImage1.DataField := 'Photo';
  ///   gllImage1.FitToWindow := True;
  ///
  ///   // Rotation
  ///   gllImage1.RotateClockwise;
  ///
  ///   // Print
  ///   gllImage1.Print;
  ///   </code>
  /// </example>
  TgllDBImage = class( TgllCustomImageView )
  private
    /// <summary>Links the control to its BLOB field; nil only during destruction.</summary>
    FDataLink           : TFieldDataLink;
    /// <summary>Scratch stream used while reading the BLOB field.</summary>
    FMemoria            : TMemoryStream;
    /// <summary>When True the picture loads as soon as the record changes.</summary>
    FAutoDisplay        : Boolean;
    /// <summary>Handler that decodes formats the built-in loaders do not recognise.</summary>
    FOnLoadCustomImage  : TLoadCustomImageEvent;
    /// <summary>True while an asynchronous load is in flight.</summary>
    FAsyncLoading       : Boolean;
    /// <summary>The task of the asynchronous load in flight.</summary>
    FAsyncFuture        : IFuture<TGraphic>;
    /// <summary>Cancellation token of the load in flight (an IgllImageLoadToken); nil when none.</summary>
    FAsyncToken         : IInterface;

    /// <summary>Handles a record change: clears the picture, cancels any async load, and reloads when AutoDisplay is on.</summary>
    /// <param name="Sender">The object that raised the event.</param>
    procedure DataChange( Sender : TObject );
    /// <summary>Getter for DataField.</summary>
    /// <returns>The linked field name.</returns>
    function GetDataField : string;
    /// <summary>Getter for DataSource.</summary>
    /// <returns>The linked data source.</returns>
    function GetDataSource : TDataSource;
    /// <summary>Getter for Field.</summary>
    /// <returns>The linked field, or nil.</returns>
    function GetField : TField;
    /// <summary>Setter for AutoDisplay.</summary>
    /// <param name="Value">The new value.</param>
    procedure SetAutoDisplay( Value : Boolean );
    /// <summary>Setter for DataField.</summary>
    /// <param name="Value">The new value.</param>
    procedure SetDataField( const Value : string );
    /// <summary>Setter for DataSource.</summary>
    /// <param name="Value">The new value.</param>
    procedure SetDataSource( Value : TDataSource );
    /// <summary>Writes the picture to the field when the data link asks for it; an empty picture clears the field.</summary>
    /// <param name="Sender">The object that raised the event.</param>
    procedure UpdateData( Sender : TObject );
    /// <summary>Abandons the asynchronous load in flight, if any: its result is discarded when it arrives.</summary>
    procedure CancelAsyncLoad;
    /// <summary>Answers CM_GETDATALINK with the control's data link.</summary>
    /// <param name="Message">The window message.</param>
    procedure CMGetDataLink( var Message : TMessage ); message CM_GETDATALINK;
    /// <summary>Writes a pending edit to the record on exit (refocusing on failure) and repaints.</summary>
    /// <param name="Message">The window message.</param>
    procedure CMExit( var Message : TCMExit ); message CM_EXIT;
    /// <summary>Loads the picture on double-click when it is not yet loaded.</summary>
    /// <param name="Message">The window message.</param>
    procedure WMLButtonDblClk( var Message : TWMLButtonDblClk ); message WM_LBUTTONDBLCLK;
    /// <summary>Handles WM_UNDO by reloading the picture from the field.</summary>
    /// <param name="Message">The window message.</param>
    procedure WMUndo( var Message : TMessage ); message WM_UNDO;

  protected
    /// <summary>Handles Ctrl+X/C/V/Z, Enter (load the picture) and Escape (reset to the field's value).</summary>
    /// <param name="Key">The key; set to 0 when handled.</param>
    procedure KeyPress( var Key : Char ); override;
    /// <summary>Clears DataSource when the linked data source is freed.</summary>
    /// <param name="AComponent">The component being inserted or removed.</param>
    /// <param name="Operation">The notification kind.</param>
    procedure Notification( AComponent : TComponent; Operation : TOperation ); override;
    /// <summary>Puts the dataset into edit mode for a change made through the control.</summary>
    /// <returns>True when the record is (now) being edited.</returns>
    function CanModify : Boolean; override;
    /// <summary>Getter for ReadOnly.</summary>
    /// <returns>True when the data link is read-only.</returns>
    function GetReadOnly : Boolean; override;
    /// <summary>Setter for ReadOnly.</summary>
    /// <param name="Value">The new value.</param>
    procedure SetReadOnly( Value : Boolean ); override;
    /// <summary>Marks the record modified, so the next Post writes the picture back.</summary>
    procedure PictureModified; override;
    /// <summary>Loads the current row's picture for a TDBCtrlGrid paint copy.</summary>
    /// <param name="APicture">The picture to load into.</param>
    /// <returns>True when the control is linked to a BLOB field and APicture was loaded from it.</returns>
    function LoadPaintCopy( APicture : TPicture ) : Boolean; override;
    /// <summary>The field's DisplayLabel, or the control's Name when no field is linked.</summary>
    /// <returns>The caption drawn while the picture is not loaded.</returns>
    function GetPlaceholderCaption : string; override;
    /// <summary>Writes the field's own bytes to a file in AFolder for a drag-out, named for the format they hold, so
    /// the file is exactly what is stored (an old TDBImage header removed).  A change made through the control and
    /// not yet posted is written to the field first, as Post would write it.</summary>
    /// <param name="AFolder">An existing, empty temporary folder.</param>
    /// <returns>The file written; the picture saved by the viewer when the field's format is not recognised; an
    /// empty string when there is nothing to drag.</returns>
    function SaveDragOutFile( const AFolder : string ) : string; override;

  public
    /// <summary>Creates the component, initialising defaults and the data link.</summary>
    /// <param name="AOwner">The owning component.</param>
    constructor Create( AOwner : TComponent ); override;

    /// <summary>Destroys the component, abandoning any load in flight before the viewer is freed.</summary>
    destructor Destroy; override;

    /// <summary>Routes a standard VCL action (e.g. clipboard actions) to the data link when applicable.</summary>
    /// <param name="Action">The action to execute.</param>
    /// <returns>True if the action was handled by this control or its data link.</returns>
    function ExecuteAction( Action : TBasicAction ) : Boolean; override;

    /// <summary>
    ///   Loads the picture from the linked database field.
    /// </summary>
    procedure LoadPicture;

    /// <summary>
    ///   Loads the picture asynchronously from the linked database field.
    /// </summary>
    /// <example>
    ///   <code>
    ///   gllImage1.LoadPictureAsync;
    ///   // Image will load in background and display when ready
    ///   </code>
    /// </example>
    procedure LoadPictureAsync;

    /// <summary>Updates the enabled/visible state of a standard VCL action based on the current control state.</summary>
    /// <param name="Action">The action to update.</param>
    /// <returns>True if the action was updated by this control or its data link.</returns>
    function UpdateAction( Action : TBasicAction ) : Boolean; override;

    /// <summary>
    ///   Loads an image from a file into the linked database field.
    /// </summary>
    /// <remarks>A failure (no field, not a BLOB field, the record cannot be edited, an unreadable file) is reported
    /// through LastError and OnImageError, not raised.</remarks>
    /// <param name="FileName">The path to the image file.</param>
    procedure LoadFromFile( const FileName : string ); override;

    /// <summary>
    ///   The linked database field.
    /// </summary>
    property Field : TField read GetField;

    /// <summary>
    ///   Indicates whether async loading is in progress.
    /// </summary>
    property AsyncLoading : Boolean read FAsyncLoading;

  published
    /// <summary>Inherited <c>Align</c>, published.</summary>
    property Align;
    /// <summary>Inherited <c>Anchors</c>, published.</summary>
    property Anchors;
    /// <summary>When True the picture loads as soon as the record changes; otherwise on double-click or Enter.</summary>
    property AutoDisplay : Boolean read FAutoDisplay write SetAutoDisplay default True;
    /// <summary>Inherited <c>BorderStyle</c>, published.</summary>
    property BorderStyle;
    /// <summary>Inherited <c>Center</c>, published.</summary>
    property Center;
    /// <summary>Inherited <c>Color</c>, published.</summary>
    property Color;
    /// <summary>Inherited <c>Constraints</c>, published.</summary>
    property Constraints;
    /// <summary>Inherited <c>Ctl3D</c>, published.</summary>
    property Ctl3D;
    /// <summary>Name of the BLOB field the picture comes from.</summary>
    property DataField : string read GetDataField write SetDataField;
    /// <summary>Data source of the dataset holding DataField.</summary>
    property DataSource : TDataSource read GetDataSource write SetDataSource;
    /// <summary>Inherited <c>DragCursor</c>, published.</summary>
    property DragCursor;
    /// <summary>Inherited <c>DragKind</c>, published.</summary>
    property DragKind;
    /// <summary>Inherited <c>DragMode</c>, published.</summary>
    property DragMode;
    /// <summary>Inherited <c>Enabled</c>, published.</summary>
    property Enabled;
    /// <summary>Inherited <c>Font</c>, published.</summary>
    property Font;
    /// <summary>Inherited <c>ParentColor</c>, published.</summary>
    property ParentColor default False;
    /// <summary>Inherited <c>ParentCtl3D</c>, published.</summary>
    property ParentCtl3D;
    /// <summary>Inherited <c>ParentFont</c>, published.</summary>
    property ParentFont;
    /// <summary>Inherited <c>ParentShowHint</c>, published.</summary>
    property ParentShowHint;
    /// <summary>Inherited <c>PopupMenu</c>, published.</summary>
    property PopupMenu;
    /// <summary>Inherited <c>ReadOnly</c>, published.</summary>
    property ReadOnly;
    /// <summary>Inherited <c>QuickDraw</c>, published.</summary>
    property QuickDraw;
    /// <summary>Inherited <c>ShowHint</c>, published.</summary>
    property ShowHint;
    /// <summary>Inherited <c>ShrinkToFit</c>, published.</summary>
    property ShrinkToFit;
    /// <summary>Inherited <c>TabOrder</c>, published.</summary>
    property TabOrder;
    /// <summary>Inherited <c>ZoomToFit</c>, published.</summary>
    property ZoomToFit;
    /// <summary>Inherited <c>TabStop</c>, published.</summary>
    property TabStop default True;
    /// <summary>Inherited <c>Visible</c>, published.</summary>
    property Visible;
    /// <summary>Inherited <c>FitToWindow</c>, published.</summary>
    property FitToWindow;
    /// <summary>Inherited <c>MaintainAspectRatio</c>, published.</summary>
    property MaintainAspectRatio;
    /// <summary>Inherited <c>TransparentMode</c>, published.</summary>
    property TransparentMode;
    /// <summary>Inherited <c>CheckerSize</c>, published.</summary>
    property CheckerSize;
    /// <summary>Inherited <c>CheckerColour1</c>, published.</summary>
    property CheckerColour1;
    /// <summary>Inherited <c>CheckerColour2</c>, published.</summary>
    property CheckerColour2;
    /// <summary>Inherited <c>EnableMouseWheel</c>, published.</summary>
    property EnableMouseWheel;
    /// <summary>Inherited <c>ZoomFactor</c>, published.</summary>
    property ZoomFactor;
    /// <summary>Inherited <c>RenderMode</c>, published.</summary>
    property RenderMode;
    /// <summary>Inherited <c>MinZoom</c>, published.</summary>
    property MinZoom;
    /// <summary>Inherited <c>MaxZoom</c>, published.</summary>
    property MaxZoom;
    /// <summary>Inherited <c>EnableDragDrop</c>, published.</summary>
    property EnableDragDrop;
    /// <summary>Inherited <c>EnableDragOut</c>, published.</summary>
    property EnableDragOut;
    /// <summary>Inherited <c>DragOutFileName</c>, published.</summary>
    property DragOutFileName;
    /// <summary>Inherited <c>ShowErrorState</c>, published.</summary>
    property ShowErrorState;
    /// <summary>Inherited <c>MaxImageWidth</c>, published.</summary>
    property MaxImageWidth;
    /// <summary>Inherited <c>MaxImageHeight</c>, published.</summary>
    property MaxImageHeight;
    /// <summary>Inherited <c>EnablePan</c>, published.</summary>
    property EnablePan;
    /// <summary>Inherited <c>ScrollBars</c>, published.</summary>
    property ScrollBars;
    /// <summary>Inherited <c>ShowContextMenu</c>, published.</summary>
    property ShowContextMenu;
    /// <summary>Inherited <c>Stretch</c>, published.</summary>
    property Stretch;
    /// <summary>Inherited <c>Proportional</c>, published.</summary>
    property Proportional;
    /// <summary>Inherited <c>OnFilesDropped</c>, published.</summary>
    property OnFilesDropped;
    /// <summary>Inherited <c>Rotation</c>, published.</summary>
    property Rotation;
    /// <summary>Inherited <c>OnClick</c>, published.</summary>
    property OnClick;
    /// <summary>Inherited <c>OnContextPopup</c>, published.</summary>
    property OnContextPopup;
    /// <summary>Inherited <c>OnDblClick</c>, published.</summary>
    property OnDblClick;
    /// <summary>Inherited <c>OnDragDrop</c>, published.</summary>
    property OnDragDrop;
    /// <summary>Inherited <c>OnDragOver</c>, published.</summary>
    property OnDragOver;
    /// <summary>Inherited <c>OnEndDock</c>, published.</summary>
    property OnEndDock;
    /// <summary>Inherited <c>OnEndDrag</c>, published.</summary>
    property OnEndDrag;
    /// <summary>Inherited <c>OnEnter</c>, published.</summary>
    property OnEnter;
    /// <summary>Inherited <c>OnExit</c>, published.</summary>
    property OnExit;
    /// <summary>Inherited <c>OnKeyDown</c>, published.</summary>
    property OnKeyDown;
    /// <summary>Inherited <c>OnKeyPress</c>, published.</summary>
    property OnKeyPress;
    /// <summary>Inherited <c>OnKeyUp</c>, published.</summary>
    property OnKeyUp;
    /// <summary>Inherited <c>OnMouseDown</c>, published.</summary>
    property OnMouseDown;
    /// <summary>Inherited <c>OnMouseMove</c>, published.</summary>
    property OnMouseMove;
    /// <summary>Inherited <c>OnMouseUp</c>, published.</summary>
    property OnMouseUp;
    /// <summary>Inherited <c>OnMouseEnter</c>, published.</summary>
    property OnMouseEnter;
    /// <summary>Inherited <c>OnMouseLeave</c>, published.</summary>
    property OnMouseLeave;
    /// <summary>Inherited <c>OnStartDock</c>, published.</summary>
    property OnStartDock;
    /// <summary>Inherited <c>OnStartDrag</c>, published.</summary>
    property OnStartDrag;

    /// <summary>
    ///   Event for handling custom image formats not natively supported.
    /// </summary>
    property OnLoadCustomImage : TLoadCustomImageEvent read FOnLoadCustomImage write FOnLoadCustomImage;

    /// <summary>Inherited <c>NoPicture</c>, published.</summary>
    property NoPicture;
    /// <summary>Inherited <c>OnImageLoaded</c>, published.</summary>
    property OnImageLoaded;
    /// <summary>Inherited <c>OnImageError</c>, published.</summary>
    property OnImageError;
    /// <summary>Inherited <c>OnZoomChanged</c>, published.</summary>
    property OnZoomChanged;
    /// <summary>Inherited <c>OnPanChanged</c>, published.</summary>
    property OnPanChanged;
    /// <summary>Inherited <c>OnRotated</c>, published.</summary>
    property OnRotated;
    /// <summary>Inherited <c>OnFlipped</c>, published.</summary>
    property OnFlipped;
  end;

implementation

uses
  System.Types, System.IOUtils;

type
  /// <summary>Cancellation flag shared between a TgllDBImage and the completion of its async load.</summary>
  IgllImageLoadToken = interface
    ['{6E0F3C41-8B52-4D7A-9E21-3A5C7F0B1D94}']
    /// <summary>Reports whether the load was abandoned.</summary>
    /// <returns>True once Cancel has been called.</returns>
    function GetCancelled : Boolean;
    /// <summary>Abandons the load; its result will be discarded.</summary>
    procedure Cancel;
    /// <summary>True once the load has been abandoned.</summary>
    property Cancelled : Boolean read GetCancelled;
  end;

  /// <summary>Reference-counted implementation of IgllImageLoadToken; outlives the control if need be.</summary>
  TgllImageLoadToken = class( TInterfacedObject, IgllImageLoadToken )
  private
    /// <summary>Set by Cancel. Read and written on the main thread only.</summary>
    FCancelled : Boolean;
  public
    /// <summary>Reports whether the load was abandoned.</summary>
    /// <returns>True once Cancel has been called.</returns>
    function GetCancelled : Boolean;
    /// <summary>Abandons the load.</summary>
    procedure Cancel;
  end;

function TgllImageLoadToken.GetCancelled : Boolean;
begin

  Result := FCancelled;

end;

procedure TgllImageLoadToken.Cancel;
begin

  FCancelled := True;

end;

constructor TgllDBImage.Create( AOwner : TComponent );
begin

  inherited Create( AOwner );

  FAutoDisplay  := True;
  FAsyncLoading := False;

  FMemoria := TMemoryStream.Create;

  FDataLink              := TFieldDataLink.Create;
  FDataLink.Control      := Self;
  FDataLink.OnDataChange := DataChange;
  FDataLink.OnUpdateData := UpdateData;

end;

destructor TgllDBImage.Destroy;
begin

  // GITLAK 2026-09-30: the queued completion of an async load captured Self; cancelling
  // the token makes it free its graphic and return without touching this object.
  CancelAsyncLoad;
  FDataLink.Free;
  FDataLink := nil;
  FMemoria.Free;

  inherited Destroy;

end;

function TgllDBImage.CanModify : Boolean;
begin

  Result := FDataLink.Edit;

end;

procedure TgllDBImage.PictureModified;
begin

  if Assigned( FDataLink ) then
    FDataLink.Modified;

end;

function TgllDBImage.LoadPaintCopy( APicture : TPicture ) : Boolean;
begin

  Result := Assigned( FDataLink.Field ) and FDataLink.Field.IsBlob;

  if Result then
    LoadPictureEx( FMemoria, APicture, FDataLink.Field, FOnLoadCustomImage, False );

end;

function TgllDBImage.SaveDragOutFile( const AFolder : string ) : string;
begin

  if ( not Assigned( FDataLink.Field ) ) or ( not FDataLink.Field.IsBlob ) then
    Exit( inherited SaveDragOutFile( AFolder ) );

  // A rotation or flip not yet posted lives only in Picture: write it to the field exactly as Post would.
  if FDataLink.Editing then
    FDataLink.UpdateRecord;

  if FDataLink.Field.IsNull then
    Exit( '' );

  var lMs := TMemoryStream.Create;

  try
    ( FDataLink.Field as TBlobField ).SaveToStream( lMs );
    StripLegacyGraphicHeader( lMs );

    var lClass := DetectImageFormat( lMs );

    if lClass = nil then
      Exit( inherited SaveDragOutFile( AFolder ) );

    Result := TPath.Combine( AFolder, DragOutBaseName + GraphicClassExtension( lClass ) );
    lMs.SaveToFile( Result );
  finally
    lMs.Free;
  end;

end;

function TgllDBImage.GetPlaceholderCaption : string;
begin

  if FDataLink.Field <> nil then
    Result := FDataLink.Field.DisplayLabel
  else
    Result := Name;

end;

procedure TgllDBImage.KeyPress( var Key : Char );
begin

  inherited KeyPress( Key );

  case Key of
    #13 : LoadPicture;
    #27 : FDataLink.Reset;
  end;

end;

procedure TgllDBImage.CMExit( var Message : TCMExit );
begin

  try

    if Assigned( DataSource ) and Assigned( DataSource.DataSet ) and
       ( DataSource.DataSet.State in [ dsInsert, dsEdit ] ) then
      FDataLink.UpdateRecord;
  except
    SetFocus;
    raise;
  end;

  inherited;

end;

procedure TgllDBImage.LoadPictureAsync;
begin

  if FAsyncLoading then
    Exit;

  if ( not Assigned( FDataLink.Field ) ) or ( not FDataLink.Field.IsBlob ) then
  begin
    LoadPicture;
    Exit;
  end;

  FAsyncLoading := True;
  FLastError    := '';

  // GITLAK 2026-09-30: each load carries a token. The completion runs later on the main
  // thread; if the control was destroyed meanwhile (use-after-free) or the record moved
  // on (the old image would land on the new record, and the next Post would write it),
  // the token is cancelled and the result is discarded without touching Self.
  var lToken : IgllImageLoadToken := TgllImageLoadToken.Create;
  FAsyncToken := lToken;

  FAsyncFuture := gllImage.Utils.LoadPictureAsync( FDataLink.Field,
    procedure( Graphic : TGraphic; const ErrorMsg : string )
    begin

      if lToken.Cancelled then
      begin
        Graphic.Free;
        Exit;
      end;

      FAsyncLoading := False;
      FAsyncToken   := nil;

      if ( Graphic <> nil ) then
      begin
        try
          FPicture.Assign( Graphic );
        finally
          Graphic.Free;
        end;
      end
      else if ( ErrorMsg <> '' ) then
      begin
        FLastError := ErrorMsg;

        DoImageError;
      end;

      Invalidate;

    end );

end;

procedure TgllDBImage.CancelAsyncLoad;
begin

  if Assigned( FAsyncToken ) then
    ( FAsyncToken as IgllImageLoadToken ).Cancel;

  FAsyncToken   := nil;
  FAsyncLoading := False;

end;

function TgllDBImage.GetDataSource : TDataSource;
begin

  Result := FDataLink.DataSource;

end;

procedure TgllDBImage.SetDataSource( Value : TDataSource );
begin

  if ( not ( FDataLink.DataSourceFixed and ( csLoading in ComponentState ) ) ) then
    FDataLink.DataSource := Value;

  if ( Value <> nil ) then
    Value.FreeNotification( Self );

end;

function TgllDBImage.GetDataField : string;
begin

  Result := FDataLink.FieldName;

end;

procedure TgllDBImage.SetDataField( const Value : string );
begin

  FDataLink.FieldName := Value;

end;

function TgllDBImage.GetReadOnly : Boolean;
begin

  Result := FDataLink.ReadOnly;

end;

procedure TgllDBImage.SetReadOnly( Value : Boolean );
begin

  FDataLink.ReadOnly := Value;

end;

function TgllDBImage.GetField : TField;
begin

  Result := FDataLink.Field;

end;

procedure TgllDBImage.SetAutoDisplay( Value : Boolean );
begin

  if FAutoDisplay <> Value then
  begin
    FAutoDisplay := Value;

    if Value then
      LoadPicture;
  end;

end;

procedure TgllDBImage.Notification( AComponent : TComponent; Operation : TOperation );
begin

  inherited Notification( AComponent, Operation );

  if ( Operation = opRemove ) and ( FDataLink <> nil ) and ( AComponent = DataSource ) then
    DataSource := nil;

end;

procedure TgllDBImage.LoadPicture;
begin

  if ( not FPictureLoaded ) and ( ( not Assigned( FDataLink.Field ) ) or FDataLink.Field.IsBlob ) then
  begin
    FLastError := '';

    // GITLAK 2026-09-30: the reporting overload. The procedure overload discards the
    // message, and LoadPictureEx reports failures through it rather than by raising, so
    // OnImageError and LastError never fired for an unreadable image. An unbound control
    // (no field) is not an error.
    var lError := '';
    try
      if ( not LoadPictureEx( FMemoria, Picture, FDataLink.Field, FOnLoadCustomImage, FPictureLoaded, lError ) ) and
         Assigned( FDataLink.Field ) and ( lError <> '' ) then
      begin
        FLastError := lError;

        DoImageError;
      end;
    except
      on E : Exception do
      begin
        FLastError := E.Message;

        DoImageError;
      end;
    end;
  end;

end;

procedure TgllDBImage.DataChange( Sender : TObject );
begin

  // GITLAK 2026-09-30: the record changed, so a load still in flight is for the old row.
  CancelAsyncLoad;

  if Assigned( FPicture ) then
    FPicture.Graphic := nil;

  FPictureLoaded := False;
  FPictureValid  := False;
  FLastError     := '';
  FRotation      := ro0;
  FPanOffset     := Point( 0, 0 );

  StopAnimation;

  if FAutoDisplay and ( csLoading not in ComponentState ) then
    LoadPicture;

end;

procedure TgllDBImage.UpdateData( Sender : TObject );
begin

  if ( not Assigned( FDataLink.Field ) ) or ( not FDataLink.Field.IsBlob ) then
    Exit;

  if ( Picture.Graphic = nil ) or Picture.Graphic.Empty then
  begin
    FDataLink.Field.Clear;
    Exit;
  end;

  var lMs := TMemoryStream.Create;

  try
    Picture.Graphic.SaveToStream( lMs );
    lMs.Position := 0;
    ( FDataLink.Field as TBlobField ).LoadFromStream( lMs );
  finally
    lMs.Free;
  end;

end;

procedure TgllDBImage.CMGetDataLink( var Message : TMessage );
begin

  Message.Result := NativeInt( FDataLink );

end;

procedure TgllDBImage.WMLButtonDblClk( var Message : TWMLButtonDblClk );
begin

  LoadPicture;
  inherited;

end;

procedure TgllDBImage.WMUndo( var Message : TMessage );
begin

  FDataLink.Reset;

end;

function TgllDBImage.ExecuteAction( Action : TBasicAction ) : Boolean;
begin

  Result := inherited ExecuteAction( Action ) or ( ( FDataLink <> nil ) and FDataLink.ExecuteAction( Action ) );

end;

function TgllDBImage.UpdateAction( Action : TBasicAction ) : Boolean;
begin

  Result := inherited UpdateAction( Action ) or ( ( FDataLink <> nil ) and FDataLink.UpdateAction( Action ) );

end;

procedure TgllDBImage.LoadFromFile( const FileName : string );
begin

  if ( not Assigned( FDataLink.Field ) ) then
  begin
    FLastError := SNoDbFieldLinked;

    DoImageError;

    Invalidate;
    Exit;
  end;

  if ( not FDataLink.Field.IsBlob ) then
  begin
    FLastError := SFieldNotBlobEDB;

    DoImageError;

    Invalidate;
    Exit;
  end;

  if ( not FDataLink.Edit ) then
  begin
    FLastError := SCannotEditRecord;

    DoImageError;

    Invalidate;
    Exit;
  end;

  try
    // GITLAK 2026-10-19: the field now holds the file's own bytes, and writing it reloads the picture through
    // DataChange. It used to call PictureChanged here as well, which marked the record modified, so on Post
    // UpdateData replaced those bytes with Picture.Graphic re-encoded: a lossy second generation for JPEG XL, and
    // a re-compressed PNG.
    ( FDataLink.Field as TBlobField ).LoadFromFile( FileName );
    FLastError := '';
  except
    on E : Exception do
    begin
      FLastError := E.Message;

      DoImageError;

      Invalidate;
    end;
  end;

end;

initialization

  // GITLAK 2026-10-19: the class was TGDBImage in GITLAKDB; a form still naming it streams in as TgllDBImage.
  RegisterClassAlias( TgllDBImage, 'TGDBImage' );

end.
