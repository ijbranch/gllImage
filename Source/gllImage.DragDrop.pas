(* Copyright (c) 2026 Ian Branch. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style
 * license that can be found in the LICENSE file.
 *)
(*
  gllImage.DragDrop - OLE drag and drop for the gllImage viewers
  Version: 1.0

  Description:
    The OLE side of drag and drop, kept apart from the controls so it can be tested without a window:
    - TgllImageDropTarget accepts files dropped from Explorer (CF_HDROP) and "virtual" files that exist only in
      the source program (an Outlook attachment, an image dragged out of a web browser or a zip folder), offered
      as FileGroupDescriptorW plus FileContents.  Virtual files are written to a temporary folder for the length
      of the drop.
    - TgllImageDropSource, CreateFileDataObject and DragFileOut drag a picture out as a file, through the shell's
      own data object, so every drop target that takes files from Explorer takes it.
*)

unit gllImage.DragDrop;

interface

uses
  Winapi.Windows, Winapi.ActiveX, Winapi.ShlObj,
  System.SysUtils, System.Classes, System.Types;

type
  /// <summary>Asked on every drag movement whether a drop would be taken now.</summary>
  /// <returns>True when the files being dragged may be dropped.</returns>
  TgllDropCanAccept = reference to function : Boolean;

  /// <summary>Receives the files of a drop.</summary>
  /// <param name="AFileNames">Every dropped file; a virtual file's temporary copy exists only during the call.</param>
  TgllDropFilesProc = reference to procedure( const AFileNames : TArray<string> );

  /// <summary>
  ///   An OLE drop target that takes files: real ones (CF_HDROP) and virtual ones (FileGroupDescriptorW with
  ///   FileContents), and shows the shell's drag image over its window.
  /// </summary>
  /// <remarks>The only effect offered is a copy: a drop never moves or deletes the source's file.</remarks>
  TgllImageDropTarget = class( TInterfacedObject, IDropTarget )
  private
    /// <summary>The window registered with RegisterDragDrop; the drag image is drawn over it.</summary>
    FWindow : HWND;
    /// <summary>Asked whether a drop would be taken now.</summary>
    FCanAccept : TgllDropCanAccept;
    /// <summary>Receives the files of a drop.</summary>
    FOnDrop : TgllDropFilesProc;
    /// <summary>The shell's drag-image helper; nil when it cannot be created.</summary>
    FHelper : IDropTargetHelper;
    /// <summary>True while the data being dragged holds files.</summary>
    FHasFiles : Boolean;
    /// <summary>The effect to report for a drag: a copy when files are dragged, the source allows a copy and
    /// FCanAccept agrees; otherwise none.</summary>
    /// <param name="AAllowed">The effects the source allows.</param>
    /// <returns>DROPEFFECT_COPY or DROPEFFECT_NONE.</returns>
    function EffectFor( AAllowed : Longint ) : Longint;
  public
    /// <summary>Creates the target for a window.</summary>
    /// <param name="AWindow">The window that will be registered with RegisterDragDrop.</param>
    /// <param name="ACanAccept">Asked whether a drop would be taken now; nil accepts every file drop.</param>
    /// <param name="AOnDrop">Receives the files of a drop.</param>
    constructor Create( AWindow : HWND; const ACanAccept : TgllDropCanAccept; const AOnDrop : TgllDropFilesProc );
    /// <summary>Starts a drag over the window: notes whether files are being dragged.</summary>
    /// <param name="dataObj">The data being dragged.</param>
    /// <param name="grfKeyState">The modifier keys and mouse buttons held.</param>
    /// <param name="pt">The cursor position, in screen coordinates.</param>
    /// <param name="dwEffect">In: the effects the source allows; out: the effect a drop would have.</param>
    /// <returns>S_OK.</returns>
    function DragEnter( const dataObj : IDataObject; grfKeyState : Longint; pt : TPoint;
                        var dwEffect : Longint ) : HResult; stdcall;
    /// <summary>Reports the effect a drop at the cursor would have.</summary>
    /// <param name="grfKeyState">The modifier keys and mouse buttons held.</param>
    /// <param name="pt">The cursor position, in screen coordinates.</param>
    /// <param name="dwEffect">In: the effects the source allows; out: the effect a drop would have.</param>
    /// <returns>S_OK.</returns>
    function DragOver( grfKeyState : Longint; pt : TPoint; var dwEffect : Longint ) : HResult; stdcall;
    /// <summary>Ends a drag that left the window.</summary>
    /// <returns>S_OK.</returns>
    function DragLeave : HResult; stdcall;
    /// <summary>Takes a drop: hands its files to the drop procedure, then deletes the temporary copies of any
    /// virtual files.</summary>
    /// <remarks>An exception from the drop procedure goes to the application's exception handler: it must not
    /// cross back into the source program.</remarks>
    /// <param name="dataObj">The data dropped.</param>
    /// <param name="grfKeyState">The modifier keys and mouse buttons held.</param>
    /// <param name="pt">The cursor position, in screen coordinates.</param>
    /// <param name="dwEffect">In: the effects the source allows; out: the effect of the drop.</param>
    /// <returns>S_OK.</returns>
    function Drop( const dataObj : IDataObject; grfKeyState : Longint; pt : TPoint;
                   var dwEffect : Longint ) : HResult; stdcall;
  end;

  /// <summary>An OLE drop source for a drag started with the left mouse button.</summary>
  TgllImageDropSource = class( TInterfacedObject, IDropSource )
  public
    /// <summary>Cancels the drag on Escape and drops when the left button is released.</summary>
    /// <param name="fEscapePressed">True when Escape was pressed since the last call.</param>
    /// <param name="grfKeyState">The modifier keys and mouse buttons held.</param>
    /// <returns>DRAGDROP_S_CANCEL, DRAGDROP_S_DROP or S_OK (go on dragging).</returns>
    function QueryContinueDrag( fEscapePressed : BOOL; grfKeyState : Longint ) : HResult; stdcall;
    /// <summary>Leaves the cursor to OLE.</summary>
    /// <param name="dwEffect">The effect the target reports.</param>
    /// <returns>DRAGDROP_S_USEDEFAULTCURSORS.</returns>
    function GiveFeedback( dwEffect : Longint ) : HResult; stdcall;
  end;

