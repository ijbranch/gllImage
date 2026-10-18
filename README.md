# gllImage

Picture viewer controls for Delphi VCL, with **JPEG XL built in**.

- **`TgllImageView`** is the stand-alone viewer (the `TImage` counterpart).
- **`TgllDBImage`** is the data-aware one (the `TDBImage` counterpart; it reads `TDBImage`'s `Stretch` and `Proportional`, so a form converts by changing the class name).

Both descend from `TgllCustomImageView`, so they behave identically:

| | |
|---|---|
| **Formats** | JPEG, PNG, BMP, GIF (animated), ICO, WMF, EMF, TIFF (Windows WIC) and **JPEG XL** (libjxl, through [libjxl-delphi](https://github.com/ijbranch/libjxl-delphi)); anything else registered with `TPicture` is tried too. |
| **Viewing** | Fit to window, shrink / zoom to fit, zoom (buttons, keys, Ctrl+wheel), pan by dragging, **scroll bars**, display rotation and flip, checkerboard behind transparency, error state. |
| **Changing** | Rotate and flip the picture itself **keeping its format** (a JPEG XL stays JPEG XL), clipboard, load and save (`.jxl` included), print, thumbnails. |
| **Drag and drop** | Drop files from Explorer **and virtual files** (an e-mail attachment, an image from a web browser); drag the picture out as a file (`EnableDragOut`), in its own format. |
| **Data** | `TgllDBImage` stores the bytes of a loaded file exactly as they are, loads asynchronously on request, skips the header old `TDBImage` controls wrote, and works in a `TDBCtrlGrid`. |

**Delphi 13, Win32 and Win64, VCL.**  The only dependency outside the RTL and VCL is LibJxl, for JPEG XL.

## Getting started

1. Build the `LibJxl` package from [libjxl-delphi](https://github.com/ijbranch/libjxl-delphi) first: `gllImageR` requires it.  Then build `Packages\gllImage.groupproj` (runtime `gllImageR`, design-time `gllImageD`, the tests and the demo).
2. Install `gllImageD` from the 64-bit IDE (`bin64\bds.exe`).  The controls appear on the **gllImage** palette page.
3. Put `jxl.dll` beside your executable ([libjxl-delphi](https://github.com/ijbranch/libjxl-delphi)'s `CopyJxlDlls.ps1` does it).  It is loaded only when a JPEG XL is decoded or encoded.

```pascal
gllImageView1.FitToWindow := True;
gllImageView1.LoadFromFile( 'C:\Pictures\Photo.jxl' );
gllImageView1.RotatePicture( ro90 );          // the pixels, kept as JPEG XL
gllImageView1.SaveToFile( 'C:\Pictures\Turned.jxl' );
```

Run `Demo\gllImageDemo` to see both controls, with two JPEG XL samples.

## Documents

- [Users Guide.md](Users%20Guide.md): how to use the controls, property by property.
- [Help.md](Help.md): building, troubleshooting, and the things that look wrong but are not.
- [CHANGELOG.md](CHANGELOG.md): what changed and why.

## Licence

[BSD 3-Clause](LICENSE).  libjxl and the libjxl-delphi binding are BSD-3 as well.

## Origin

gllImage grew from GDBImage (Sebastián Mayorá's freeware enhanced `TDBImage`, later Roy Lambert's EDBImage), which lived inside GITLAKDB as `TGDBImage` until 2026-10-19.  A form that still names `TGDBImage` streams in as `TgllDBImage`.

## How gllImage was developed

gllImage was developed with substantial assistance from an AI coding assistant (Anthropic's Claude), under the maintainer's direction and review.  It is tested as described in [Help.md](Help.md).
