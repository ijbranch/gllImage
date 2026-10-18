(* Copyright (c) 2026 Ian Branch. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style
 * license that can be found in the LICENSE file.
 *)
(*
  gllImage.View - Image viewer controls
  Version: 4.0

  Original Copyright (c) 2000-2025 Sebastián Mayorá, Argentina
  Original Author: Sebastián Mayorá (DelphiHelper@yahoo.com.ar)
  Further developed by Roy Lambert (EDBImage).

  Original licence: Freeware - Use at your own risk.  gllImage: BSD 3-Clause
  (see the LICENSE file).

  Description:
    TgllCustomImageView holds everything a picture viewer does: scaling (shrink, zoom and fit to the window), zoom
    with the mouse wheel and keyboard, pan, display rotation and flip, animated GIF playback, a checkerboard behind
    transparent images, the error state, clipboard, drag and drop of image files, print, thumbnails, save to file and
    the built-in context menu.

    TgllImageView publishes it as a stand-alone control (the TImage counterpart). The data-aware TgllDBImage
    (gllImage.DB) descends from the same base, so the two never drift apart.

  Version 4.0 (GITLAK 2026-10-19):
    - Split out of gdbximage (GITLAKDB) into the gllImage project: the viewer moved into this base class, and
      TgllDBImage keeps only the data link.
*)

unit gllImage.View;

{$D-}

interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.ShellAPI, Winapi.ActiveX,
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Math,
  System.Generics.Collections,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Menus, Vcl.Dialogs,
  Vcl.ExtCtrls, Vcl.Printers, Vcl.Imaging.GIFImg,

  gllImage.Consts,
  gllImage.Utils;