/// <summary>Tells whether a data object holds files: real ones (CF_HDROP) or virtual ones (FileGroupDescriptorW).</summary>
/// <param name="AData">The data object.</param>
/// <returns>True when ExtractDroppedFiles can take files from it.</returns>
function HasDroppableFiles( const AData : IDataObject ) : Boolean;

/// <summary>Returns the files a data object holds.</summary>
/// <remarks>
///   Real files (CF_HDROP) are returned by name.  Without them, virtual files (FileGroupDescriptorW with
///   FileContents, from an HGLOBAL or a stream) are written to ATempFolder, created only when one is written, under
///   their own names made safe for the file system and unique; folders among them are skipped.  The caller deletes
///   ATempFolder (DeleteDropFolder) once the files have been used.
/// </remarks>
/// <param name="AData">The data object.</param>
/// <param name="ATempFolder">Where virtual files are written.</param>
/// <returns>The files, in the order the data object lists them; empty when it holds none.</returns>
function ExtractDroppedFiles( const AData : IDataObject; const ATempFolder : string ) : TArray<string>;

/// <summary>Returns the shell's data object for a file: what Explorer offers when the file is dragged from it.</summary>
/// <param name="AFileName">The full path of an existing file.</param>
/// <returns>The data object, or nil when the shell cannot provide one.</returns>
function CreateFileDataObject( const AFileName : string ) : IDataObject;

/// <summary>Drags a file out to wherever the user drops it, as a copy; returns when the drag ends.</summary>
/// <remarks>Needs OLE initialised on the calling thread (OleInitialize).  Call it from a mouse-move with the left
/// button held.  The file must stay where it is after the call: a drop target may copy it later, on a thread of
/// its own.</remarks>
/// <param name="AFileName">The full path of the file.</param>
/// <returns>DROPEFFECT_COPY when the file was dropped; DROPEFFECT_NONE when the drag was cancelled or could not
/// start.</returns>
function DragFileOut( const AFileName : string ) : Longint;

/// <summary>Returns a new, unique folder name under %TEMP%\gllImage for one drop or drag; the folder is not created.</summary>
/// <returns>The folder's full path.</returns>
function NewDropFolder : string;

