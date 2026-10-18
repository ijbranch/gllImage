(* Copyright (c) 2026 Ian Branch. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style
 * license that can be found in the LICENSE file.
 *)
(*
  gllImage.Consts - gllImage Constants and Resource Strings
  Version: 1.0

  Description:
    Resource strings for localisation and constants for the TgllDBImage component.
    Separating these allows for easier translation and maintenance.
*)

unit gllImage.Consts;

interface

resourcestring
  // Context menu items
  /// <summary>Caption for the context menu Copy command.</summary>
  SMenuCopy = 'Copy';
  /// <summary>Caption for the context menu Cut command.</summary>
  SMenuCut = 'Cut';
  /// <summary>Caption for the context menu Paste command.</summary>
  SMenuPaste = 'Paste';
  /// <summary>Caption for the context menu Clear command.</summary>
  SMenuClear = 'Clear';
  /// <summary>Caption for the context menu Load from File command.</summary>
  SMenuLoadFromFile = 'Load from File...';
  /// <summary>Caption for the context menu Save to File command.</summary>
  SMenuSaveToFile = 'Save to File...';
  /// <summary>Caption for the context menu Print command.</summary>
  SMenuPrint = 'Print...';
  /// <summary>Caption for the context menu Rotate Clockwise command.</summary>
  SMenuRotateCW = 'Rotate Clockwise';
  /// <summary>Caption for the context menu Rotate Counter-Clockwise command.</summary>
  SMenuRotateCCW = 'Rotate Counter-Clockwise';
  /// <summary>Caption for the context menu Flip Horizontal command.</summary>
  SMenuFlipH = 'Flip Horizontal';
  /// <summary>Caption for the context menu Flip Vertical command.</summary>
  SMenuFlipV = 'Flip Vertical';
  /// <summary>Caption for the context menu Reset View command.</summary>
  SMenuResetView = 'Reset View';

  /// <summary>Caption for the context menu Zoom In command.</summary>
  SMenuZoomIn = 'Zoom In';
  /// <summary>Caption for the context menu Zoom Out command.</summary>
  SMenuZoomOut = 'Zoom Out';
  /// <summary>Caption for the context menu Start Animation command (animated GIF).</summary>
  SMenuStartAnimation = 'Start Animation';
  /// <summary>Caption for the context menu Stop Animation command (animated GIF).</summary>
  SMenuStopAnimation = 'Stop Animation';

  // Keyboard shortcut labels
  /// <summary>Localised label for the Ctrl+C shortcut (Copy).</summary>
  SShortcutCtrlC = 'Ctrl+C';
  /// <summary>Localised label for the Ctrl+X shortcut (Cut).</summary>
  SShortcutCtrlX = 'Ctrl+X';
  /// <summary>Localised label for the Ctrl+V shortcut (Paste).</summary>
  SShortcutCtrlV = 'Ctrl+V';
  /// <summary>Localised label for the Ctrl+Del shortcut (Clear).</summary>
  SShortcutCtrlDel = 'Ctrl+Del';
  /// <summary>Localised label for the Ctrl+P shortcut (Print).</summary>
  SShortcutCtrlP = 'Ctrl+P';

  // Error messages
  /// <summary>Error message when no database field is linked to the component.</summary>
  SNoDbFieldLinked = 'No database field linked';
  /// <summary>Error message when the linked field is not a BLOB field.</summary>
  SFieldNotBlobEDB = 'Linked field is not a BLOB field';
  /// <summary>Error message when the dataset cannot be placed into edit mode.</summary>
  SCannotEditRecord = 'Cannot edit record';
  /// <summary>Error message when a picture is loaded into a read-only viewer.</summary>
  SPictureReadOnly = 'The picture is read-only';
  /// <summary>Error message when an unsupported file format is selected.</summary>
  SUnsupportedFileFormat = 'Unsupported file format';
  /// <summary>Format string for image-too-large errors. Arguments: width, height, maxWidth, maxHeight.</summary>
  SImageDimensionsExceed = 'Image dimensions (%dx%d) exceed maximum allowed (%dx%d)';

  // File filters
  /// <summary>Open/Save dialog filter showing all supported image formats.</summary>
  SFilterAllImages = 'All Images|*.bmp;*.jpg;*.jpeg;*.png;*.gif;*.jxl;*.tif;*.tiff;*.ico;*.wmf;*.emf|';
  /// <summary>Open/Save dialog filter for JPEG XL files.</summary>
  SFilterJxl = 'JPEG XL (*.jxl)|*.jxl|';
  /// <summary>Open dialog filter for TIFF files.</summary>
  SFilterTiff = 'TIFF (*.tif;*.tiff)|*.tif;*.tiff|';
  /// <summary>Open/Save dialog filter for Windows bitmap files.</summary>
  SFilterBitmap = 'Bitmap (*.bmp)|*.bmp|';
  /// <summary>Open/Save dialog filter for JPEG files.</summary>
  SFilterJpeg = 'JPEG (*.jpg;*.jpeg)|*.jpg;*.jpeg|';
  /// <summary>Open/Save dialog filter for PNG files.</summary>
  SFilterPng = 'PNG (*.png)|*.png|';
  /// <summary>Open/Save dialog filter for GIF files.</summary>
  SFilterGif = 'GIF (*.gif)|*.gif|';
  /// <summary>Open/Save dialog filter for icon files.</summary>
  SFilterIcon = 'Icon (*.ico)|*.ico|';
  /// <summary>Open/Save dialog filter for Windows metafiles (WMF/EMF).</summary>
  SFilterMetafile = 'Metafile (*.wmf;*.emf)|*.wmf;*.emf|';
  /// <summary>Open/Save dialog filter for all files.</summary>
  SFilterAllFiles = 'All Files (*.*)|*.*';

  // Dialog titles
  /// <summary>Title for the Load Image dialog.</summary>
  SDialogLoadImage = 'Load Image';
  /// <summary>Title for the Save Image dialog.</summary>
  SDialogSaveImage = 'Save Image';

const
  /// <summary>Zoom step increment/decrement (10%)</summary>
  ZOOM_STEP = 0.1;

  /// <summary>Animation timer interval in milliseconds</summary>
  ANIMATION_INTERVAL = 100;

  /// <summary>Pan step for keyboard navigation in pixels</summary>
  PAN_STEP = 20;

implementation

end.