type
  /// <summary>Raised when image files are dropped on the control (EnableDragDrop).</summary>
  /// <param name="Sender">The control.</param>
  /// <param name="FileNames">Every dropped file, in the order Windows reports them.</param>
  /// <param name="Handled">Set True when the handler dealt with the drop; left False, the control loads the first
  /// supported file itself.</param>
  TFilesDroppedEvent = procedure( Sender : TObject; const FileNames : TArray<string>; var Handled : Boolean ) of object;

  /// <summary>
  ///   Base class of the gllImage picture viewers: everything except where the picture comes from.
  /// </summary>
  /// <remarks>
  ///   Provides automatic image scaling, clipboard operations, drag and drop, mouse wheel zoom, rotation, flip,
  ///   pan, print support, animated GIF playback, and support for multiple image formats including JPEG, PNG, BMP,
  ///   GIF, ICO, WMF, EMF, and optionally TIFF via GraphicEx. A descendant decides where the picture comes from and
  ///   whether it may be changed, through CanModify, GetReadOnly / SetReadOnly, PictureModified, LoadPaintCopy,
  ///   GetPlaceholderCaption and LoadFromFile.
  /// </remarks>
  TgllCustomImageView = class( TCustomControl )
  private
    /// <summary>Border drawn round the control.</summary>
    FBorderStyle        : TBorderStyle;
    /// <summary>When True images larger than the control are scaled down to fit.</summary>
    FShrinkToFit        : Boolean;
    /// <summary>When True the picture is centred in the control.</summary>
    FCenter             : Boolean;
    /// <summary>When True palettised images are drawn without palette realisation.</summary>
    FQuickDraw          : Boolean;
    /// <summary>When True images smaller than the control are scaled up to fit.</summary>
    FZoomToFit          : Boolean;
    /// <summary>Text shown when there is no picture.</summary>
    FNoPicture          : string;
    /// <summary>When True scaling keeps the image's aspect ratio.</summary>
    FMaintainAspectRatio: Boolean;
    /// <summary>How transparent areas are drawn.</summary>
    FTransparentMode    : TTransparentMode;
    /// <summary>Checkerboard square size, in pixels.</summary>
    FCheckerSize        : Integer;
    /// <summary>First checkerboard colour.</summary>
    FCheckerColour1     : TColor;
    /// <summary>Second checkerboard colour.</summary>
    FCheckerColour2     : TColor;
    /// <summary>When True the mouse wheel zooms.</summary>
    FEnableMouseWheel   : Boolean;
    /// <summary>Current zoom; 1.0 is 100%.</summary>
    FZoomFactor         : Double;
    /// <summary>Smallest zoom allowed.</summary>
    FMinZoom            : Double;
    /// <summary>Largest zoom allowed.</summary>
    FMaxZoom            : Double;
    /// <summary>When True image files may be dropped on the control.</summary>
    FEnableDragDrop     : Boolean;
    /// <summary>When True a load failure is drawn in the control.</summary>
    FShowErrorState     : Boolean;
    /// <summary>When True the picture cannot be changed through the control (the stand-alone viewer's own flag;
    /// TgllDBImage uses its data link's instead).</summary>
    FReadOnly           : Boolean;
    /// <summary>The built-in context menu; owned.</summary>
    FContextMenu        : TPopupMenu;
    /// <summary>Raised after an image loads.</summary>
    FOnImageLoaded      : TNotifyEvent;
    /// <summary>Raised after an image fails to load.</summary>
    FOnImageError       : TNotifyEvent;
    /// <summary>Raised when the zoom changes.</summary>
    FOnZoomChanged      : TNotifyEvent;
    /// <summary>Raised when the pan offset changes.</summary>
    FOnPanChanged       : TNotifyEvent;
    /// <summary>Raised after a rotation.</summary>
    FOnRotated          : TNotifyEvent;
    /// <summary>Raised after a flip.</summary>
    FOnFlipped          : TNotifyEvent;
    /// <summary>Context-menu item: Copy.</summary>
    FMenuItemCopy       : TMenuItem;
    /// <summary>Context-menu item: Cut.</summary>
    FMenuItemCut        : TMenuItem;
    /// <summary>Context-menu item: Paste.</summary>
    FMenuItemPaste      : TMenuItem;
    /// <summary>Context-menu item: Clear.</summary>
    FMenuItemClear      : TMenuItem;
    /// <summary>Context-menu item: Load from file.</summary>
    FMenuItemLoad       : TMenuItem;
    /// <summary>Context-menu item: Save to file.</summary>
    FMenuItemSave       : TMenuItem;
    /// <summary>Context-menu item: Print.</summary>
    FMenuItemPrint      : TMenuItem;
    /// <summary>Context-menu item: Rotate clockwise.</summary>
    FMenuItemRotateCW   : TMenuItem;
    /// <summary>Context-menu item: Rotate anticlockwise.</summary>
    FMenuItemRotateCCW  : TMenuItem;
    /// <summary>Context-menu item: Flip horizontally.</summary>
    FMenuItemFlipH      : TMenuItem;
    /// <summary>Context-menu item: Flip vertically.</summary>
    FMenuItemFlipV      : TMenuItem;
    /// <summary>Context-menu item: Reset view.</summary>
    FMenuItemResetView  : TMenuItem;
    /// <summary>Context-menu item: Start/stop animation.</summary>
    FMenuItemAnimation  : TMenuItem;
    /// <summary>Cached checkerboard tile; owned.</summary>
    FCheckerTile        : TBitmap;
    /// <summary>True while FCheckerTile matches the checker settings.</summary>
    FCheckerTileValid   : Boolean;
    /// <summary>Largest image width accepted, in pixels; 0 for no limit.</summary>
    FMaxImageWidth      : Integer;
    /// <summary>Largest image height accepted, in pixels; 0 for no limit.</summary>
    FMaxImageHeight     : Integer;
    /// <summary>When True a zoomed image can be dragged.</summary>
    FEnablePan          : Boolean;
    /// <summary>True while a pan drag is in progress.</summary>
    FIsPanning          : Boolean;
    /// <summary>Mouse position where the pan drag started.</summary>
    FPanStartPoint      : TPoint;
    /// <summary>Pan offset when the drag started.</summary>
    FPanStartOffset     : TPoint;
    /// <summary>Drives GIF animation; owned.</summary>
    FAnimationTimer     : TTimer;
    /// <summary>True while a GIF animation runs.</summary>
    FIsAnimating        : Boolean;
    /// <summary>True while PictureChanged clears an oversized picture, so the re-entrant change is ignored.</summary>
    FClearingOversize   : Boolean;
    /// <summary>When True scroll bars appear while the picture is larger than the control.</summary>
    FScrollBars         : Boolean;
    /// <summary>True while UpdateScrollBars runs, so the WM_SIZE that showing a bar causes does not re-enter it.</summary>
    FUpdatingScrollBars : Boolean;
    /// <summary>When True a right-click shows the built-in context menu (when no PopupMenu is assigned).</summary>
    FShowContextMenu    : Boolean;
    /// <summary>Raised when image files are dropped on the control.</summary>
    FOnFilesDropped     : TFilesDroppedEvent;
    /// <summary>The OLE drop target registered for the window; nil while none is registered.</summary>
    FDropTarget         : IDropTarget;
    /// <summary>True once OleInitialize succeeded for this control, so Destroy balances it.</summary>
    FOleInitialised     : Boolean;
    /// <summary>When True the picture can be dragged out of the control as a file.</summary>
    FEnableDragOut      : Boolean;
    /// <summary>File name (without extension) of a picture dragged out; empty for the default.</summary>
    FDragOutFileName    : string;
    /// <summary>True between a left-button press that may start a drag-out and the move that starts it.</summary>
    FDragOutPending     : Boolean;
    /// <summary>Where the press that may start a drag-out was made.</summary>
    FDragOutStart       : TPoint;
    /// <summary>True while a drag-out runs, so the control does not take its own picture back.</summary>
    FDraggingOut        : Boolean;
    /// <summary>Temporary folder holding the file of the last drag-out; deleted at the next drag and in Destroy.</summary>
    FDragOutFolder      : string;
    /// <summary>TDBImage-compatible Stretch, as last set (see SetStretch).</summary>
    FStretch            : Boolean;
    /// <summary>TDBImage-compatible Proportional, as last set (see SetStretch).</summary>
    FProportional       : Boolean;
    /// <summary>Save routines keyed by file extension.</summary>
    FSaveFormatHandlers : TDictionary<string, TSaveFormatHandler>;

    /// <summary>Getter for ImageWidth.</summary>
    /// <returns>The picture width in pixels, or 0.</returns>
    function GetImageWidth : Integer;
    /// <summary>Getter for ImageHeight.</summary>
    /// <returns>The picture height in pixels, or 0.</returns>
    function GetImageHeight : Integer;
    /// <summary>Getter for ImageFormat.</summary>
    /// <returns>A short format name, or empty.</returns>
    function GetImageFormat : string;
    /// <summary>Getter for HasImage.</summary>
    /// <returns>True when a non-empty picture is loaded.</returns>
    function GetHasImage : Boolean;
    /// <summary>Getter for CanCopy.</summary>
    /// <returns>True when there is a picture to copy.</returns>
    function GetCanCopy : Boolean;
    /// <summary>Getter for CanCut.</summary>
    /// <returns>True when there is a picture and it can be changed.</returns>
    function GetCanCut : Boolean;
    /// <summary>Getter for CanPaste.</summary>
    /// <returns>True when the clipboard holds a picture and the picture can be changed.</returns>
    function GetCanPaste : Boolean;
    /// <summary>Getter for CanClear.</summary>
    /// <returns>True when there is a picture and it can be changed.</returns>
    function GetCanClear : Boolean;
    /// <summary>Getter for ImageSize.</summary>
    /// <returns>The picture size in pixels.</returns>
    function GetImageSize : TSize;
    /// <summary>Getter for FitToWindow.</summary>
    /// <returns>True when both ShrinkToFit and ZoomToFit are on.</returns>
    function GetFitToWindow : Boolean;
    /// <summary>Getter for IsAnimatedGIF.</summary>
    /// <returns>True when the picture is a GIF with more than one frame.</returns>
    function GetIsAnimatedGIF : Boolean;
    /// <summary>Setter for FitToWindow; sets ShrinkToFit and ZoomToFit together.</summary>
    /// <param name="Value">The new value.</param>
    procedure SetFitToWindow( const Value : Boolean );
    /// <summary>Setter for BorderStyle.</summary>
    /// <param name="Value">The new value.</param>
    procedure SetBorderStyle( Value : TBorderStyle );
    /// <summary>Setter for Center.</summary>
    /// <param name="Value">The new value.</param>
    procedure SetCenter( Value : Boolean );
    /// <summary>Setter for Picture.</summary>
    /// <param name="Value">The new value.</param>
    procedure SetPicture( Value : TPicture );
    /// <summary>Setter for ShrinkToFit.</summary>
    /// <param name="Value">The new value.</param>
    procedure SetShrinkToFit( Value : Boolean );
    /// <summary>Setter for ZoomToFit.</summary>
    /// <param name="Value">The new value.</param>
    procedure SetZoomToFit( const Value : Boolean );
    /// <summary>Setter for MaintainAspectRatio.</summary>
    /// <param name="Value">The new value.</param>
    procedure SetMaintainAspectRatio( const Value : Boolean );
    /// <summary>Setter for TransparentMode.</summary>
    /// <param name="Value">The new value.</param>
    procedure SetTransparentMode( const Value : TTransparentMode );
    /// <summary>Setter for CheckerSize.</summary>
    /// <param name="Value">The new value.</param>
    procedure SetCheckerSize( const Value : Integer );
    /// <summary>Setter for CheckerColour1.</summary>
    /// <param name="Value">The new value.</param>
    procedure SetCheckerColour1( const Value : TColor );
    /// <summary>Setter for CheckerColour2.</summary>
    /// <param name="Value">The new value.</param>
    procedure SetCheckerColour2( const Value : TColor );
    /// <summary>Initialises OLE for this control once (balanced in Destroy).</summary>
    /// <returns>True when OLE is usable on this thread.</returns>
    function EnsureOle : Boolean;
    /// <summary>Registers the window as an OLE drop target, or for WM_DROPFILES when OLE is not available.</summary>
    procedure RegisterDropTarget;
    /// <summary>Revokes whichever drop registration RegisterDropTarget made.</summary>
    procedure RevokeDropTarget;
    /// <summary>True when a left-button drag would drag the picture out now.</summary>
    /// <returns>True when EnableDragOut is on and a loaded picture is shown, outside the designer.</returns>
    function CanDragOut : Boolean;
    /// <summary>Writes the picture to a new temporary folder (SaveDragOutFile) and drags that file out.</summary>
    procedure BeginDragOut;
    /// <summary>Setter for EnableDragDrop; registers or revokes the window as a drop target.</summary>
    /// <param name="Value">The new value.</param>
    procedure SetEnableDragDrop( const Value : Boolean );
    /// <summary>Setter for ZoomFactor; clamps to MinZoom..MaxZoom.</summary>
    /// <param name="Value">The new value.</param>
    procedure SetZoomFactor( const Value : Double );
    /// <summary>Setter for MinZoom.</summary>
    /// <param name="Value">The new value.</param>
    procedure SetMinZoom( const Value : Double );
    /// <summary>Setter for MaxZoom.</summary>
    /// <param name="Value">The new value.</param>
    procedure SetMaxZoom( const Value : Double );
    /// <summary>Setter for EnablePan.</summary>
    /// <param name="Value">The new value.</param>
    procedure SetEnablePan( const Value : Boolean );
    /// <summary>Setter for Rotation; invalidates the drawn picture and resets the pan.</summary>
    /// <param name="Value">The new value.</param>
    procedure SetRotation( const Value : TRotationAngle );
    /// <summary>Builds the built-in context menu.</summary>
    procedure CreateContextMenu;
    /// <summary>Context-menu handler: copy.</summary>
    /// <param name="Sender">The object that raised the event.</param>
    procedure ContextMenuCopy( Sender : TObject );
    /// <summary>Context-menu handler: cut.</summary>
    /// <param name="Sender">The object that raised the event.</param>
    procedure ContextMenuCut( Sender : TObject );
    /// <summary>Context-menu handler: paste.</summary>
    /// <param name="Sender">The object that raised the event.</param>
    procedure ContextMenuPaste( Sender : TObject );
    /// <summary>Context-menu handler: clear.</summary>
    /// <param name="Sender">The object that raised the event.</param>
    procedure ContextMenuClear( Sender : TObject );
    /// <summary>Context-menu handler: load from file.</summary>
    /// <param name="Sender">The object that raised the event.</param>
    procedure ContextMenuLoadFromFile( Sender : TObject );
    /// <summary>Context-menu handler: save to file.</summary>
    /// <param name="Sender">The object that raised the event.</param>
    procedure ContextMenuSaveToFile( Sender : TObject );
    /// <summary>Context-menu handler: print.</summary>
    /// <param name="Sender">The object that raised the event.</param>
    procedure ContextMenuPrint( Sender : TObject );
    /// <summary>Context-menu handler: rotate clockwise.</summary>
    /// <param name="Sender">The object that raised the event.</param>
    procedure ContextMenuRotateCW( Sender : TObject );
    /// <summary>Context-menu handler: rotate anticlockwise.</summary>
    /// <param name="Sender">The object that raised the event.</param>
    procedure ContextMenuRotateCCW( Sender : TObject );
    /// <summary>Context-menu handler: flip horizontally.</summary>
    /// <param name="Sender">The object that raised the event.</param>
    procedure ContextMenuFlipH( Sender : TObject );
    /// <summary>Context-menu handler: flip vertically.</summary>
    /// <param name="Sender">The object that raised the event.</param>
    procedure ContextMenuFlipV( Sender : TObject );
    /// <summary>Context-menu handler: reset view.</summary>
    /// <param name="Sender">The object that raised the event.</param>
    procedure ContextMenuResetView( Sender : TObject );
    /// <summary>Context-menu handler: start or stop the animation.</summary>
    /// <param name="Sender">The object that raised the event.</param>
    procedure ContextMenuToggleAnimation( Sender : TObject );
    /// <summary>Fills a rectangle with the checkerboard pattern.</summary>
    /// <param name="ACanvas">The canvas to draw on.</param>
    /// <param name="ARect">The rectangle to fill.</param>
    procedure DrawCheckerboard( ACanvas : TCanvas; ARect : TRect );
    /// <summary>Draws the load-failure indicator and LastError.</summary>
    /// <param name="ACanvas">The canvas to draw on.</param>
    /// <param name="ARect">The rectangle to fill.</param>
    procedure DrawErrorState( ACanvas : TCanvas; ARect : TRect );
    /// <summary>Registers the built-in save routines by extension.</summary>
    procedure InitialiseSaveHandlers;
    /// <summary>Advances the GIF animation by one frame.</summary>
    /// <param name="Sender">The object that raised the event.</param>
    procedure AnimationTimerTick( Sender : TObject );
    /// <summary>Begins a pan drag.</summary>
    /// <param name="X">Mouse X in client coordinates.</param>
    /// <param name="Y">Mouse Y in client coordinates.</param>
    procedure StartPan( X, Y : Integer );
    /// <summary>Moves the picture during a pan drag.</summary>
    /// <param name="X">Mouse X in client coordinates.</param>
    /// <param name="Y">Mouse Y in client coordinates.</param>
    procedure UpdatePan( X, Y : Integer );
    /// <summary>Ends a pan drag.</summary>
    procedure EndPan;
    /// <summary>Keeps the pan offset within the picture as Paint draws it, and updates the scroll bars.</summary>
    procedure ClampPanOffset;
    /// <summary>The picture's size on screen before any fitting: after the display rotation, at ZoomFactor.</summary>
    /// <returns>The size in pixels; 0 x 0 without a picture.</returns>
    function GetViewImageSize : TSize;
    /// <summary>The client area's size, without creating a window: the bounds until the control has one.</summary>
    /// <returns>The size in pixels.</returns>
    function GetViewClientSize : TSize;
    /// <summary>How far the picture as drawn overhangs the client area on each axis.</summary>
    /// <returns>The overhang in pixels per axis; 0 on an axis that fits, and on both while the picture is fitted to
    /// the window.</returns>
    function GetScrollExcess : TPoint;
    /// <summary>The pan offset at scroll position 0 on an axis.</summary>
    /// <param name="AExcess">The overhang on that axis (GetScrollExcess).</param>
    /// <returns>AExcess div 2 for a centred picture, 0 otherwise.</returns>
    function PanBase( AExcess : Integer ) : Integer;
    /// <summary>Getter for ScrollPosition.</summary>
    /// <returns>The scroll position per axis, 0 at the picture's left / top edge.</returns>
    function GetScrollPosition : TPoint;
    /// <summary>Setter for ScrollBars.</summary>
    /// <param name="Value">The new value.</param>
    procedure SetScrollBars( const Value : Boolean );
    /// <summary>Shows, hides and positions the scroll bars to match the picture and the pan offset.</summary>
    procedure UpdateScrollBars;
    /// <summary>True while the picture is scaled to the control (ShrinkToFit / ZoomToFit apply): Paint then draws it
    /// fitted, and there is nothing to pan or scroll.</summary>
    /// <returns>True when the picture is being fitted.</returns>
    function GetIsFitted : Boolean;
    /// <summary>The scale a fitted picture is drawn at: the largest that fits the client area with the aspect kept.
    /// </summary>
    /// <returns>The scale; 1.0 without a picture.</returns>
    function GetFittedScale : Double;
    /// <summary>Turns fitting off and takes the fitted scale as the zoom, so a zoom step continues from what is
    /// shown instead of jumping to the old ZoomFactor.</summary>
    procedure LeaveFitMode;
    /// <summary>Setter for Stretch: TDBImage's Stretch / Proportional mapped onto ShrinkToFit, ZoomToFit and
    /// MaintainAspectRatio.</summary>
    /// <param name="Value">The new value.</param>
    procedure SetStretch( const Value : Boolean );
    /// <summary>Setter for Proportional (see SetStretch).</summary>
    /// <param name="Value">The new value.</param>
    procedure SetProportional( const Value : Boolean );
    /// <summary>Applies FStretch / FProportional to the fit properties, as TDBImage draws them.</summary>
    procedure ApplyStretchMode;
    /// <summary>Scrolls one axis for a scroll-bar message.</summary>
    /// <param name="ABar">SB_HORZ or SB_VERT.</param>
    /// <param name="ACode">The SB_* scroll code of the message.</param>
    procedure ScrollAxis( ABar, ACode : Integer );
    /// <summary>Scrolls horizontally from the scroll bar.</summary>
    /// <param name="Message">The window message.</param>
    procedure WMHScroll( var Message : TWMHScroll ); message WM_HSCROLL;
    /// <summary>Scrolls vertically from the scroll bar.</summary>
    /// <param name="Message">The window message.</param>
    procedure WMVScroll( var Message : TWMVScroll ); message WM_VSCROLL;
    /// <summary>Repaints the focus frame on entry.</summary>
    /// <param name="Message">The window message.</param>
    procedure CMEnter( var Message : TCMEnter ); message CM_ENTER;
    /// <summary>Repaints the focus frame on exit.</summary>
    /// <param name="Message">The window message.</param>
    procedure CMExit( var Message : TCMExit ); message CM_EXIT;
    /// <summary>Repaints the placeholder text when the caption changes and no picture is loaded.</summary>
    /// <param name="Message">The window message.</param>
    procedure CMTextChanged( var Message : TMessage ); message CM_TEXTCHANGED;
    /// <summary>Takes focus and starts a pan drag when panning is possible.</summary>
    /// <param name="Message">The window message.</param>
    procedure WMLButtonDown( var Message : TWMLButtonDown ); message WM_LBUTTONDOWN;
    /// <summary>Ends a pan drag.</summary>
    /// <param name="Message">The window message.</param>
    procedure WMLButtonUp( var Message : TWMLButtonUp ); message WM_LBUTTONUP;
    /// <summary>Moves the picture during a pan drag.</summary>
    /// <param name="Message">The window message.</param>
    procedure WMMouseMove( var Message : TWMMouseMove ); message WM_MOUSEMOVE;
    /// <summary>Handles WM_CUT.</summary>
    /// <param name="Message">The window message.</param>
    procedure WMCut( var Message : TMessage ); message WM_CUT;
    /// <summary>Handles WM_COPY.</summary>
    /// <param name="Message">The window message.</param>
    procedure WMCopy( var Message : TMessage ); message WM_COPY;
    /// <summary>Handles WM_PASTE.</summary>
    /// <param name="Message">The window message.</param>
    procedure WMPaste( var Message : TMessage ); message WM_PASTE;
    /// <summary>Clamps the pan offset and repaints after a resize.</summary>
    /// <param name="Message">The window message.</param>
    procedure WMSize( var Message : TMessage ); message WM_SIZE;
    /// <summary>Handles WM_CLEAR.</summary>
    /// <param name="Message">The window message.</param>
    procedure WMClear( var Message : TMessage ); message WM_CLEAR;
    /// <summary>Loads a dropped image file.</summary>
    /// <param name="Message">The window message.</param>
    procedure WMDropFiles( var Message : TWMDropFiles ); message WM_DROPFILES;
    /// <summary>Shows the built-in context menu unless a PopupMenu is assigned.</summary>
    /// <param name="Message">The window message.</param>
    procedure WMContextMenu( var Message : TWMContextMenu ); message WM_CONTEXTMENU;

  protected
    /// <summary>The picture shown; owned.</summary>
    FPicture            : TPicture;
    /// <summary>The picture actually drawn: a copy of FPicture after rotation, rebuilt when FPictureValid is False.</summary>
    FDrawPict           : TPicture;
    /// <summary>True once the picture has been loaded (or assigned). TgllDBImage clears it on every record change and
    /// draws its placeholder until the next load.</summary>
    FPictureLoaded      : Boolean;
    /// <summary>True while FDrawPict matches FPicture and the current rotation.</summary>
    FPictureValid       : Boolean;
    /// <summary>Message of the last failure; empty after a successful load.</summary>
    FLastError          : string;
    /// <summary>Current pan offset, in pixels.</summary>
    FPanOffset          : TPoint;
    /// <summary>Current rotation.</summary>
    FRotation           : TRotationAngle;

    /// <summary>Adds the border style to the window parameters.</summary>
    /// <param name="Params">The window creation parameters.</param>
    procedure CreateParams( var Params : TCreateParams ); override;
    /// <summary>Registers the window for drag and drop after it is created.</summary>
    procedure CreateWnd; override;
    /// <summary>Revokes drag and drop before the window is destroyed.</summary>
    procedure DestroyWnd; override;
    /// <summary>Creates the built-in context menu after streaming, outside the designer.</summary>
    procedure Loaded; override;
    /// <summary>Returns the picture's palette for the VCL to realise.</summary>
    /// <returns>The picture's palette, or 0.</returns>
    function GetPalette : HPALETTE; override;
    /// <summary>Zooms with the mouse wheel when EnableMouseWheel is on.</summary>
    /// <param name="Shift">The modifier keys held.</param>
    /// <param name="WheelDelta">The wheel movement.</param>
    /// <param name="MousePos">The mouse position.</param>
    /// <returns>True when the wheel was handled.</returns>
    function DoMouseWheel( Shift : TShiftState; WheelDelta : Integer; MousePos : TPoint ) : Boolean; override;
    /// <summary>Handles Shift/Ctrl+Insert and Shift/Ctrl+Delete clipboard keys and the Ctrl zoom, reset and rotate shortcuts.</summary>
    /// <param name="Key">The key; set to 0 when handled.</param>
    /// <param name="Shift">The modifier keys held.</param>
    procedure KeyDown( var Key : Word; Shift : TShiftState ); override;
    /// <summary>Handles Ctrl+X/C/V/Z.</summary>
    /// <param name="Key">The key; set to 0 when handled.</param>
    procedure KeyPress( var Key : Char ); override;
    /// <summary>Draws the picture, the placeholder text or the error state.</summary>
    procedure Paint; override;

    /// <summary>Asks whether the picture may be changed now, and prepares for the change.</summary>
    /// <remarks>Called before every change made through the control (clear, cut, paste, flip, load from file).
    /// The stand-alone viewer answers from ReadOnly; TgllDBImage puts its dataset into edit mode.</remarks>
    /// <returns>True when the change may go ahead.</returns>
    function CanModify : Boolean; virtual;
    /// <summary>Getter for ReadOnly.</summary>
    /// <returns>True when the picture cannot be changed through the control.</returns>
    function GetReadOnly : Boolean; virtual;
    /// <summary>Setter for ReadOnly.</summary>
    /// <param name="Value">The new value.</param>
    procedure SetReadOnly( Value : Boolean ); virtual;
    /// <summary>Reports that the loaded picture was changed through the control. Does nothing here; TgllDBImage marks
    /// its record modified.</summary>
    procedure PictureModified; virtual;
    /// <summary>Loads the picture for a paint copy (a TDBCtrlGrid row) into APicture. Not supported here.</summary>
    /// <param name="APicture">The picture to load into.</param>
    /// <returns>True when APicture was loaded; False to paint the control's own picture.</returns>
    function LoadPaintCopy( APicture : TPicture ) : Boolean; virtual;
    /// <summary>The caption drawn, in brackets, while no picture has been loaded.</summary>
    /// <returns>The control's Name here; TgllDBImage returns its field's DisplayLabel.</returns>
    function GetPlaceholderCaption : string; virtual;
    /// <summary>Raises OnImageError. The caller sets FLastError first.</summary>
    procedure DoImageError;
    /// <summary>Handles a change to Picture: enforces the size limits and reports the change through
    /// PictureModified.</summary>
    /// <param name="Sender">The object that raised the event.</param>
    procedure PictureChanged( Sender : TObject );
    /// <summary>Asks whether files dragged over the control would be taken now.</summary>
    /// <returns>True when EnableDragDrop is on, the control is enabled and not read-only, and it is not dragging its
    /// own picture out.</returns>
    function CanAcceptDrop : Boolean; virtual;
    /// <summary>Takes dropped files, from an OLE drop or WM_DROPFILES: OnFilesDropped sees them first; left
    /// unhandled, the first one is loaded when its extension is supported, otherwise LastError and OnImageError
    /// report it.</summary>
    /// <remarks>The temporary copy of a virtual file (an e-mail attachment, an image from a browser) exists only for
    /// the length of this call.</remarks>
    /// <param name="AFileNames">The dropped files.</param>
    procedure HandleDroppedFiles( const AFileNames : TArray<string> ); virtual;
    /// <summary>Writes the picture to a file in AFolder for a drag-out.</summary>
    /// <remarks>Here the picture's own SaveToFile, so it keeps its format; TgllDBImage writes the field's bytes.</remarks>
    /// <param name="AFolder">An existing, empty temporary folder.</param>
    /// <returns>The file written, or an empty string when there is nothing to drag.</returns>
    function SaveDragOutFile( const AFolder : string ) : string; virtual;
    /// <summary>The name, without extension, a dragged-out picture's file is given: DragOutFileName made safe, or
    /// SDragOutDefaultName.</summary>
    /// <returns>The file name without extension.</returns>
    function DragOutBaseName : string;

  public
    /// <summary>Creates the component, initialising defaults, picture buffers, animation timer and save handlers.</summary>
    /// <param name="AOwner">The owning component.</param>
    constructor Create( AOwner : TComponent ); override;

    /// <summary>Destroys the component, stopping animation and freeing all owned resources.</summary>
    destructor Destroy; override;

    /// <summary>
    ///   Copies the current picture to the clipboard.
    /// </summary>
    procedure CopyToClipboard;

    /// <summary>
    ///   Cuts the current picture to the clipboard.
    /// </summary>
    procedure CutToClipboard;

    /// <summary>
    ///   Pastes an image from the clipboard into the component.
    /// </summary>
    procedure PasteFromClipboard;

    /// <summary>
    ///   Loads an image from a file into the picture.
    /// </summary>
    /// <remarks>A failure is reported through LastError and OnImageError, not raised.</remarks>
    /// <param name="FileName">The path to the image file.</param>
    procedure LoadFromFile( const FileName : string ); virtual;

    /// <summary>
    ///   Saves the current image to a file.
    /// </summary>
    /// <param name="FileName">The destination file path.</param>
    procedure SaveToFile( const FileName : string );

    /// <summary>
    ///   Resets the zoom factor to 100%.
    /// </summary>
    procedure ResetZoom;

    /// <summary>
    ///   Zooms in by 10%.
    /// </summary>
    procedure ZoomIn;

    /// <summary>
    ///   Zooms out by 10%.
    /// </summary>
    procedure ZoomOut;

    /// <summary>
    ///   Multiplies the zoom by AFactor (1.25 zooms in a quarter, 0.8 back out).
    /// </summary>
    /// <remarks>Like ZoomIn and ZoomOut, a fitted picture first leaves fit mode at the scale it is shown at, so the
    /// step continues from what is on screen.</remarks>
    /// <param name="AFactor">The factor; the result is kept within MinZoom..MaxZoom.</param>
    procedure ZoomBy( const AFactor : Double );

    /// <summary>
    ///   Clears the last error message.
    /// </summary>
    procedure ClearError;

    /// <summary>
    ///   Rotates the image clockwise by 90 degrees.
    /// </summary>
    /// <example>
    ///   <code>
    ///   gllImage1.RotateClockwise;
    ///   </code>
    /// </example>
    procedure RotateClockwise;

    /// <summary>
    ///   Rotates the image counter-clockwise by 90 degrees.
    /// </summary>
    procedure RotateCounterClockwise;

    /// <summary>
    ///   Rotates the image by the specified angle.
    /// </summary>
    /// <param name="Angle">The rotation angle (ro0, ro90, ro180, ro270).</param>
    procedure Rotate( Angle : TRotationAngle );

    /// <summary>
    ///   Rotates the picture itself (not just the display) and keeps its format, so a JPEG, PNG, GIF or JPEG XL is
    ///   still one afterwards; TgllDBImage writes it to its field on the next Post.
    /// </summary>
    /// <remarks>Turns the picture AS SEEN: a display Rotation already applied (for example from an EXIF orientation)
    /// is baked in too, and the display rotation returns to ro0. Unlike Rotate, which only turns the display, this
    /// changes the pixels: the image is re-encoded once. Does nothing without a picture or when the picture cannot be
    /// changed (ReadOnly).</remarks>
    /// <param name="Angle">The further rotation, clockwise; ro0 bakes in just the display rotation.</param>
    procedure RotatePicture( Angle : TRotationAngle );

    /// <summary>
    ///   Flips the image horizontally.
    /// </summary>
    procedure FlipHorizontal;

    /// <summary>
    ///   Flips the image vertically.
    /// </summary>
    procedure FlipVertical;

    /// <summary>
    ///   Resets the view to default (zoom 100%, no pan, no rotation).
    /// </summary>
    procedure ResetView;

    /// <summary>
    ///   Moves the picture by DX, DY pixels within the limits a drag or the scroll bars have.
    /// </summary>
    /// <remarks>Positive values move the picture right and down (the view up and left). Raises OnPanChanged when the
    /// offset changes.</remarks>
    /// <param name="DX">Horizontal movement in pixels.</param>
    /// <param name="DY">Vertical movement in pixels.</param>
    procedure PanBy( DX, DY : Integer );

    /// <summary>
    ///   Prints the current image.
    /// </summary>
    /// <param name="FitToPage">Whether to scale the image to fit the page.</param>
    /// <param name="CentreOnPage">Whether to centre the image on the page.</param>
    /// <example>
    ///   <code>
    ///   gllImage1.Print( True, True );
    ///   </code>
    /// </example>
    procedure Print( FitToPage : Boolean = True; CentreOnPage : Boolean = True );

    /// <summary>
    ///   Creates a thumbnail of the current image.
    /// </summary>
    /// <param name="MaxWidth">Maximum thumbnail width.</param>
    /// <param name="MaxHeight">Maximum thumbnail height.</param>
    /// <returns>A new bitmap containing the thumbnail. Caller must free.</returns>
    /// <example>
    ///   <code>
    ///   var thumb := gllImage1.GetThumbnail( 100, 100 );
    ///   try
    ///     Image1.Picture.Bitmap := thumb;
    ///   finally
    ///     thumb.Free;
    ///   end;
    ///   </code>
    /// </example>
    function GetThumbnail( MaxWidth, MaxHeight : Integer ) : TBitmap;

    /// <summary>
    ///   Starts animated GIF playback.
    /// </summary>
    procedure StartAnimation;

    /// <summary>
    ///   Stops animated GIF playback.
    /// </summary>
    procedure StopAnimation;

    /// <summary>
    ///   Registers a custom save format handler.
    /// </summary>
    /// <param name="Extension">The file extension (e.g., '.webp').</param>
    /// <param name="Handler">The save handler procedure.</param>
    procedure RegisterSaveFormat( const Extension : string; Handler : TSaveFormatHandler );

    /// <summary>
    ///   The picture displayed in the component.
    /// </summary>
    property Picture : TPicture read FPicture write SetPicture;

    /// <summary>
    ///   Width of the loaded image in pixels.
    /// </summary>
    property ImageWidth : Integer read GetImageWidth;

    /// <summary>
    ///   Height of the loaded image in pixels.
    /// </summary>
    property ImageHeight : Integer read GetImageHeight;

    /// <summary>
    ///   Format description of the loaded image.
    /// </summary>
    property ImageFormat : string read GetImageFormat;

    /// <summary>
    ///   Indicates whether an image is currently loaded.
    /// </summary>
    property HasImage : Boolean read GetHasImage;

    /// <summary>
    ///   The last error message if image loading failed.
    /// </summary>
    property LastError : string read FLastError;

    /// <summary>
    ///   Indicates whether copy operation is available.
    /// </summary>
    property CanCopy : Boolean read GetCanCopy;

    /// <summary>
    ///   Indicates whether cut operation is available.
    /// </summary>
    property CanCut : Boolean read GetCanCut;

    /// <summary>
    ///   Indicates whether paste operation is available.
    /// </summary>
    property CanPaste : Boolean read GetCanPaste;

    /// <summary>
    ///   Indicates whether clear operation is available.
    /// </summary>
    property CanClear : Boolean read GetCanClear;

    /// <summary>
    ///   Returns the dimensions of the loaded image.
    /// </summary>
    property ImageSize : TSize read GetImageSize;

    /// <summary>
    ///   Indicates whether the current image is an animated GIF.
    /// </summary>
    property IsAnimatedGIF : Boolean read GetIsAnimatedGIF;

    /// <summary>
    ///   Indicates whether animation is currently playing.
    /// </summary>
    property IsAnimating : Boolean read FIsAnimating;

    /// <summary>
    ///   Current pan offset in pixels.
    /// </summary>
    property PanOffset : TPoint read FPanOffset;

    /// <summary>
    ///   The scroll position per axis: 0 with the picture's left / top edge in view, up to the overhang.
    /// </summary>
    property ScrollPosition : TPoint read GetScrollPosition;

    /// <summary>
    ///   When True, scroll bars appear while the picture (zoomed, not fitted) is larger than the control. The mouse
    ///   wheel then scrolls (Shift+wheel horizontally) and Ctrl+wheel zooms.
    /// </summary>
    property ScrollBars : Boolean read FScrollBars write SetScrollBars default False;

    /// <summary>
    ///   When True (the default) a right-click shows the built-in context menu; a PopupMenu, when assigned, is shown
    ///   instead either way.
    /// </summary>
    property ShowContextMenu : Boolean read FShowContextMenu write FShowContextMenu default True;

    /// <summary>
    ///   TDBImage compatibility: True scales the picture to the control both ways (ShrinkToFit and ZoomToFit). Not
    ///   stored: a form keeps the fit properties it maps to, so an old TDBImage form loads and is saved in our terms.
    /// </summary>
    property Stretch : Boolean read FStretch write SetStretch stored False;

    /// <summary>
    ///   TDBImage compatibility: True keeps the aspect ratio, and without Stretch shrinks a larger picture to fit
    ///   (never enlarges a smaller one). Not stored (see Stretch).
    /// </summary>
    property Proportional : Boolean read FProportional write SetProportional stored False;

    /// <summary>
    ///   Raised when image files are dropped on the control (EnableDragDrop), with every dropped file; set Handled to
    ///   take the drop over (validate, convert, add several). Left unhandled, the control loads the first supported
    ///   file itself.
    /// </summary>
    property OnFilesDropped : TFilesDroppedEvent read FOnFilesDropped write FOnFilesDropped;

    /// <summary>Border drawn round the control.</summary>
    property BorderStyle : TBorderStyle read FBorderStyle write SetBorderStyle default bsSingle;
    /// <summary>When True the picture is centred in the control.</summary>
    property Center : Boolean read FCenter write SetCenter default True;
    /// <summary>When True the picture cannot be changed through the control.</summary>
    property ReadOnly : Boolean read GetReadOnly write SetReadOnly default False;
    /// <summary>
    ///   When True, uses faster but lower quality drawing for palettised images.
    /// </summary>
    property QuickDraw : Boolean read FQuickDraw write FQuickDraw default True;
    /// <summary>
    ///   When True, shrinks images larger than the component to fit within its bounds.
    /// </summary>
    property ShrinkToFit : Boolean read FShrinkToFit write SetShrinkToFit default False;
    /// <summary>
    ///   When True, expands images smaller than the component to fit within its bounds.
    /// </summary>
    property ZoomToFit : Boolean read FZoomToFit write SetZoomToFit default False;
    /// <summary>
    ///   When True, scales the image to fit the window (combines ShrinkToFit and ZoomToFit).
    /// </summary>
    property FitToWindow : Boolean read GetFitToWindow write SetFitToWindow default False;
    /// <summary>
    ///   When True, maintains the image aspect ratio during scaling.
    /// </summary>
    property MaintainAspectRatio : Boolean read FMaintainAspectRatio write SetMaintainAspectRatio default True;
    /// <summary>
    ///   Determines how transparent areas are displayed.
    /// </summary>
    property TransparentMode : TTransparentMode read FTransparentMode write SetTransparentMode default tmSolidColour;
    /// <summary>
    ///   Size of checkerboard squares in pixels.
    /// </summary>
    property CheckerSize : Integer read FCheckerSize write SetCheckerSize default 8;
    /// <summary>
    ///   First colour of the checkerboard pattern.
    /// </summary>
    property CheckerColour1 : TColor read FCheckerColour1 write SetCheckerColour1 default clWhite;
    /// <summary>
    ///   Second colour of the checkerboard pattern.
    /// </summary>
    property CheckerColour2 : TColor read FCheckerColour2 write SetCheckerColour2 default clSilver;
    /// <summary>
    ///   Enables mouse wheel zooming.
    /// </summary>
    property EnableMouseWheel : Boolean read FEnableMouseWheel write FEnableMouseWheel default True;
    /// <summary>
    ///   Current zoom factor (1.0 = 100%).
    /// </summary>
    property ZoomFactor : Double read FZoomFactor write SetZoomFactor;
    /// <summary>
    ///   Minimum zoom factor allowed (must be greater than 0 and less than or equal to MaxZoom).
    /// </summary>
    property MinZoom : Double read FMinZoom write SetMinZoom;
    /// <summary>
    ///   Maximum zoom factor allowed (must be greater than or equal to MinZoom).
    /// </summary>
    property MaxZoom : Double read FMaxZoom write SetMaxZoom;
    /// <summary>
    ///   Enables drag and drop of image files.
    /// </summary>
    property EnableDragDrop : Boolean read FEnableDragDrop write SetEnableDragDrop default True;
    /// <summary>
    ///   Lets the picture be dragged out of the control as a file (to Explorer, an e-mail, another program). The drag
    ///   starts with the left button when the picture cannot be panned, or with Ctrl held when it can.
    /// </summary>
    property EnableDragOut : Boolean read FEnableDragOut write FEnableDragOut default False;
    /// <summary>
    ///   File name, without extension, of a picture dragged out; the extension follows the picture's format. Empty
    ///   gives SDragOutDefaultName.
    /// </summary>
    property DragOutFileName : string read FDragOutFileName write FDragOutFileName;
    /// <summary>
    ///   Shows an error indicator when image loading fails.
    /// </summary>
    property ShowErrorState : Boolean read FShowErrorState write FShowErrorState default True;
    /// <summary>
    ///   Maximum allowed image width in pixels (0 = no limit).
    /// </summary>
    property MaxImageWidth : Integer read FMaxImageWidth write FMaxImageWidth default 0;
    /// <summary>
    ///   Maximum allowed image height in pixels (0 = no limit).
    /// </summary>
    property MaxImageHeight : Integer read FMaxImageHeight write FMaxImageHeight default 0;
    /// <summary>
    ///   Enables pan/scroll when the image is zoomed beyond the component bounds.
    /// </summary>
    property EnablePan : Boolean read FEnablePan write SetEnablePan default True;
    /// <summary>
    ///   Current rotation angle of the image.
    /// </summary>
    property Rotation : TRotationAngle read FRotation write SetRotation default ro0;
    /// <summary>
    ///   Text displayed when no image is loaded.
    /// </summary>
    property NoPicture : string read FNoPicture write FNoPicture;
    /// <summary>
    ///   Fired when an image is successfully loaded.
    /// </summary>
    property OnImageLoaded : TNotifyEvent read FOnImageLoaded write FOnImageLoaded;
    /// <summary>
    ///   Fired when an image fails to load.
    /// </summary>
    property OnImageError : TNotifyEvent read FOnImageError write FOnImageError;
    /// <summary>
    ///   Fired when the zoom factor changes.
    /// </summary>
    property OnZoomChanged : TNotifyEvent read FOnZoomChanged write FOnZoomChanged;
    /// <summary>
    ///   Fired when the pan offset changes.
    /// </summary>
    property OnPanChanged : TNotifyEvent read FOnPanChanged write FOnPanChanged;
    /// <summary>
    ///   Fired when the image is rotated.
    /// </summary>
    property OnRotated : TNotifyEvent read FOnRotated write FOnRotated;
    /// <summary>
    ///   Fired when the image is flipped.
    /// </summary>
    property OnFlipped : TNotifyEvent read FOnFlipped write FOnFlipped;
  end;

  /// <summary>
  ///   Stand-alone picture viewer: TgllCustomImageView with its properties published (the TImage counterpart of
  ///   TgllDBImage).
  /// </summary>
  /// <example>
  ///   <code>
  ///   gllImageView1.FitToWindow := True;
  ///   gllImageView1.LoadFromFile( 'C:\Pictures\Photo.jpg' );
  ///   gllImageView1.RotateClockwise;
  ///   </code>
  /// </example>
  TgllImageView = class( TgllCustomImageView )
  public
    /// <summary>Creates the viewer. It starts out loaded (empty), so it shows NoPicture rather than a
    /// placeholder caption.</summary>
    /// <param name="AOwner">The owning component.</param>
    constructor Create( AOwner : TComponent ); override;

  published
    /// <summary>Inherited <c>Align</c>, published.</summary>
    property Align;
    /// <summary>Inherited <c>Anchors</c>, published.</summary>
    property Anchors;
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
    /// <summary>The picture shown; stored in the form like TImage.Picture.</summary>
    property Picture;
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
    /// <summary>Inherited <c>NoPicture</c>, published.</summary>
    property NoPicture;
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
  System.IOUtils,
  Vcl.Clipbrd, Vcl.Imaging.Jpeg, Vcl.Imaging.PngImage,
  Jxl.Graphic,
  gllImage.DragDrop;