/// <summary>Deletes a folder made for one drop or drag, and the files in it; a file still in use is left.</summary>
/// <param name="AFolder">The folder; nothing happens when it is empty or does not exist.</param>
procedure DeleteDropFolder( const AFolder : string );

/// <summary>Makes a name a source program offered safe as a file name: the name part only, characters Windows
/// does not allow replaced by '_', no trailing dots or spaces, no device name.</summary>
/// <param name="AName">The offered name, possibly with a relative path.</param>
/// <returns>The file name; 'Dropped' when nothing usable is left.</returns>
function SafeDropFileName( const AName : string ) : string;

implementation

uses
  Winapi.ShellAPI,
  System.IOUtils, System.Generics.Collections;

const
  /// <summary>Name used when a source offers nothing usable as a file name.</summary>
  DEFAULT_DROP_NAME = 'Dropped';
  /// <summary>Longest file name written for a virtual file, leaving room for the folder and a " (n)" suffix.</summary>
  MAX_DROP_NAME = 180;
  /// <summary>Bytes read from a FileContents stream at a time.</summary>
  STREAM_CHUNK = 65536;

var
  /// <summary>Clipboard format FileGroupDescriptorW, registered on first use.</summary>
  CFFileDescriptorW : TClipFormat = 0;
  /// <summary>Clipboard format FileContents, registered on first use.</summary>
  CFFileContents : TClipFormat = 0;

/// <summary>Registers the virtual-file clipboard formats once.</summary>
procedure EnsureFormats;
begin

  if CFFileDescriptorW = 0 then
    CFFileDescriptorW := RegisterClipboardFormat( CFSTR_FILEDESCRIPTORW );

  if CFFileContents = 0 then
    CFFileContents := RegisterClipboardFormat( CFSTR_FILECONTENTS );

end;

/// <summary>Fills a FORMATETC for content data.</summary>
/// <param name="AFormat">The clipboard format.</param>
/// <param name="AIndex">The item index (FileContents), or -1 for all.</param>
/// <param name="ATymed">The storage media accepted.</param>
/// <returns>The FORMATETC.</returns>
function FormatOf( AFormat : TClipFormat; AIndex, ATymed : Longint ) : TFormatEtc;
begin

  Result.cfFormat := AFormat;
  Result.ptd      := nil;
  Result.dwAspect := DVASPECT_CONTENT;
  Result.lindex   := AIndex;
  Result.tymed    := ATymed;

end;

function HasDroppableFiles( const AData : IDataObject ) : Boolean;
begin

  EnsureFormats;

  Result := Assigned( AData ) and
            ( ( AData.QueryGetData( FormatOf( CF_HDROP, -1, TYMED_HGLOBAL ) ) = S_OK ) or
              ( AData.QueryGetData( FormatOf( CFFileDescriptorW, -1, TYMED_HGLOBAL ) ) = S_OK ) );

end;

/// <summary>Returns the real files of a CF_HDROP.</summary>
/// <param name="AData">The data object.</param>
/// <param name="AFiles">Receives the files.</param>
/// <returns>True when the data object holds CF_HDROP.</returns>
function ReadHDrop( const AData : IDataObject; out AFiles : TArray<string> ) : Boolean;
var
  lMedium : TStgMedium;
begin

  AFiles := nil;
  Result := Succeeded( AData.GetData( FormatOf( CF_HDROP, -1, TYMED_HGLOBAL ), lMedium ) );

  if not Result then
    Exit;

  try
    var lDrop  := HDROP( lMedium.hGlobal );
    var lCount := DragQueryFile( lDrop, $FFFFFFFF, nil, 0 );

    SetLength( AFiles, lCount );

    for var i := 0 to Integer( lCount ) - 1 do
    begin
      var lName : string;

      SetLength( lName, DragQueryFile( lDrop, i, nil, 0 ) );

      if lName <> '' then
        DragQueryFile( lDrop, i, PChar( lName ), Length( lName ) + 1 );

      AFiles[ i ] := lName;
    end;
  finally
    ReleaseStgMedium( lMedium );
  end;

end;

function SafeDropFileName( const AName : string ) : string;
const
  DEVICE_NAMES : array[ 0..21 ] of string = ( 'CON', 'PRN', 'AUX', 'NUL', 'COM1', 'COM2', 'COM3', 'COM4', 'COM5',
    'COM6', 'COM7', 'COM8', 'COM9', 'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9' );
