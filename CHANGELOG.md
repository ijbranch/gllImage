# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- `TgllImageView`, the stand-alone viewer (the `TImage` counterpart), and `TgllCustomImageView`, the base both controls share, so the viewer and the data-aware control never drift apart (2026-10-19) — `gllImage.View.pas`
- JPEG XL: detected by signature and decoded by LibJxl's `TJxlImage`; `SaveToFile` writes `.jxl`; LibJxl is the one dependency beyond the RTL and VCL.  Formats registered with `TPicture` are tried when no signature matches (2026-10-19) — `gllImage.Utils.pas`, `gllImage.View.pas`
- Scroll bars (`ScrollBars`): shown while the zoomed picture overhangs the control; the wheel scrolls with them (Shift+wheel horizontally) and Ctrl+wheel zooms (2026-10-19) — `gllImage.View.pas`
- `RotatePicture`: turns the pixels as seen (display rotation included) and keeps the format; `ZoomBy`; `PanBy`; `ScrollPosition`; `ShowContextMenu`; `OnFilesDropped` (every dropped file, `Handled` to take the drop over) (2026-10-19) — `gllImage.View.pas`
- `Stretch` / `Proportional` (not stored), so a VCL `TDBImage` form converts by its class name; `RegisterClassAlias( TgllDBImage, 'TGDBImage' )` for forms that still name the GITLAKDB class (2026-10-19) — `gllImage.View.pas`, `gllImage.DB.pas`
- Packages `gllImageR` / `gllImageD` (Win32 + Win64), the group project, the DUnitX suite, the demo with two JPEG XL samples, and the documents (2026-10-19) — `gllImageR.dpk`, `gllImageD.dpk`, `gllImage.groupproj`, `gllImage.Consts.pas`, `gllImage.Register.pas`, `gllImageTests.dpr`, `TestGllImage.pas`, `gllImageDemo.dpr`, `Demo.Main.pas`, `Demo.Main.dfm`, `Sample-Landscape.jxl`, `Sample-Portrait.jxl`, `README.md`, `Help.md`, `Users Guide.md`, `.gitignore`

### Changed
- The documents are written for outside readers: libjxl-delphi linked instead of local paths, the one place the tests and the demo expect it named, internal tool names dropped, and a note on how gllImage was developed (2026-10-19) — `README.md`, `Help.md`
- Licensed under BSD 3-Clause (Ian, 2026-10-19), matching libjxl and libjxl-delphi: `LICENSE` added (crediting the GDBImage / EDBImage originals) and every source file carries the BSD header in place of the proprietary one (2026-10-19) — `LICENSE`, `README.md`, `gllImage.Consts.pas`, `gllImage.DB.pas`, `gllImage.Utils.pas`, `gllImage.View.pas`, `gllImage.Register.pas`, `gllImageR.dpk`, `gllImageD.dpk`, `TestGllImage.pas`, `gllImageTests.dpr`, `Demo.Main.pas`, `gllImageDemo.dpr`
- `TRotationAngle`'s values are `ro0`, `ro90`, `ro180`, `ro270` (were `ra0` .. `ra270`) (2026-10-19) — `gllImage.Utils.pas`, `gllImage.View.pas`, `gllImage.DB.pas`, `TestGllImage.pas`, `Demo.Main.pas`, `README.md`, `Users Guide.md`
- The source headers no longer carry a former third-party licence grant; the rest of each header is unchanged (2026-10-19) — `gllImage.Consts.pas`, `gllImage.DB.pas`, `gllImage.Utils.pas`, `gllImage.View.pas`
- Moved out of GITLAKDB (`gdbximage`, `gdbximageutils`, `gdbximageconsts`): it uses nothing of the engine.  `TGDBImage` is now `TgllDBImage`, the units `gllImage.*`, the palette page **gllImage** (2026-10-19) — all units
- Flips keep the picture's format: a flipped JPEG used to become a bitmap and so was stored as BMP.  Rotation and flips re-encode with the old graphic's settings (JPEG quality, JPEG XL lossless / distance / effort) (2026-10-19) — `gllImage.Utils.pas` (`ReplaceGraphicKeepingFormat`)
- `ZoomIn`, `ZoomOut` and `ZoomBy` on a fitted picture continue from the scale shown; they used to change nothing visible (2026-10-19) — `gllImage.View.pas`

### Removed
- The optional GraphicEx support: TIFF decodes through the VCL's `TWICImage` (2026-10-19) — `gllImage.Utils.pas`

### Fixed
- `TgllDBImage.LoadFromFile` re-encoded the file on Post: it marked the record modified after writing the file's bytes, so `UpdateData` replaced them with the picture re-encoded (a lossy second generation for JPEG XL, a re-compressed PNG).  The bytes are now stored as they are (2026-10-19) — `gllImage.DB.pas`
- Pan limits ignored the display rotation (a picture turned 90 degrees could not be panned along its long side), allowed a symmetrical range for an uncentred picture (half of it unreachable, an empty band draggable into view), and kept a stale offset when the picture went (2026-10-19) — `gllImage.View.pas` (`ClampPanOffset`)
- With `MaintainAspectRatio` off a fitted picture was drawn at 1:1 instead of stretched to the control (2026-10-19) — `gllImage.View.pas` (`Paint`)
- A BLOB written by the VCL's `TDBImage` (an 8-byte header before the bitmap) was reported as an unknown format (2026-10-19) — `gllImage.Utils.pas` (`StripLegacyGraphicHeader`)
- `SaveToFile` with a `.jxl` name wrote the graphic's own format under that name (2026-10-19) — `gllImage.View.pas`
- `ImageFormat` called a JPEG XL "Bitmap" (`TJxlImage` descends from `TBitmap`) (2026-10-19) — `gllImage.View.pas`
- The palette icon was named `TEDBIMAGE` (the ElevateDB-era class), so `TGDBImage` never had one; both controls now do (2026-10-19) — `gllImage.Register.dcr`
- Assigning a picture before the control had a parent raised "has no parent window" (the layout read `ClientWidth`) (2026-10-19) — `gllImage.View.pas` (`GetViewClientSize`)