constructor TgllCustomImageView.Create( AOwner : TComponent );
begin

  inherited Create( AOwner );
  ControlStyle := ControlStyle + [ csOpaque, csReplicatable, csNeedsBorderPaint ];

  if ( not NewStyleControls ) then
    ControlStyle := ControlStyle + [ csFramed ];

  Width       := 105;
  Height      := 105;
  TabStop     := True;
  ParentColor := False;

  FBorderStyle         := bsSingle;
  FCenter              := True;
  FPictureValid        := False;
  FPictureLoaded       := False;
  FQuickDraw           := True;
  FMaintainAspectRatio := True;
  FTransparentMode     := tmSolidColour;
  FCheckerSize         := 8;
  FCheckerColour1      := clWhite;
  FCheckerColour2      := clSilver;
  FEnableMouseWheel    := True;
  FZoomFactor          := 1.0;
  FMinZoom             := 0.1;
  FMaxZoom             := 10.0;
  FEnableDragDrop      := True;
  FShowErrorState      := True;
  FLastError           := '';
  FMaxImageWidth       := 0;
  FMaxImageHeight      := 0;
  FEnablePan           := True;
  FPanOffset           := Point( 0, 0 );
  FIsPanning           := False;
  FRotation            := ro0;
  FIsAnimating         := False;
  FShowContextMenu     := True;

  FDrawPict         := TPicture.Create;
  FCheckerTile      := TBitmap.Create;
  FCheckerTileValid := False;

  FPicture          := TPicture.Create;
  FPicture.OnChange := PictureChanged;

  FContextMenu := nil;

  FAnimationTimer          := TTimer.Create( Self );
  FAnimationTimer.Enabled  := False;
  FAnimationTimer.Interval := ANIMATION_INTERVAL;
  FAnimationTimer.OnTimer  := AnimationTimerTick;

  FSaveFormatHandlers := TDictionary<string, TSaveFormatHandler>.Create;
  InitialiseSaveHandlers;

  if ( csDesigning not in ComponentState ) then
    CreateContextMenu;

