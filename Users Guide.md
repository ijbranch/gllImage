# gllImage — User's Guide

How to use `TgllImageView` and `TgllDBImage`.  For building and troubleshooting, see [Help.md](Help.md).

---

## 1. Which control

| Need | Use |
|---|---|
| Show a picture from a file, a stream or code | `TgllImageView` |
| Show and edit the picture in a BLOB field | `TgllDBImage` (`DataSource`, `DataField`) |
| Replace a VCL `TDBImage` | `TgllDBImage`: change the class name in the `.pas` and `.dfm`; `Stretch` and `Proportional` are understood |
| Replace an old GITLAKDB `TGDBImage` | nothing to do: the old class name streams in as `TgllDBImage` (rename it when you next touch the form) |

Both share every property below.  `TgllDBImage` adds `DataSource`, `DataField`, `AutoDisplay`, `Field`, `LoadPicture`, `LoadPictureAsync`, `AsyncLoading` and `OnLoadCustomImage`.

## 2. Showing the picture

| Property | Effect |
|---|---|
| `FitToWindow` | Scale to the control both ways, aspect kept.  The usual choice for a viewer. |
| `ShrinkToFit` / `ZoomToFit` | The two halves of `FitToWindow`: shrink a larger picture / enlarge a smaller one. |
| `MaintainAspectRatio` | Off: a fitted picture is stretched to fill the control. |
| `Stretch` / `Proportional` | `TDBImage` compatibility: set the three above as `TDBImage` would.  Not stored. |
| `Center` | Centre a picture smaller than the control (default True). |
| `ZoomFactor`, `MinZoom`, `MaxZoom` | The zoom when not fitting (1.0 = 100%).  Lower `MinZoom` (for example 0.02) for very large photos. |
| `ScrollBars` | Show scroll bars while the zoomed picture is larger than the control.  The wheel then scrolls (Shift+wheel horizontally) and Ctrl+wheel zooms. |
| `EnablePan` | Drag the picture with the mouse when it is larger than the control. |
| `Rotation` | Display-only rotation (`ro0`, `ro90`, `ro180`, `ro270`); the stored picture is untouched. |
| `TransparentMode`, `CheckerSize`, `CheckerColour1/2` | Checkerboard behind transparent areas. |
| `NoPicture` | Text shown while there is no picture. |
| `ShowErrorState` | Draw a failed load (with `LastError`) in the control. |

**Zooming from a fitted picture.**  `ZoomIn`, `ZoomOut` and `ZoomBy( factor )` first take the scale the picture is shown at, so a step continues from what is on screen.  `ZoomBy( 1.25 )` and `ZoomBy( 0.8 )` give 25% steps; `ZoomIn` / `ZoomOut` step by 10 points.  `ResetZoom` returns to 100%; `ResetView` also clears the pan and rotation.

**Panning in code.**  `PanBy( dx, dy )` moves the picture within the same limits as a drag; `PanOffset` and `ScrollPosition` report where it is.

## 3. Changing the picture

| Method | Effect |
|---|---|
| `RotatePicture( angle )` | Turns the pixels, **keeping the format** (JPEG stays JPEG with its quality, JPEG XL stays JPEG XL with its settings, PNG and BMP stay lossless).  It turns the picture **as seen**: a display `Rotation` already applied (for example from an EXIF orientation) is baked in too.  `RotatePicture( ro0 )` bakes in just the display rotation. |
| `FlipHorizontal` / `FlipVertical` | Mirror the pixels, format kept. |
| `LoadFromFile` | `TgllImageView`: into its picture.  `TgllDBImage`: the file's bytes into the field **exactly as they are** (no re-encode), so a JPEG XL is stored as the file was. |
| `SaveToFile` | By extension: `.jpg`, `.png`, `.bmp`, `.gif`, `.jxl` convert as needed; any other name writes the picture's own format.  `RegisterSaveFormat` adds an extension. |
| `CopyToClipboard`, `CutToClipboard`, `PasteFromClipboard` | As in `TDBImage`. |
| `Print`, `GetThumbnail` | Print fitted and centred; make a thumbnail bitmap (the caller frees it). |

Every change goes through `CanModify`: nothing changes while `ReadOnly` is True.  In `TgllDBImage` a change puts the dataset into edit and marks the record modified; **Post** writes the picture.

**A form that changes the picture itself** (its own Rotate button, say) while the control is `ReadOnly` to the user: set `ReadOnly := False`, `Edit`, change, `Post`, and only then `ReadOnly := True`.  Making the control read-only ends the data link's editing state and drops its "modified" flag, so setting it back before the Post loses the change.

## 4. Mouse, keyboard, menu and drag-and-drop

- **Keys:** Ctrl + / Ctrl − zoom, Ctrl+0 resets the zoom, Ctrl+R / Ctrl+L rotate the display, Ctrl+H / Ctrl+J flip, Ctrl+P prints, the arrows pan; Ctrl+C / X / V / Del and Shift/Ctrl+Insert / Delete are the clipboard.  `TgllDBImage` adds Enter (load the picture when `AutoDisplay` is off) and Esc (back to the field's value).
- **Context menu:** built in, unless `PopupMenu` is assigned; `ShowContextMenu := False` turns it off.
- **Dropping files:** `EnableDragDrop` (default True) accepts files from Explorer and **virtual files**: an Outlook attachment, an image dragged out of a web browser or a zip folder.  A virtual file is written to a temporary folder for the length of the drop and deleted afterwards, so a handler that keeps it must copy it.  `OnFilesDropped` receives every dropped file first; set `Handled` to validate, convert or add them yourself.  Left unhandled, the control loads the first supported file.  A read-only or disabled control shows the no-drop cursor.  A form that puts its own drop-target component on the control should set `EnableDragDrop := False` (a window has one OLE drop target).
- **Dragging the picture out:** `EnableDragOut` (default False) lets the picture be dragged to Explorer, an e-mail or another program as a file.  The drag starts with the left button when the picture cannot be panned, and with **Ctrl** held when it can (a plain drag then pans).  The file is named `DragOutFileName` (default `Picture`; an image extension given is replaced) with the extension of the picture's format.  `TgllImageView` saves the picture in its own format; `TgllDBImage` writes the field's bytes exactly as stored, and a rotation or flip not yet posted is written to the field first, as Post would.  It is always a copy: the control's picture is untouched.

## 5. Events

`OnImageLoaded`, `OnImageError` (read `LastError`), `OnZoomChanged`, `OnPanChanged`, `OnRotated`, `OnFlipped`, `OnFilesDropped`; `TgllDBImage` adds `OnLoadCustomImage` for a format nothing else decodes.

## 6. Formats

Detection is by the bytes, not the file name: BMP, JPEG, PNG, GIF, ICO, WMF, EMF, TIFF (through Windows' WIC) and JPEG XL by signature, then any `TGraphic` registered with `TPicture`, then a loader registered with `TgllImageFormatRegistry`, then `OnLoadCustomImage`.  A BLOB written by an old `TDBImage` (an 8-byte header before a bitmap) is read too.

`ImageFormat` names what is shown: `JPEG`, `PNG`, `GIF`, `JPEG XL`, `TIFF`, `Bitmap`, `Icon`, `Metafile`.