begin

  // A virtual file may carry a relative path ("Folder\Photo.jpg", or "/" from a browser): keep the name only.
  // The forbidden characters go first: ExtractFileName takes ':' as a drive separator ("photo:1.png" -> "1.png").
  Result := StringReplace( AName, '/', '\', [ rfReplaceAll ] );

  for var i := 1 to Length( Result ) do
    if ( Result[ i ] < ' ' ) or CharInSet( Result[ i ], [ '<', '>', ':', '"', '|', '?', '*' ] ) then
      Result[ i ] := '_';

  Result := ExtractFileName( Result );

  Result := TrimRight( Result );

  while ( Result <> '' ) and CharInSet( Result[ Length( Result ) ], [ '.', ' ' ] ) do
    SetLength( Result, Length( Result ) - 1 );

  if Length( Result ) > MAX_DROP_NAME then
  begin
    var lExt := ExtractFileExt( Result );

    if Length( lExt ) > 16 then
      lExt := '';

    Result := Copy( Result, 1, MAX_DROP_NAME - Length( lExt ) ) + lExt;
  end;

  for var lDevice in DEVICE_NAMES do
    if SameText( ChangeFileExt( Result, '' ), lDevice ) then
    begin
      Result := '_' + Result;
      Break;
    end;

  if Result = '' then
    Result := DEFAULT_DROP_NAME;

end;

/// <summary>Returns a path in a folder for a file name, adding " (2)", " (3)" ... while the name is taken.</summary>
/// <param name="AFolder">The folder.</param>
/// <param name="AName">The file name.</param>
/// <returns>A path no file has yet.</returns>
function UniquePath( const AFolder, AName : string ) : string;
begin

  Result := TPath.Combine( AFolder, AName );

  var lBase := ChangeFileExt( AName, '' );
  var lExt  := ExtractFileExt( AName );
  var lNo   := 1;

  while FileExists( Result ) do
  begin
    Inc( lNo );
    Result := TPath.Combine( AFolder, Format( '%s (%d)%s', [ lBase, lNo, lExt ] ) );
  end;

end;

/// <summary>Writes one virtual file's contents to a file.</summary>
/// <param name="AData">The data object.</param>
/// <param name="AIndex">The item's index in the file group descriptor.</param>
/// <param name="ASize">The item's size from its descriptor, or -1 when the descriptor gives none.</param>
/// <param name="AFileName">The file to write.</param>
/// <returns>True when the contents were written.</returns>
function WriteFileContents( const AData : IDataObject; AIndex : Integer; ASize : Int64;
                            const AFileName : string ) : Boolean;
var
  lMedium : TStgMedium;
begin

  Result := Succeeded( AData.GetData( FormatOf( CFFileContents, AIndex, TYMED_HGLOBAL or TYMED_ISTREAM ), lMedium ) );

  if not Result then
    Exit;

  try
    var lOut := TFileStream.Create( AFileName, fmCreate );

    try
      case lMedium.tymed of
        TYMED_HGLOBAL :
          begin
            // GlobalSize may round the block up, so the descriptor's size wins when it is given.
            var lSize := Int64( GlobalSize( lMedium.hGlobal ) );

            if ( ASize >= 0 ) and ( ASize < lSize ) then
              lSize := ASize;

            var lPtr := GlobalLock( lMedium.hGlobal );

            try
              if ( lPtr <> nil ) and ( lSize > 0 ) then
                lOut.WriteBuffer( lPtr^, lSize );
            finally
              GlobalUnlock( lMedium.hGlobal );
            end;
          end;

        TYMED_ISTREAM :
          begin
            var lStream := IStream( lMedium.stm );
            var lBuffer : TBytes;
            var lNewPos : LargeUInt;
            var lRead   : FixedUInt;

            SetLength( lBuffer, STREAM_CHUNK );

            // Some sources hand over a stream left at its end.
            lStream.Seek( 0, STREAM_SEEK_SET, lNewPos );

            repeat
              lRead := 0;

              if Failed( lStream.Read( @lBuffer[ 0 ], STREAM_CHUNK, @lRead ) ) then
                lRead := 0;

              if lRead > 0 then
                lOut.WriteBuffer( lBuffer[ 0 ], lRead );
            until lRead = 0;
          end;
      else
        Result := False;
      end;
    finally
      lOut.Free;
    end;
  finally
    ReleaseStgMedium( lMedium );
  end;

  if not Result then
    System.SysUtils.DeleteFile( AFileName );

end;

/// <summary>Writes the virtual files of a FileGroupDescriptorW to a folder.</summary>
/// <param name="AData">The data object.</param>
/// <param name="ATempFolder">Where the files are written; created when the first one is.</param>
/// <returns>The files written.</returns>
function ReadVirtualFiles( const AData : IDataObject; const ATempFolder : string ) : TArray<string>;
var
  lMedium : TStgMedium;
begin

  Result := nil;

  if Failed( AData.GetData( FormatOf( CFFileDescriptorW, -1, TYMED_HGLOBAL ), lMedium ) ) then
    Exit;

  try
    var lGroup := PFileGroupDescriptorW( GlobalLock( lMedium.hGlobal ) );

    if lGroup = nil then
      Exit;

    try
      var lList := TList<string>.Create;

      try
        for var i := 0 to Integer( lGroup.cItems ) - 1 do
        begin
          // fgd is declared [ 0..0 ]: index past it by address.
          var lDesc := PFileDescriptorW( PByte( @lGroup.fgd[ 0 ] ) + i * SizeOf( TFileDescriptorW ) );

          if ( ( lDesc.dwFlags and FD_ATTRIBUTES ) <> 0 ) and
             ( ( lDesc.dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY ) <> 0 ) then
            Continue;

          var lSize : Int64 := -1;

          if ( lDesc.dwFlags and FD_FILESIZE ) <> 0 then
            lSize := ( Int64( lDesc.nFileSizeHigh ) shl 32 ) or lDesc.nFileSizeLow;

          ForceDirectories( ATempFolder );

          var lFile := UniquePath( ATempFolder, SafeDropFileName( lDesc.cFileName ) );

          if WriteFileContents( AData, i, lSize, lFile ) then
            lList.Add( lFile );
        end;

        Result := lList.ToArray;
      finally
        lList.Free;
      end;
    finally
      GlobalUnlock( lMedium.hGlobal );
    end;
  finally
    ReleaseStgMedium( lMedium );
  end;

end;

function ExtractDroppedFiles( const AData : IDataObject; const ATempFolder : string ) : TArray<string>;
begin

  Result := nil;

  if not Assigned( AData ) then
    Exit;

  EnsureFormats;

  if not ReadHDrop( AData, Result ) then
    Result := ReadVirtualFiles( AData, ATempFolder );

end;

function CreateFileDataObject( const AFileName : string ) : IDataObject;
var
  lPidl   : PItemIDList;
  lChild  : PItemIDList;
  lFolder : Pointer;
  lAttrs  : DWORD;
begin

  Result := nil;
  lAttrs := 0;

  if Failed( SHParseDisplayName( PChar( AFileName ), nil, lPidl, 0, lAttrs ) ) then
    Exit;

  try
    lFolder := nil;

    if Succeeded( SHBindToParent( lPidl, IShellFolder, lFolder, lChild ) ) then
    begin
      // SHBindToParent hands over a reference: take it without adding another.
      var lShellFolder : IShellFolder;

      Pointer( lShellFolder ) := lFolder;

      if Failed( lShellFolder.GetUIObjectOf( 0, 1, lChild, IDataObject, nil, Result ) ) then
        Result := nil;
    end;
  finally
    CoTaskMemFree( lPidl );
  end;

end;

function DragFileOut( const AFileName : string ) : Longint;
begin

  Result := DROPEFFECT_NONE;

  var lData := CreateFileDataObject( AFileName );

  if not Assigned( lData ) then
    Exit;

  var lSource : IDropSource := TgllImageDropSource.Create;
  var lEffect : Longint     := DROPEFFECT_NONE;

  if DoDragDrop( lData, lSource, DROPEFFECT_COPY, lEffect ) = DRAGDROP_S_DROP then
    Result := lEffect and DROPEFFECT_COPY;

end;

function NewDropFolder : string;
begin

  Result := TPath.Combine( TPath.Combine( TPath.GetTempPath, 'gllImage' ), TGUID.NewGuid.ToString );

end;

procedure DeleteDropFolder( const AFolder : string );
begin

  if ( AFolder = '' ) or ( not TDirectory.Exists( AFolder ) ) then
    Exit;

  // The folder is flat (one file per drop or drag).  A file a drop target still has open stays; the next clean-up
  // of the same folder, or Windows' own temp clean-up, removes it.
  for var lFile in TDirectory.GetFiles( AFolder ) do
    System.SysUtils.DeleteFile( lFile );

  RemoveDir( AFolder );

end;

{ TgllImageDropTarget }

constructor TgllImageDropTarget.Create( AWindow : HWND; const ACanAccept : TgllDropCanAccept;
                                        const AOnDrop : TgllDropFilesProc );
begin

  inherited Create;

  FWindow    := AWindow;
  FCanAccept := ACanAccept;
  FOnDrop    := AOnDrop;

  // Without the helper the drag still works; only the picture Explorer drags along disappears over the window.
  if Failed( CoCreateInstance( CLSID_DragDropHelper, nil, CLSCTX_INPROC_SERVER, IDropTargetHelper, FHelper ) ) then
    FHelper := nil;

end;

function TgllImageDropTarget.EffectFor( AAllowed : Longint ) : Longint;
begin

  if FHasFiles and ( ( AAllowed and DROPEFFECT_COPY ) <> 0 ) and ( ( not Assigned( FCanAccept ) ) or FCanAccept() ) then
    Result := DROPEFFECT_COPY
  else
    Result := DROPEFFECT_NONE;

end;

function TgllImageDropTarget.DragEnter( const dataObj : IDataObject; grfKeyState : Longint; pt : TPoint;
                                        var dwEffect : Longint ) : HResult;
begin

  FHasFiles := HasDroppableFiles( dataObj );
  dwEffect  := EffectFor( dwEffect );

  if Assigned( FHelper ) then
    FHelper.DragEnter( FWindow, dataObj, pt, dwEffect );

  Result := S_OK;

end;

function TgllImageDropTarget.DragOver( grfKeyState : Longint; pt : TPoint; var dwEffect : Longint ) : HResult;
begin

  dwEffect := EffectFor( dwEffect );

  if Assigned( FHelper ) then
    FHelper.DragOver( pt, dwEffect );

  Result := S_OK;

end;

function TgllImageDropTarget.DragLeave : HResult;
begin

  FHasFiles := False;

  if Assigned( FHelper ) then
    FHelper.DragLeave;

  Result := S_OK;

end;

function TgllImageDropTarget.Drop( const dataObj : IDataObject; grfKeyState : Longint; pt : TPoint;
                                   var dwEffect : Longint ) : HResult;
begin

  FHasFiles := HasDroppableFiles( dataObj );
  dwEffect  := EffectFor( dwEffect );

  if Assigned( FHelper ) then
    FHelper.Drop( dataObj, pt, dwEffect );

  FHasFiles := False;
  Result    := S_OK;

  if dwEffect = DROPEFFECT_NONE then
    Exit;

  var lFolder := NewDropFolder;

  try
    try
      var lFiles := ExtractDroppedFiles( dataObj, lFolder );

      if Length( lFiles ) = 0 then
        dwEffect := DROPEFFECT_NONE
      else if Assigned( FOnDrop ) then
        FOnDrop( lFiles );
    except
      dwEffect := DROPEFFECT_NONE;

      if Assigned( ApplicationHandleException ) then
        ApplicationHandleException( Self );
    end;
  finally
    DeleteDropFolder( lFolder );
  end;

end;

{ TgllImageDropSource }

function TgllImageDropSource.QueryContinueDrag( fEscapePressed : BOOL; grfKeyState : Longint ) : HResult;
begin

  if fEscapePressed then
    Result := DRAGDROP_S_CANCEL
  else if ( grfKeyState and MK_LBUTTON ) = 0 then
    Result := DRAGDROP_S_DROP
  else
    Result := S_OK;

end;

function TgllImageDropSource.GiveFeedback( dwEffect : Longint ) : HResult;
begin

  Result := DRAGDROP_S_USEDEFAULTCURSORS;

end;

end.