end;

destructor TgllCustomImageView.Destroy;
begin

  // GITLAK 2026-10-19: the OLE registration goes before OLE is uninitialised; DestroyWnd, later, finds none.
  if HandleAllocated then
    RevokeDropTarget;

  FDropTarget := nil;

  if FOleInitialised then
    OleUninitialize;

  DeleteDropFolder( FDragOutFolder );

  StopAnimation;
  FAnimationTimer.Free;
  FSaveFormatHandlers.Free;
  FContextMenu.Free;
  FCheckerTile.Free;
  FPicture.Free;
  FDrawPict.Free;

  inherited Destroy;

end;

function TgllCustomImageView.CanModify : Boolean;
begin

  Result := not FReadOnly;

end;

function TgllCustomImageView.GetReadOnly : Boolean;
begin

  Result := FReadOnly;

end;

procedure TgllCustomImageView.SetReadOnly( Value : Boolean );
begin

  FReadOnly := Value;

end;

procedure TgllCustomImageView.PictureModified;
begin

  // Nothing to report: the stand-alone viewer's picture is its own.

end;

function TgllCustomImageView.LoadPaintCopy( APicture : TPicture ) : Boolean;
begin

  Result := False;

end;

function TgllCustomImageView.GetPlaceholderCaption : string;
begin

  Result := Name;

end;

procedure TgllCustomImageView.DoImageError;
begin

  if Assigned( FOnImageError ) then
    FOnImageError( Self );

end;

procedure TgllCustomImageView.LoadFromFile( const FileName : string );
begin

  if ( not CanModify ) then
  begin
    FLastError := SPictureReadOnly;
    DoImageError;
    Invalidate;
    Exit;
  end;

  try
    FPicture.LoadFromFile( FileName );
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

procedure TgllCustomImageView.RotatePicture( Angle : TRotationAngle );
begin

  // The picture as seen: the display rotation plus the requested one.
  var lTotal := TRotationAngle( ( Ord( FRotation ) + Ord( Angle ) ) mod 4 );

  if ( not HasImage ) or ( ( lTotal = ro0 ) and ( FRotation = ro0 ) ) or ( not CanModify ) then
    Exit;

  // A full turn back to where the pixels already are: only the display changes.
  if lTotal = ro0 then
  begin
    Rotation := ro0;
    Exit;
  end;

  var lBmp := GraphicToBitmap( FPicture.Graphic );

  try

    var lRotated := RotateBitmap( lBmp, lTotal );

    try
      // PictureChanged (through Picture.OnChange) resets the display rotation and the pan, and reports the change.
      ReplaceGraphicKeepingFormat( FPicture, lRotated );

      if Assigned( FOnRotated ) then
        FOnRotated( Self );
    finally
      lRotated.Free;
    end;

  finally
    lBmp.Free;
  end;

end;

procedure TgllCustomImageView.KeyPress( var Key : Char );
begin

  inherited KeyPress( Key );

  case Key of
    ^X  : CutToClipboard;
    ^C  : CopyToClipboard;
    ^V  : PasteFromClipboard;
    ^Z  : SendMessage( Handle, WM_UNDO, 0, 0 );
  end;

end;

procedure TgllCustomImageView.CMExit( var Message : TCMExit );
begin

  Invalidate;
  inherited;

end;

procedure TgllCustomImageView.InitialiseSaveHandlers;
begin

  FSaveFormatHandlers.Add( '.jpg',
    procedure( const FileName : string; Source : TGraphic )
    begin

      if ( Source is TJPEGImage ) then
        Source.SaveToFile( FileName )
      else
      begin

        var lTemp := TBitmap.Create;

        try
          lTemp.Assign( Source );

          var lJpg := TJPEGImage.Create;

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

    end );

  FSaveFormatHandlers.Add( '.jpeg', FSaveFormatHandlers[ '.jpg' ] );

  FSaveFormatHandlers.Add( '.png',
    procedure( const FileName : string; Source : TGraphic )
    begin

      if ( Source is TPngImage ) then
        Source.SaveToFile( FileName )
      else
      begin

        var lPng := TPngImage.Create;

        try
          lPng.Assign( Source );
          lPng.SaveToFile( FileName );
        finally
          lPng.Free;
        end;
      end;

    end );

  FSaveFormatHandlers.Add( '.bmp',
    procedure( const FileName : string; Source : TGraphic )
    begin

      if ( Source is TBitmap ) then
        Source.SaveToFile( FileName )
      else
      begin

        var lBmp := TBitmap.Create;

        try
          lBmp.Assign( Source );
          lBmp.SaveToFile( FileName );
        finally
          lBmp.Free;
        end;
      end;

    end );

  FSaveFormatHandlers.Add( '.gif',
    procedure( const FileName : string; Source : TGraphic )
    begin

      if ( Source is TGIFImage ) then
        Source.SaveToFile( FileName )
      else
      begin

        var lGif := TGIFImage.Create;

        try
          lGif.Assign( Source );
          lGif.SaveToFile( FileName );
        finally
          lGif.Free;
        end;
      end;

    end );

  // GITLAK 2026-10-19: without a handler a .jxl name fell back to Source.SaveToFile, which writes the graphic's own
  // format: a JPEG "saved as" .jxl was JPEG bytes.
  FSaveFormatHandlers.Add( '.jxl',
    procedure( const FileName : string; Source : TGraphic )
    begin

      if ( Source is TJxlImage ) then
        Source.SaveToFile( FileName )
      else
      begin

        var lBmp := GraphicToBitmap( Source );

        try

          var lJxl := TJxlImage.Create;

          try
            lJxl.Assign( lBmp );
            lJxl.SaveToFile( FileName );
          finally
            lJxl.Free;
          end;

        finally
          lBmp.Free;
        end;
      end;

    end );

end;

procedure TgllCustomImageView.RegisterSaveFormat( const Extension : string; Handler : TSaveFormatHandler );
begin

  FSaveFormatHandlers.AddOrSetValue( LowerCase( Extension ), Handler );

end;

procedure TgllCustomImageView.CreateContextMenu;
var
  lMenuItem : TMenuItem;
begin

  FContextMenu := TPopupMenu.Create( Self );

  FMenuItemCopy         := TMenuItem.Create( FContextMenu );
  FMenuItemCopy.Caption := Format( '%s'#9'%s', [ SMenuCopy, SShortcutCtrlC ] );
  FMenuItemCopy.OnClick := ContextMenuCopy;
  FContextMenu.Items.Add( FMenuItemCopy );

  FMenuItemCut         := TMenuItem.Create( FContextMenu );
  FMenuItemCut.Caption := Format( '%s'#9'%s', [ SMenuCut, SShortcutCtrlX ] );
  FMenuItemCut.OnClick := ContextMenuCut;
  FContextMenu.Items.Add( FMenuItemCut );

  FMenuItemPaste         := TMenuItem.Create( FContextMenu );
  FMenuItemPaste.Caption := Format( '%s'#9'%s', [ SMenuPaste, SShortcutCtrlV ] );
  FMenuItemPaste.OnClick := ContextMenuPaste;
  FContextMenu.Items.Add( FMenuItemPaste );

  lMenuItem         := TMenuItem.Create( FContextMenu );
  lMenuItem.Caption := '-';
  FContextMenu.Items.Add( lMenuItem );

  FMenuItemClear         := TMenuItem.Create( FContextMenu );
  FMenuItemClear.Caption := Format( '%s'#9'%s', [ SMenuClear, SShortcutCtrlDel ] );
  FMenuItemClear.OnClick := ContextMenuClear;
  FContextMenu.Items.Add( FMenuItemClear );

  lMenuItem         := TMenuItem.Create( FContextMenu );
  lMenuItem.Caption := '-';
  FContextMenu.Items.Add( lMenuItem );

  FMenuItemRotateCW         := TMenuItem.Create( FContextMenu );
  FMenuItemRotateCW.Caption := SMenuRotateCW;
  FMenuItemRotateCW.OnClick := ContextMenuRotateCW;
  FContextMenu.Items.Add( FMenuItemRotateCW );

  FMenuItemRotateCCW         := TMenuItem.Create( FContextMenu );
  FMenuItemRotateCCW.Caption := SMenuRotateCCW;
  FMenuItemRotateCCW.OnClick := ContextMenuRotateCCW;
  FContextMenu.Items.Add( FMenuItemRotateCCW );

  FMenuItemFlipH         := TMenuItem.Create( FContextMenu );
  FMenuItemFlipH.Caption := SMenuFlipH;
  FMenuItemFlipH.OnClick := ContextMenuFlipH;
  FContextMenu.Items.Add( FMenuItemFlipH );

  FMenuItemFlipV         := TMenuItem.Create( FContextMenu );
  FMenuItemFlipV.Caption := SMenuFlipV;
  FMenuItemFlipV.OnClick := ContextMenuFlipV;
  FContextMenu.Items.Add( FMenuItemFlipV );

  lMenuItem         := TMenuItem.Create( FContextMenu );
  lMenuItem.Caption := '-';
  FContextMenu.Items.Add( lMenuItem );

  FMenuItemResetView         := TMenuItem.Create( FContextMenu );
  FMenuItemResetView.Caption := SMenuResetView;
  FMenuItemResetView.OnClick := ContextMenuResetView;
  FContextMenu.Items.Add( FMenuItemResetView );

  FMenuItemAnimation         := TMenuItem.Create( FContextMenu );
  FMenuItemAnimation.Caption := SMenuStartAnimation;
  FMenuItemAnimation.OnClick := ContextMenuToggleAnimation;
  FContextMenu.Items.Add( FMenuItemAnimation );

  lMenuItem         := TMenuItem.Create( FContextMenu );
  lMenuItem.Caption := '-';
  FContextMenu.Items.Add( lMenuItem );

  FMenuItemLoad         := TMenuItem.Create( FContextMenu );
  FMenuItemLoad.Caption := SMenuLoadFromFile;
  FMenuItemLoad.OnClick := ContextMenuLoadFromFile;
  FContextMenu.Items.Add( FMenuItemLoad );

  FMenuItemSave         := TMenuItem.Create( FContextMenu );
  FMenuItemSave.Caption := SMenuSaveToFile;
  FMenuItemSave.OnClick := ContextMenuSaveToFile;
  FContextMenu.Items.Add( FMenuItemSave );

  lMenuItem         := TMenuItem.Create( FContextMenu );
  lMenuItem.Caption := '-';
  FContextMenu.Items.Add( lMenuItem );

  FMenuItemPrint         := TMenuItem.Create( FContextMenu );
  FMenuItemPrint.Caption := Format( '%s'#9'%s', [ SMenuPrint, SShortcutCtrlP ] );
  FMenuItemPrint.OnClick := ContextMenuPrint;
  FContextMenu.Items.Add( FMenuItemPrint );

end;

procedure TgllCustomImageView.ContextMenuCopy( Sender : TObject );
begin

  CopyToClipboard;

end;

procedure TgllCustomImageView.ContextMenuCut( Sender : TObject );
begin

  CutToClipboard;

end;

procedure TgllCustomImageView.ContextMenuPaste( Sender : TObject );
begin

  PasteFromClipboard;

end;

procedure TgllCustomImageView.ContextMenuClear( Sender : TObject );
begin

  if ( Picture.Graphic <> nil ) and CanModify then
  begin
    Picture.Graphic := nil;
    PictureChanged( Self );
  end;

end;

procedure TgllCustomImageView.ContextMenuLoadFromFile( Sender : TObject );
begin

  var lDlg := TOpenDialog.Create( nil );

  try
    lDlg.Filter := SFilterAllImages + SFilterBitmap + SFilterJpeg +
                   SFilterPng + SFilterGif + SFilterJxl + SFilterTiff + SFilterIcon + SFilterMetafile +
                   SFilterAllFiles;
    lDlg.Title  := SDialogLoadImage;

    if lDlg.Execute then
      LoadFromFile( lDlg.FileName );
  finally
    lDlg.Free;
  end;

end;

procedure TgllCustomImageView.ContextMenuSaveToFile( Sender : TObject );
begin

  if ( not HasImage ) then
    Exit;

  var lDlg := TSaveDialog.Create( nil );

  try
    lDlg.Filter   := SFilterBitmap + SFilterJpeg + SFilterPng +
                     SFilterGif + SFilterJxl + SFilterAllFiles;
    lDlg.Title    := SDialogSaveImage;
    lDlg.FileName := 'image';

    if lDlg.Execute then
      SaveToFile( lDlg.FileName );
  finally
    lDlg.Free;
  end;

end;

procedure TgllCustomImageView.ContextMenuPrint( Sender : TObject );
begin

  Print;

end;

procedure TgllCustomImageView.ContextMenuRotateCW( Sender : TObject );
begin

  RotateClockwise;

end;

procedure TgllCustomImageView.ContextMenuRotateCCW( Sender : TObject );
begin

  RotateCounterClockwise;

end;

procedure TgllCustomImageView.ContextMenuFlipH( Sender : TObject );
begin

  FlipHorizontal;

end;

procedure TgllCustomImageView.ContextMenuFlipV( Sender : TObject );
begin

  FlipVertical;

end;

procedure TgllCustomImageView.ContextMenuResetView( Sender : TObject );
begin

  ResetView;

end;

procedure TgllCustomImageView.ContextMenuToggleAnimation( Sender : TObject );
begin

  if FIsAnimating then
    StopAnimation
  else
    StartAnimation;

end;

procedure TgllCustomImageView.AnimationTimerTick( Sender : TObject );
begin

  if ( not HasImage ) or ( not IsAnimatedGIF ) then
  begin
    StopAnimation;
    Exit;
  end;

  var lGif := FPicture.Graphic as TGIFImage;

  if lGif.Images.Count > 1 then
  begin
    lGif.Animate := True;
    Invalidate;
  end;

end;

procedure TgllCustomImageView.StartAnimation;
begin

  if ( not HasImage ) or ( not IsAnimatedGIF ) then
    Exit;

  FIsAnimating            := True;
  FAnimationTimer.Enabled := True;

  var lGif := FPicture.Graphic as TGIFImage;

  lGif.Animate := True;
  lGif.AnimationSpeed := 100;

end;

procedure TgllCustomImageView.StopAnimation;
begin

  FAnimationTimer.Enabled := False;
  FIsAnimating            := False;

  if HasImage and ( FPicture.Graphic is TGIFImage ) then
    ( FPicture.Graphic as TGIFImage ).Animate := False;

end;

function TgllCustomImageView.GetIsAnimatedGIF : Boolean;
begin

  Result := HasImage and ( FPicture.Graphic is TGIFImage ) and
            ( ( FPicture.Graphic as TGIFImage ).Images.Count > 1 );

end;

procedure TgllCustomImageView.StartPan( X, Y : Integer );
begin

  if ( not FEnablePan ) or ( not HasImage ) then
    Exit;

  FIsPanning      := True;
  FPanStartPoint  := Point( X, Y );
  FPanStartOffset := FPanOffset;
  Cursor          := crHandPoint;

end;

procedure TgllCustomImageView.UpdatePan( X, Y : Integer );
var
  lDeltaX : Integer;
  lDeltaY : Integer;
begin

  if ( not FIsPanning ) then
    Exit;

  lDeltaX    := X - FPanStartPoint.X;
  lDeltaY    := Y - FPanStartPoint.Y;
  FPanOffset := Point( FPanStartOffset.X + lDeltaX, FPanStartOffset.Y + lDeltaY );

  ClampPanOffset;
  Invalidate;

  if Assigned( FOnPanChanged ) then
    FOnPanChanged( Self );

end;

procedure TgllCustomImageView.EndPan;
begin

  FIsPanning := False;
  Cursor     := crDefault;

end;

function TgllCustomImageView.GetViewImageSize : TSize;
begin

  if ( not HasImage ) then
    Exit( TSize.Create( 0, 0 ) );

  var lWidth  := FPicture.Graphic.Width;
  var lHeight := FPicture.Graphic.Height;

  // Paint draws FDrawPict, the picture after the display rotation.
  if FRotation in [ ro90, ro270 ] then
  begin
    lWidth  := FPicture.Graphic.Height;
    lHeight := FPicture.Graphic.Width;
  end;

  Result := TSize.Create( Round( lWidth * FZoomFactor ), Round( lHeight * FZoomFactor ) );

end;

function TgllCustomImageView.GetViewClientSize : TSize;
begin

  // ClientWidth on a control without a window makes the VCL create one, which fails without a parent: a picture
  // assigned before Parent is set must not raise. Without a window nothing is drawn, and CreateWnd / WM_SIZE clamp
  // again once the real client area exists.
  if HandleAllocated then
    Result := TSize.Create( ClientWidth, ClientHeight )
  else
    Result := TSize.Create( Width, Height );

end;

function TgllCustomImageView.GetScrollExcess : TPoint;
begin

  var lSize   := GetViewImageSize;
  var lClient := GetViewClientSize;

  // A fitted picture fills the control, so there is nothing to scroll.
  if GetIsFitted then
    Exit( Point( 0, 0 ) );

  Result := Point( Max( 0, lSize.cx - lClient.cx ), Max( 0, lSize.cy - lClient.cy ) );

end;

function TgllCustomImageView.PanBase( AExcess : Integer ) : Integer;
begin

  // Paint puts a centred picture at ( ClientSize - ImageSize ) div 2 + pan; an uncentred one at 0 + pan.
  Result := if FCenter then AExcess div 2 else 0;

end;

function TgllCustomImageView.GetScrollPosition : TPoint;
begin

  var lExcess := GetScrollExcess;

  Result := Point( PanBase( lExcess.X ) - FPanOffset.X, PanBase( lExcess.Y ) - FPanOffset.Y );

end;

procedure TgllCustomImageView.ClampPanOffset;
begin

  // GITLAK 2026-10-19: the limits now follow Paint exactly. They used the unrotated picture (so a portrait picture
  // turned 90 degrees could not be panned along its long side), allowed a symmetrical range for an uncentred
  // picture (which can only move one way), and did not reset the pan when the picture went away.
  var lExcess := GetScrollExcess;

  FPanOffset.X := EnsureRange( FPanOffset.X, PanBase( lExcess.X ) - lExcess.X, PanBase( lExcess.X ) );
  FPanOffset.Y := EnsureRange( FPanOffset.Y, PanBase( lExcess.Y ) - lExcess.Y, PanBase( lExcess.Y ) );

  UpdateScrollBars;

end;

procedure TgllCustomImageView.PanBy( DX, DY : Integer );
begin

  var lBefore := FPanOffset;

  FPanOffset := Point( FPanOffset.X + DX, FPanOffset.Y + DY );
  ClampPanOffset;

  if ( FPanOffset <> lBefore ) then
  begin
    Invalidate;

    if Assigned( FOnPanChanged ) then
      FOnPanChanged( Self );
  end;

end;

procedure TgllCustomImageView.SetScrollBars( const Value : Boolean );
begin

  if FScrollBars <> Value then
  begin
    FScrollBars := Value;
    ClampPanOffset;
    Invalidate;
  end;

end;

procedure TgllCustomImageView.UpdateScrollBars;
var
  lInfo : TScrollInfo;
begin

  if ( not HandleAllocated ) or FUpdatingScrollBars then
    Exit;

  FUpdatingScrollBars := True;

  try

    // Showing one bar shrinks the client area, which can make the other bar necessary: settle in a few rounds.
    for var lRound := 1 to 3 do
    begin
      var lClient := ClientRect;
      var lExcess := GetScrollExcess;
      var lPos    := GetScrollPosition;

      for var lBar in [ SB_HORZ, SB_VERT ] do
      begin
        var lAxisExcess := if lBar = SB_HORZ then lExcess.X else lExcess.Y;
        var lPage       := if lBar = SB_HORZ then lClient.Width else lClient.Height;
        var lShow       := FScrollBars and ( lAxisExcess > 0 );

        if lShow then
        begin
          lInfo        := Default( TScrollInfo );
          lInfo.cbSize := SizeOf( lInfo );
          lInfo.fMask  := SIF_RANGE or SIF_PAGE or SIF_POS;
          lInfo.nMin   := 0;
          lInfo.nMax   := lPage + lAxisExcess - 1;
          lInfo.nPage  := lPage;
          lInfo.nPos   := if lBar = SB_HORZ then lPos.X else lPos.Y;
          SetScrollInfo( Handle, lBar, lInfo, True );
        end;

        ShowScrollBar( Handle, lBar, lShow );
      end;

      if ClientRect = lClient then
        Break;

      // The client area changed: the pan limits did too.
      lExcess      := GetScrollExcess;
      FPanOffset.X := EnsureRange( FPanOffset.X, PanBase( lExcess.X ) - lExcess.X, PanBase( lExcess.X ) );
      FPanOffset.Y := EnsureRange( FPanOffset.Y, PanBase( lExcess.Y ) - lExcess.Y, PanBase( lExcess.Y ) );
    end;

  finally
    FUpdatingScrollBars := False;
  end;

end;

procedure TgllCustomImageView.ScrollAxis( ABar, ACode : Integer );
var
  lInfo : TScrollInfo;
begin

  var lExcess := GetScrollExcess;
  var lAxis   := if ABar = SB_HORZ then lExcess.X else lExcess.Y;
  var lPage   := if ABar = SB_HORZ then ClientWidth else ClientHeight;
  var lPos    := if ABar = SB_HORZ then GetScrollPosition.X else GetScrollPosition.Y;

  case ACode of
    SB_LINEUP        : Dec( lPos, PAN_STEP );
    SB_LINEDOWN      : Inc( lPos, PAN_STEP );
    SB_PAGEUP        : Dec( lPos, lPage );
    SB_PAGEDOWN      : Inc( lPos, lPage );
    SB_TOP           : lPos := 0;
    SB_BOTTOM        : lPos := lAxis;
    SB_THUMBTRACK, SB_THUMBPOSITION :
      begin
        // The message carries only 16 bits of position; the scroll info has all 32.
        lInfo        := Default( TScrollInfo );
        lInfo.cbSize := SizeOf( lInfo );
        lInfo.fMask  := SIF_TRACKPOS;

        if GetScrollInfo( Handle, ABar, lInfo ) then
          lPos := lInfo.nTrackPos;
      end;
  else
    Exit;   // SB_ENDSCROLL
  end;

  lPos := EnsureRange( lPos, 0, lAxis );

  if ABar = SB_HORZ then
    PanBy( PanBase( lAxis ) - lPos - FPanOffset.X, 0 )
  else
    PanBy( 0, PanBase( lAxis ) - lPos - FPanOffset.Y );

end;

procedure TgllCustomImageView.WMHScroll( var Message : TWMHScroll );
begin

  ScrollAxis( SB_HORZ, Message.ScrollCode );
  Message.Result := 0;

end;

procedure TgllCustomImageView.WMVScroll( var Message : TWMVScroll );
begin

  ScrollAxis( SB_VERT, Message.ScrollCode );
  Message.Result := 0;

end;

procedure TgllCustomImageView.RotateClockwise;
begin

  case FRotation of
    ro0   : Rotation := ro90;
    ro90  : Rotation := ro180;
    ro180 : Rotation := ro270;
    ro270 : Rotation := ro0;
  end;

end;

procedure TgllCustomImageView.RotateCounterClockwise;
begin

  case FRotation of
    ro0   : Rotation := ro270;
    ro90  : Rotation := ro0;
    ro180 : Rotation := ro90;
    ro270 : Rotation := ro180;
  end;

end;

procedure TgllCustomImageView.Rotate( Angle : TRotationAngle );
begin

  Rotation := Angle;

end;

procedure TgllCustomImageView.SetRotation( const Value : TRotationAngle );
begin

  if FRotation <> Value then
  begin
    FRotation     := Value;
    FPictureValid := False;
    FPanOffset    := Point( 0, 0 );
    ClampPanOffset;
    Invalidate;

    if Assigned( FOnRotated ) then
      FOnRotated( Self );
  end;

end;

procedure TgllCustomImageView.FlipHorizontal;
begin

  if ( not HasImage ) or ( not CanModify ) then
    Exit;

  var lBmp := GraphicToBitmap( FPicture.Graphic );

  try

    var lFlipped := FlipBitmap( lBmp, fdHorizontal );

    try
      ReplaceGraphicKeepingFormat( FPicture, lFlipped );
      FPictureValid := False;
      Invalidate;

      if Assigned( FOnFlipped ) then
        FOnFlipped( Self );
    finally
      lFlipped.Free;
    end;

  finally
    lBmp.Free;
  end;

end;

procedure TgllCustomImageView.FlipVertical;
begin

  if ( not HasImage ) or ( not CanModify ) then
    Exit;

  var lBmp := GraphicToBitmap( FPicture.Graphic );

  try

    var lFlipped := FlipBitmap( lBmp, fdVertical );

    try
      ReplaceGraphicKeepingFormat( FPicture, lFlipped );
      FPictureValid := False;
      Invalidate;

      if Assigned( FOnFlipped ) then
        FOnFlipped( Self );
    finally
      lFlipped.Free;
    end;

  finally
    lBmp.Free;
  end;

end;

procedure TgllCustomImageView.ResetView;
begin

  FZoomFactor := 1.0;
  FRotation   := ro0;
  FPanOffset  := Point( 0, 0 );
  FPictureValid := False;
  ClampPanOffset;
  Invalidate;

  if Assigned( FOnZoomChanged ) then
    FOnZoomChanged( Self );

end;

procedure TgllCustomImageView.Print( FitToPage : Boolean; CentreOnPage : Boolean );
begin

  if ( not HasImage ) then
    Exit;

  PrintGraphic( FPicture.Graphic, '', FitToPage, CentreOnPage );

end;

function TgllCustomImageView.GetThumbnail( MaxWidth, MaxHeight : Integer ) : TBitmap;
begin

  if ( not HasImage ) then
  begin
    Result := nil;
    Exit;
  end;

  Result := CreateThumbnail( FPicture.Graphic, MaxWidth, MaxHeight, True );

end;

procedure TgllCustomImageView.CreateWnd;
begin

  inherited CreateWnd;

  if FEnableDragDrop then
    RegisterDropTarget;

  UpdateScrollBars;

end;

procedure TgllCustomImageView.DestroyWnd;
begin

  if HandleAllocated then
    RevokeDropTarget;

  inherited DestroyWnd;

end;

function TgllCustomImageView.EnsureOle : Boolean;
begin

  // S_FALSE (already initialised on this thread) also needs its OleUninitialize; RPC_E_CHANGED_MODE (the thread
  // is multi-threaded COM) does not, and leaves only WM_DROPFILES.
  if not FOleInitialised then
    FOleInitialised := Succeeded( OleInitialize( nil ) );

  Result := FOleInitialised;

end;

procedure TgllCustomImageView.RegisterDropTarget;
begin

  // GITLAK 2026-10-19: OLE first, so virtual files (e-mail attachments, images from a browser) can be dropped as
  // well as files from Explorer. The designer keeps its own drag and drop.
  if ( csDesigning in ComponentState ) or Assigned( FDropTarget ) then
    Exit;

  if EnsureOle then
  begin
    var lTarget : IDropTarget := TgllImageDropTarget.Create( Handle, CanAcceptDrop, HandleDroppedFiles );

    if Succeeded( RegisterDragDrop( Handle, lTarget ) ) then
    begin
      FDropTarget := lTarget;
      Exit;
    end;
  end;

  DragAcceptFiles( Handle, True );

end;

procedure TgllCustomImageView.RevokeDropTarget;
begin

  if Assigned( FDropTarget ) then
  begin
    RevokeDragDrop( Handle );
    FDropTarget := nil;
  end
  else
    DragAcceptFiles( Handle, False );

end;

procedure TgllCustomImageView.Loaded;
begin

  inherited Loaded;

  if ( csDesigning not in ComponentState ) and ( not Assigned( FContextMenu ) ) then
    CreateContextMenu;

end;

function TgllCustomImageView.GetImageWidth : Integer;
begin

  Result := 0;

  if ( FPicture.Graphic <> nil ) and ( not FPicture.Graphic.Empty ) then
    Result := FPicture.Graphic.Width;

end;

function TgllCustomImageView.GetImageHeight : Integer;
begin

  Result := 0;

  if ( FPicture.Graphic <> nil ) and ( not FPicture.Graphic.Empty ) then
    Result := FPicture.Graphic.Height;

end;

function TgllCustomImageView.GetImageFormat : string;
begin

  Result := '';

  if ( FPicture.Graphic = nil ) or FPicture.Graphic.Empty then
    Exit;

  if ( FPicture.Graphic is TJPEGImage ) then
    Result := 'JPEG'
  else if ( FPicture.Graphic is TPngImage ) then
    Result := 'PNG'
  else if ( FPicture.Graphic is TGIFImage ) then
    Result := 'GIF'
  // Before TBitmap: TJxlImage descends from it.
  else if ( FPicture.Graphic is TJxlImage ) then
    Result := 'JPEG XL'
  else if ( FPicture.Graphic is TWICImage ) then
    Result := if TWICImage( FPicture.Graphic ).ImageFormat = wifTiff then 'TIFF' else 'WIC'
  else if ( FPicture.Graphic is TBitmap ) then
    Result := 'Bitmap'
  else if ( FPicture.Graphic is TIcon ) then
    Result := 'Icon'
  else if ( FPicture.Graphic is TMetafile ) then
    Result := 'Metafile'
  else
    Result := 'Unknown';

end;

function TgllCustomImageView.GetHasImage : Boolean;
begin

  Result := ( FPicture.Graphic <> nil ) and ( not FPicture.Graphic.Empty );

end;

function TgllCustomImageView.GetCanCopy : Boolean;
begin

  Result := HasImage;

end;

function TgllCustomImageView.GetCanCut : Boolean;
begin

  Result := HasImage and ( not GetReadOnly );

end;

function TgllCustomImageView.GetCanPaste : Boolean;
begin

  Result := ( not GetReadOnly ) and
            ( Clipboard.HasFormat( CF_BITMAP ) or
              Clipboard.HasFormat( CF_METAFILEPICT ) or
              Clipboard.HasFormat( CF_PICTURE ) );

end;

function TgllCustomImageView.GetCanClear : Boolean;
begin

  Result := HasImage and ( not GetReadOnly );

end;

function TgllCustomImageView.GetImageSize : TSize;
begin

  if HasImage then
  begin
    Result.cx := FPicture.Graphic.Width;
    Result.cy := FPicture.Graphic.Height;
  end
  else
  begin
    Result.cx := 0;
    Result.cy := 0;
  end;

end;

function TgllCustomImageView.GetFitToWindow : Boolean;
begin

  Result := FShrinkToFit and FZoomToFit;

end;

procedure TgllCustomImageView.SetFitToWindow( const Value : Boolean );
begin

  if ( FShrinkToFit <> Value ) or ( FZoomToFit <> Value ) then
  begin
    FShrinkToFit := Value;
    FZoomToFit   := Value;
    ClampPanOffset;
    Invalidate;
  end;

end;

function TgllCustomImageView.GetPalette : HPALETTE;
begin

  Result := 0;

  if ( FPicture.Graphic <> nil ) then
    Result := FPicture.Graphic.Palette;

end;

procedure TgllCustomImageView.SetBorderStyle( Value : TBorderStyle );
begin

  if FBorderStyle <> Value then
  begin
    FBorderStyle := Value;
    RecreateWnd;
  end;

end;

procedure TgllCustomImageView.SetCenter( Value : Boolean );
begin

  if FCenter <> Value then
  begin
    FCenter := Value;
    ClampPanOffset;
    Invalidate;
  end;

end;

procedure TgllCustomImageView.SetPicture( Value : TPicture );
begin

  FPicture.Assign( Value );

end;

procedure TgllCustomImageView.SetShrinkToFit( Value : Boolean );
begin

  if FShrinkToFit <> Value then
  begin
    FShrinkToFit := Value;
    ClampPanOffset;
    Invalidate;
  end;

end;

procedure TgllCustomImageView.SetZoomToFit( const Value : Boolean );
begin

  if FZoomToFit <> Value then
  begin
    FZoomToFit := Value;
    ClampPanOffset;
    Invalidate;
  end;

end;

procedure TgllCustomImageView.SetMaintainAspectRatio( const Value : Boolean );
begin

  if FMaintainAspectRatio <> Value then
  begin
    FMaintainAspectRatio := Value;
    ClampPanOffset;
    Invalidate;
  end;

end;

procedure TgllCustomImageView.SetTransparentMode( const Value : TTransparentMode );
begin

  if FTransparentMode <> Value then
  begin
    FTransparentMode := Value;
    Invalidate;
  end;

end;

procedure TgllCustomImageView.SetCheckerSize( const Value : Integer );
begin

  if ( FCheckerSize <> Value ) and ( Value > 0 ) then
  begin
    FCheckerSize      := Value;
    FCheckerTileValid := False;

    if FTransparentMode = tmCheckerboard then
      Invalidate;
  end;

end;

procedure TgllCustomImageView.SetCheckerColour1( const Value : TColor );
begin

  if FCheckerColour1 <> Value then
  begin
    FCheckerColour1   := Value;
    FCheckerTileValid := False;

    if FTransparentMode = tmCheckerboard then
      Invalidate;
  end;

end;

procedure TgllCustomImageView.SetCheckerColour2( const Value : TColor );
begin

  if FCheckerColour2 <> Value then
  begin
    FCheckerColour2   := Value;
    FCheckerTileValid := False;

    if FTransparentMode = tmCheckerboard then
      Invalidate;
  end;

end;

procedure TgllCustomImageView.SetEnableDragDrop( const Value : Boolean );
begin

  if FEnableDragDrop <> Value then
  begin
    FEnableDragDrop := Value;

    if HandleAllocated then
      if Value then
        RegisterDropTarget
      else
        RevokeDropTarget;
  end;

end;

procedure TgllCustomImageView.SetEnablePan( const Value : Boolean );
begin

  if FEnablePan <> Value then
  begin
    FEnablePan := Value;

    if ( not Value ) then
    begin
      FPanOffset := Point( 0, 0 );
      FIsPanning := False;
      Invalidate;
    end;
  end;

end;

procedure TgllCustomImageView.SetZoomFactor( const Value : Double );
var
  lNewZoom : Double;
begin

  lNewZoom := Value;

  if lNewZoom < FMinZoom then
    lNewZoom := FMinZoom;

  if lNewZoom > FMaxZoom then
    lNewZoom := FMaxZoom;

  if Abs( FZoomFactor - lNewZoom ) > 0.001 then
  begin
    FZoomFactor := lNewZoom;
    ClampPanOffset;
    Invalidate;

    if Assigned( FOnZoomChanged ) then
      FOnZoomChanged( Self );
  end;

end;

procedure TgllCustomImageView.SetMinZoom( const Value : Double );
begin

  if Value <= 0 then
    Exit;

  if Value > FMaxZoom then
    FMinZoom := FMaxZoom
  else
    FMinZoom := Value;

  if FZoomFactor < FMinZoom then
    SetZoomFactor( FMinZoom );

end;

procedure TgllCustomImageView.SetMaxZoom( const Value : Double );
begin

  if Value <= 0 then
    Exit;

  if Value < FMinZoom then
    FMaxZoom := FMinZoom
  else
    FMaxZoom := Value;

  if FZoomFactor > FMaxZoom then
    SetZoomFactor( FMaxZoom );

end;

procedure TgllCustomImageView.DrawCheckerboard( ACanvas : TCanvas; ARect : TRect );
var
  lX, lY    : Integer;
  lTileSize : Integer;
begin

  if ( not FCheckerTileValid ) then
  begin
    lTileSize := FCheckerSize * 2;
    FCheckerTile.SetSize( lTileSize, lTileSize );
    FCheckerTile.Canvas.Brush.Color := FCheckerColour1;
    FCheckerTile.Canvas.FillRect( Rect( 0, 0, FCheckerSize, FCheckerSize ) );
    FCheckerTile.Canvas.FillRect( Rect( FCheckerSize, FCheckerSize, lTileSize, lTileSize ) );
    FCheckerTile.Canvas.Brush.Color := FCheckerColour2;
    FCheckerTile.Canvas.FillRect( Rect( FCheckerSize, 0, lTileSize, FCheckerSize ) );
    FCheckerTile.Canvas.FillRect( Rect( 0, FCheckerSize, FCheckerSize, lTileSize ) );
    FCheckerTileValid := True;
  end;

  lTileSize := FCheckerSize * 2;
  lY        := ARect.Top;

  while lY < ARect.Bottom do
  begin
    lX := ARect.Left;

    while lX < ARect.Right do
    begin
      BitBlt( ACanvas.Handle, lX, lY,
              Min( lTileSize, ARect.Right - lX ), Min( lTileSize, ARect.Bottom - lY ),
              FCheckerTile.Canvas.Handle, 0, 0, SRCCOPY );
      Inc( lX, lTileSize );
    end;

    Inc( lY, lTileSize );
  end;

end;

procedure TgllCustomImageView.DrawErrorState( ACanvas : TCanvas; ARect : TRect );
var
  lIconSize : Integer;
  lIconRect : TRect;
  lTextRect : TRect;
  lTextSize : TSize;
begin

  ACanvas.Brush.Color := Color;
  ACanvas.FillRect( ARect );

  lIconSize := Min( 32, Min( ARect.Width, ARect.Height ) div 2 );

  if lIconSize >= 16 then
  begin
    lIconRect.Left   := ( ARect.Left + ARect.Right - lIconSize ) div 2;
    lIconRect.Top    := ( ARect.Top + ARect.Bottom - lIconSize ) div 2 - 10;
    lIconRect.Right  := lIconRect.Left + lIconSize;
    lIconRect.Bottom := lIconRect.Top + lIconSize;

    ACanvas.Pen.Color   := clRed;
    ACanvas.Pen.Width   := 2;
    ACanvas.Brush.Style := bsClear;
    ACanvas.Ellipse( lIconRect );
    ACanvas.MoveTo( lIconRect.Left + 4, lIconRect.Top + 4 );
    ACanvas.LineTo( lIconRect.Right - 4, lIconRect.Bottom - 4 );
    ACanvas.MoveTo( lIconRect.Right - 4, lIconRect.Top + 4 );
    ACanvas.LineTo( lIconRect.Left + 4, lIconRect.Bottom - 4 );
    ACanvas.Pen.Width := 1;
  end;

  if FLastError <> '' then
  begin
    ACanvas.Font       := Self.Font;
    ACanvas.Font.Color := clGray;
    lTextSize          := ACanvas.TextExtent( FLastError );
    lTextRect          := ARect;
    lTextRect.Top      := ( ARect.Top + ARect.Bottom ) div 2 + 10;

    ACanvas.TextRect( lTextRect, ( ARect.Right - lTextSize.cx ) div 2, lTextRect.Top, FLastError );
  end;

end;

procedure TgllCustomImageView.Paint;
var
  lTextSize    : TSize;
  lR           : TRect;
  lDrawRect    : TRect;
  lS           : string;
  lPal         : HPalette;
  lFrm         : TCustomForm;
  lScaledWidth : Integer;
  lScaledHeight: Integer;
  lNeedsScale  : Boolean;
  lRotatedBmp  : TBitmap;
begin

  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := Color;
  Canvas.FillRect( ClientRect );

  if ( FLastError <> '' ) and FShowErrorState then
    DrawErrorState( Canvas, ClientRect )
  else if FPictureLoaded or ( csPaintCopy in ControlState ) then
  begin
    lPal := 0;

    try

      if ( csPaintCopy in ControlState ) and LoadPaintCopy( FDrawPict ) then
      begin
        if ( FDrawPict.Graphic is TBitmap ) then
          FDrawPict.Bitmap.IgnorePalette := QuickDraw;
      end
      else if ( not FPictureValid ) then
      begin
        FDrawPict.Assign( Picture );

        if ( FRotation <> ro0 ) and ( FDrawPict.Graphic <> nil ) and ( not FDrawPict.Graphic.Empty ) then
        begin
          lRotatedBmp := GraphicToBitmap( FDrawPict.Graphic );

          try

            var lRotated := RotateBitmap( lRotatedBmp, FRotation );

            try
              FDrawPict.Bitmap.Assign( lRotated );
            finally
              lRotated.Free;
            end;

          finally
            lRotatedBmp.Free;
          end;
        end;

        FPictureValid := True;

        if Focused and ( FDrawPict.Graphic <> nil ) and ( FDrawPict.Graphic.Palette <> 0 ) then
        begin
          lPal := SelectPalette( Canvas.Handle, FDrawPict.Graphic.Palette, False );
          RealizePalette( Canvas.Handle );
        end;
      end;

      if ( FDrawPict.Graphic = nil ) or FDrawPict.Graphic.Empty then
      begin
        Canvas.FillRect( ClientRect );

        if Length( FNoPicture ) > 0 then
        begin
          lS        := '(' + FNoPicture + ')';
          lTextSize := Canvas.TextExtent( lS );
          lR        := ClientRect;
          Canvas.TextRect( lR, ( lR.Right - lTextSize.cx ) div 2, ( lR.Bottom - lTextSize.cy ) div 2, lS );
        end;
      end
      else
      begin
        lScaledWidth  := Round( FDrawPict.Width * FZoomFactor );
        lScaledHeight := Round( FDrawPict.Height * FZoomFactor );
        lNeedsScale   := False;

        if FShrinkToFit and ( ( lScaledHeight > ClientHeight ) or ( lScaledWidth > ClientWidth ) ) then
          lNeedsScale := True;

        if FZoomToFit and ( ( lScaledHeight < ClientHeight ) or ( lScaledWidth < ClientWidth ) ) then
          lNeedsScale := True;

        // GITLAK 2026-10-19: without MaintainAspectRatio a fitted picture is stretched to the whole client area; it
        // used to fall through to the unscaled branch, so "stretch to fill" was drawn at 1:1.
        if lNeedsScale then
        begin
          lDrawRect := if FMaintainAspectRatio then Rescale( ClientRect, FDrawPict ) else ClientRect;
          OffsetRect( lDrawRect, FPanOffset.X, FPanOffset.Y );

          if ( FTransparentMode = tmCheckerboard ) and FDrawPict.Graphic.Transparent then
            DrawCheckerboard( Canvas, lDrawRect );

          Canvas.StretchDraw( lDrawRect, FDrawPict.Graphic );
        end
        else
        begin
          SetRect( lR, 0, 0, lScaledWidth, lScaledHeight );

          if Center then
            OffsetRect( lR, ( ClientWidth - lScaledWidth ) div 2, ( ClientHeight - lScaledHeight ) div 2 );

          OffsetRect( lR, FPanOffset.X, FPanOffset.Y );

          if ( FTransparentMode = tmCheckerboard ) and FDrawPict.Graphic.Transparent then
            DrawCheckerboard( Canvas, lR );

          Canvas.StretchDraw( lR, FDrawPict.Graphic );
          ExcludeClipRect( Canvas.Handle, lR.Left, lR.Top, lR.Right, lR.Bottom );
          Canvas.FillRect( ClientRect );
          SelectClipRgn( Canvas.Handle, 0 );
        end;
      end;

    finally

      if lPal <> 0 then
        SelectPalette( Canvas.Handle, lPal, True );

      // GITLAK 2026-09-30: after a paint-copy (TDBCtrlGrid) FDrawPict is emptied, so it no
      // longer matches Picture; mark it invalid or the next normal paint shows "no picture".
      if ( csPaintCopy in ControlState ) then
      begin
        FDrawPict.Assign( nil );
        FPictureValid := False;
      end;
    end;
  end
  else
  begin
    Canvas.Font := Self.Font;

    lS        := '(' + GetPlaceholderCaption + ')';
    lTextSize := Canvas.TextExtent( lS );
    lR        := ClientRect;
    Canvas.TextRect( lR, ( lR.Right - lTextSize.cx ) div 2, ( lR.Bottom - lTextSize.cy ) div 2, lS );
  end;

  lFrm := GetParentForm( Self );

  if ( lFrm <> nil ) and ( lFrm.ActiveControl = Self ) and
     ( csDesigning not in ComponentState ) and ( csPaintCopy not in ControlState ) then
  begin
    Canvas.Brush.Color := clWindowFrame;
    Canvas.FrameRect( ClientRect );
  end;

end;

procedure TgllCustomImageView.PictureChanged( Sender : TObject );
var
  lExceedsMax : Boolean;
begin

  // GITLAK 2026-09-30: clearing an oversized picture below fires this handler again. That
  // re-entrant call saw FPictureLoaded still True and marked the record modified with a
  // nil picture, so the next Post erased the stored BLOB. Ignore it.
  if FClearingOversize then
    Exit;

  lExceedsMax := False;

  if ( FPicture.Graphic <> nil ) and ( not FPicture.Graphic.Empty ) then
  begin

    if ( FMaxImageWidth > 0 ) and ( FPicture.Graphic.Width > FMaxImageWidth ) then
      lExceedsMax := True;

    if ( FMaxImageHeight > 0 ) and ( FPicture.Graphic.Height > FMaxImageHeight ) then
      lExceedsMax := True;

    if lExceedsMax then
    begin
      FLastError := Format( SImageDimensionsExceed,
        [ FPicture.Graphic.Width, FPicture.Graphic.Height, FMaxImageWidth, FMaxImageHeight ] );
      FClearingOversize := True;
      try
        FPicture.Graphic := nil;
      finally
        FClearingOversize := False;
      end;
      FPictureLoaded   := False;
      FPictureValid    := False;

      if Assigned( FOnImageError ) then
        FOnImageError( Self );

      Invalidate;
      Exit;
    end;
  end;

  if FPictureLoaded then
    PictureModified;

  FPictureLoaded := True;
  FPictureValid  := False;
  FLastError     := '';
  FRotation      := ro0;
  FPanOffset     := Point( 0, 0 );
  ClampPanOffset;

  if ( csLoading not in ComponentState ) then
    Invalidate;

  if Assigned( FOnImageLoaded ) and ( csLoading not in ComponentState ) then
    FOnImageLoaded( Self );

end;

procedure TgllCustomImageView.CopyToClipboard;
begin

  if ( Picture.Graphic = nil ) then
    Exit;

  if ( Picture.Graphic is TIcon ) then
  begin

    var lTempBmp := TBitmap.Create;

    try
      lTempBmp.PixelFormat := pf32bit;
      lTempBmp.AlphaFormat := afDefined;
      lTempBmp.SetSize( Picture.Graphic.Width, Picture.Graphic.Height );
      lTempBmp.Canvas.Brush.Color := clWhite;
      lTempBmp.Canvas.FillRect( Rect( 0, 0, lTempBmp.Width, lTempBmp.Height ) );
      lTempBmp.Canvas.Draw( 0, 0, Picture.Graphic );
      Clipboard.Assign( lTempBmp );
    finally
      lTempBmp.Free;
    end;
  end
  else
    Clipboard.Assign( Picture );

end;

procedure TgllCustomImageView.CutToClipboard;
begin

  if ( Picture.Graphic = nil ) then
    Exit;

  if CanModify then
  begin
    CopyToClipboard;
    Picture.Graphic := nil;
    PictureChanged( Self );
  end;

end;

procedure TgllCustomImageView.PasteFromClipboard;
var
  lPasted : Boolean;
begin

  lPasted := False;

  if CanModify then
  begin

    if Clipboard.HasFormat( CF_BITMAP ) then
    begin
      Picture.Bitmap.Assign( Clipboard );
      lPasted := True;
    end
    else if Clipboard.HasFormat( CF_METAFILEPICT ) or Clipboard.HasFormat( CF_ENHMETAFILE ) then
    begin
      Picture.Metafile.Assign( Clipboard );
      lPasted := True;
    end
    else if Clipboard.HasFormat( CF_PICTURE ) then
    begin
      Picture.Assign( Clipboard );
      lPasted := True;
    end;
  end;

  if lPasted then
    PictureChanged( Self );

end;

procedure TgllCustomImageView.CreateParams( var Params : TCreateParams );
begin

  inherited CreateParams( Params );

  if FBorderStyle = bsSingle then
  begin

    if NewStyleControls and Ctl3D then
      Params.ExStyle := Params.ExStyle or WS_EX_CLIENTEDGE
    else
      Params.Style := Params.Style or WS_BORDER;
  end;

  Params.WindowClass.style := Params.WindowClass.style and not ( CS_HREDRAW or CS_VREDRAW );

end;

function TgllCustomImageView.DoMouseWheel( Shift : TShiftState; WheelDelta : Integer; MousePos : TPoint ) : Boolean;
begin

  Result := inherited DoMouseWheel( Shift, WheelDelta, MousePos );

  if ( not Result ) and FEnableMouseWheel and HasImage then
  begin
    var lExcess := GetScrollExcess;

    // With scroll bars, the wheel scrolls as in any other window and Ctrl+wheel zooms; without, it zooms.
    if FScrollBars and ( not ( ssCtrl in Shift ) ) and ( ( lExcess.X > 0 ) or ( lExcess.Y > 0 ) ) then
    begin
      var lStep := Sign( WheelDelta ) * PAN_STEP * 3;

      if ( ssShift in Shift ) or ( lExcess.Y = 0 ) then
        PanBy( lStep, 0 )
      else
        PanBy( 0, lStep );
    end
    else if WheelDelta > 0 then
      ZoomIn
    else
      ZoomOut;

    Result := True;
  end;

end;

procedure TgllCustomImageView.ZoomIn;
begin

  LeaveFitMode;
  ZoomFactor := FZoomFactor + ZOOM_STEP;

end;

procedure TgllCustomImageView.ZoomOut;
begin

  LeaveFitMode;
  ZoomFactor := FZoomFactor - ZOOM_STEP;

end;

procedure TgllCustomImageView.ZoomBy( const AFactor : Double );
begin

  if AFactor <= 0 then
    Exit;

  LeaveFitMode;
  ZoomFactor := FZoomFactor * AFactor;

end;

function TgllCustomImageView.GetIsFitted : Boolean;
begin

  var lSize   := GetViewImageSize;
  var lClient := GetViewClientSize;

  // The same decision Paint makes before it scales the picture to the control.
  Result := HasImage and
            ( ( FShrinkToFit and ( ( lSize.cy > lClient.cy ) or ( lSize.cx > lClient.cx ) ) ) or
              ( FZoomToFit and ( ( lSize.cy < lClient.cy ) or ( lSize.cx < lClient.cx ) ) ) );

end;

function TgllCustomImageView.GetFittedScale : Double;
begin

  Result := 1.0;

  var lZoom := FZoomFactor;

  if ( not HasImage ) or ( lZoom <= 0 ) then
    Exit;

  // GetViewImageSize is at ZoomFactor; the fitted scale is relative to the picture's own size.
  var lSize   := GetViewImageSize;
  var lClient := GetViewClientSize;
  var lWidth  := lSize.cx / lZoom;
  var lHeight := lSize.cy / lZoom;

  if ( lWidth > 0 ) and ( lHeight > 0 ) and ( lClient.cx > 0 ) and ( lClient.cy > 0 ) then
    Result := Min( lClient.cx / lWidth, lClient.cy / lHeight );

end;

procedure TgllCustomImageView.LeaveFitMode;
begin

  if not GetIsFitted then
    Exit;

  // Without the aspect kept the fit is not one scale; 100% is then the natural place to continue from.
  var lScale := if FMaintainAspectRatio then GetFittedScale else 1.0;

  FShrinkToFit := False;
  FZoomToFit   := False;
  FStretch     := False;
  FZoomFactor  := EnsureRange( lScale, FMinZoom, FMaxZoom );

end;

procedure TgllCustomImageView.SetStretch( const Value : Boolean );
begin

  FStretch := Value;
  ApplyStretchMode;

end;

procedure TgllCustomImageView.SetProportional( const Value : Boolean );
begin

  FProportional := Value;
  ApplyStretchMode;

end;

procedure TgllCustomImageView.ApplyStretchMode;
begin

  // TDBImage: Stretch fills the control both ways; Proportional keeps the aspect and, without Stretch, only shrinks
  // a larger picture. Neither: drawn at its own size.
  FShrinkToFit         := FStretch or FProportional;
  FZoomToFit           := FStretch;
  FMaintainAspectRatio := FProportional or ( not FStretch );
  ClampPanOffset;
  Invalidate;

end;

procedure TgllCustomImageView.ResetZoom;
begin

  ZoomFactor := 1.0;
  FPanOffset := Point( 0, 0 );

  if Assigned( FOnPanChanged ) then
    FOnPanChanged( Self );

end;

procedure TgllCustomImageView.ClearError;
begin

  FLastError := '';
  Invalidate;

end;

procedure TgllCustomImageView.KeyDown( var Key : Word; Shift : TShiftState );
begin

  inherited KeyDown( Key, Shift );

  case Key of
    VK_INSERT :
      if ( ssShift in Shift ) then
        PasteFromClipboard
      else if ( ssCtrl in Shift ) then
        CopyToClipboard;

    VK_DELETE :
      if ( ssShift in Shift ) then
        CutToClipboard
      else if ( ssCtrl in Shift ) then
        SendMessage( Handle, WM_CLEAR, 0, 0 );

    VK_ADD, VK_OEM_PLUS :
      if ( ssCtrl in Shift ) then
        ZoomIn;

    VK_SUBTRACT, VK_OEM_MINUS :
      if ( ssCtrl in Shift ) then
        ZoomOut;

    Ord( '0' ) :
      if ( ssCtrl in Shift ) then
        ResetZoom;

    Ord( 'R' ) :
      if ( ssCtrl in Shift ) then
        RotateClockwise;

    Ord( 'L' ) :
      if ( ssCtrl in Shift ) then
        RotateCounterClockwise;

    Ord( 'H' ) :
      if ( ssCtrl in Shift ) then
        FlipHorizontal;

    Ord( 'J' ) :
      if ( ssCtrl in Shift ) then
        FlipVertical;

    Ord( 'P' ) :
      if ( ssCtrl in Shift ) then
        Print;

    VK_LEFT :
      if FEnablePan then
      begin
        FPanOffset.X := FPanOffset.X + 20;
        ClampPanOffset;
        Invalidate;
      end;

    VK_RIGHT :
      if FEnablePan then
      begin
        FPanOffset.X := FPanOffset.X - 20;
        ClampPanOffset;
        Invalidate;
      end;

    VK_UP :
      if FEnablePan then
      begin
        FPanOffset.Y := FPanOffset.Y + 20;
        ClampPanOffset;
        Invalidate;
      end;

    VK_DOWN :
      if FEnablePan then
      begin
        FPanOffset.Y := FPanOffset.Y - 20;
        ClampPanOffset;
        Invalidate;
      end;
  end;

end;

procedure TgllCustomImageView.CMEnter( var Message : TCMEnter );
begin

  Invalidate;
  inherited;

end;

procedure TgllCustomImageView.CMTextChanged( var Message : TMessage );
begin

  inherited;

  if ( not FPictureLoaded ) then
    Invalidate;

end;

procedure TgllCustomImageView.WMLButtonDown( var Message : TWMLButtonDown );
begin

  if TabStop and CanFocus then
    SetFocus;

  // GITLAK 2026-10-19: a picture that cannot be panned is dragged out; one that can is dragged out with Ctrl.
  var lPannable := FEnablePan and ( GetScrollExcess <> Point( 0, 0 ) );

  if CanDragOut and ( ( ( Message.Keys and MK_CONTROL ) <> 0 ) or ( not lPannable ) ) then
  begin
    FDragOutPending := True;
    FDragOutStart   := Point( Message.XPos, Message.YPos );
  end
  else if FEnablePan and HasImage then
    StartPan( Message.XPos, Message.YPos );

  inherited;

end;

procedure TgllCustomImageView.WMLButtonUp( var Message : TWMLButtonUp );
begin

  FDragOutPending := False;
  EndPan;
  inherited;

end;

procedure TgllCustomImageView.WMMouseMove( var Message : TWMMouseMove );
begin

  if FDragOutPending then
  begin
    if ( Message.Keys and MK_LBUTTON ) = 0 then
      FDragOutPending := False
    else if ( Abs( Message.XPos - FDragOutStart.X ) > GetSystemMetrics( SM_CXDRAG ) ) or
            ( Abs( Message.YPos - FDragOutStart.Y ) > GetSystemMetrics( SM_CYDRAG ) ) then
      BeginDragOut;
  end
  else if FIsPanning then
    UpdatePan( Message.XPos, Message.YPos );

  inherited;

end;

procedure TgllCustomImageView.WMCut( var Message : TMessage );
begin

  CutToClipboard;

end;

procedure TgllCustomImageView.WMCopy( var Message : TMessage );
begin

  CopyToClipboard;

end;

procedure TgllCustomImageView.WMPaste( var Message : TMessage );
begin

  PasteFromClipboard;

end;

procedure TgllCustomImageView.WMSize( var Message : TMessage );
begin

  inherited;
  ClampPanOffset;
  Invalidate;

end;

procedure TgllCustomImageView.WMClear( var Message : TMessage );
begin

  if ( Picture.Graphic <> nil ) and CanModify then
  begin
    Picture.Graphic := nil;
    PictureChanged( Self );
  end;

end;

procedure TgllCustomImageView.WMDropFiles( var Message : TWMDropFiles );
var
  lFileName : array[ 0..MAX_PATH ] of Char;
begin

  if not CanAcceptDrop then
  begin
    inherited;
    Exit;
  end;

  try
    var lFileCount := DragQueryFile( Message.Drop, $FFFFFFFF, nil, 0 );
    var lNames     : TArray<string>;

    SetLength( lNames, lFileCount );

    for var i := 0 to Integer( lFileCount ) - 1 do
    begin
      DragQueryFile( Message.Drop, i, lFileName, MAX_PATH );
      lNames[ i ] := lFileName;
    end;

    HandleDroppedFiles( lNames );
  finally
    DragFinish( Message.Drop );
  end;

  Message.Result := 0;

end;

function TgllCustomImageView.CanAcceptDrop : Boolean;
begin

  Result := FEnableDragDrop and Enabled and ( not GetReadOnly ) and ( not FDraggingOut );

end;

procedure TgllCustomImageView.HandleDroppedFiles( const AFileNames : TArray<string> );
begin

  if Length( AFileNames ) = 0 then
    Exit;

  // GITLAK 2026-10-19: the host sees every dropped file first and may take the drop over.
  var lHandled := False;

  if Assigned( FOnFilesDropped ) then
    FOnFilesDropped( Self, AFileNames, lHandled );

  if lHandled then
    Exit;

  if IsSupportedExtension( ExtractFileExt( AFileNames[ 0 ] ) ) then
    LoadFromFile( AFileNames[ 0 ] )
  else
  begin
    FLastError := SUnsupportedFileFormat;

    DoImageError;

    Invalidate;
  end;

end;

function TgllCustomImageView.CanDragOut : Boolean;
begin

  Result := FEnableDragOut and FPictureLoaded and HasImage and ( not ( csDesigning in ComponentState ) );

end;

function TgllCustomImageView.DragOutBaseName : string;
begin

  Result := FDragOutFileName;

  // A name given with an image extension keeps only its stem: the extension follows the picture's format.
  if IsSupportedExtension( ExtractFileExt( Result ) ) then
    Result := ChangeFileExt( Result, '' );

  Result := Trim( Result );

  if Result = '' then
    Result := SDragOutDefaultName;

  Result := SafeDropFileName( Result );

end;

function TgllCustomImageView.SaveDragOutFile( const AFolder : string ) : string;
begin

  if ( not FPictureLoaded ) or ( not HasImage ) then
    Exit( '' );

  Result := TPath.Combine( AFolder, DragOutBaseName + GraphicFileExtension( Picture.Graphic ) );
  Picture.Graphic.SaveToFile( Result );

end;

procedure TgllCustomImageView.BeginDragOut;
begin

  FDragOutPending := False;
  EndPan;

  if not EnsureOle then
    Exit;

  // The last drag's file is left until now: a drop target may copy it after DoDragDrop has returned.
  DeleteDropFolder( FDragOutFolder );
  FDragOutFolder := NewDropFolder;

  var lFile := '';

  try
    ForceDirectories( FDragOutFolder );
    lFile := SaveDragOutFile( FDragOutFolder );
  except
    on E : Exception do
    begin
      FLastError := E.Message;

      DoImageError;

      Exit;
    end;
  end;

  if lFile = '' then
    Exit;

  MouseCapture := False;
  FDraggingOut := True;

  try
    DragFileOut( lFile );
  finally
    FDraggingOut := False;

    // DoDragDrop took the button-up: the control must not go on thinking the button is down.
    ControlState := ControlState - [ csLButtonDown, csClicked ];
  end;

end;

procedure TgllCustomImageView.WMContextMenu( var Message : TWMContextMenu );
begin

  if ( PopupMenu <> nil ) or ( not FShowContextMenu ) then
    inherited
  else if Assigned( FContextMenu ) then
  begin
    FMenuItemCopy.Enabled       := HasImage;
    FMenuItemCut.Enabled        := HasImage and ( not GetReadOnly );
    FMenuItemPaste.Enabled      := Clipboard.HasFormat( CF_BITMAP ) or
                                   Clipboard.HasFormat( CF_METAFILEPICT ) or
                                   Clipboard.HasFormat( CF_PICTURE );
    FMenuItemClear.Enabled      := HasImage and ( not GetReadOnly );
    FMenuItemLoad.Enabled       := ( not GetReadOnly );
    FMenuItemSave.Enabled       := HasImage;
    FMenuItemPrint.Enabled      := HasImage;
    FMenuItemRotateCW.Enabled   := HasImage;
    FMenuItemRotateCCW.Enabled  := HasImage;
    FMenuItemFlipH.Enabled      := HasImage and ( not GetReadOnly );
    FMenuItemFlipV.Enabled      := HasImage and ( not GetReadOnly );
    FMenuItemResetView.Enabled  := HasImage;
    FMenuItemAnimation.Enabled  := IsAnimatedGIF;
    FMenuItemAnimation.Visible  := IsAnimatedGIF;

    if FIsAnimating then
      FMenuItemAnimation.Caption := SMenuStopAnimation
    else
      FMenuItemAnimation.Caption := SMenuStartAnimation;

    FContextMenu.Popup( Message.XPos, Message.YPos );
  end;

end;

procedure TgllCustomImageView.SaveToFile( const FileName : string );
var
  lExt     : string;
  lHandler : TSaveFormatHandler;
begin

  if ( not FPictureLoaded ) or ( not HasImage ) then
    Exit;

  lExt := LowerCase( ExtractFileExt( FileName ) );

  try

    if FSaveFormatHandlers.TryGetValue( lExt, lHandler ) then
      lHandler( FileName, Picture.Graphic )
    else
      Picture.Graphic.SaveToFile( FileName );

  except
    on E : Exception do
    begin
      FLastError := E.Message;

      if Assigned( FOnImageError ) then
        FOnImageError( Self );
    end;
  end;

end;

{ TgllImageView }

constructor TgllImageView.Create( AOwner : TComponent );
begin

  inherited Create( AOwner );
  FPictureLoaded := True;

end;

end.
