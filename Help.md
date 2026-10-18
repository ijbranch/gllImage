# gllImage — Help & Troubleshooting

Building, deploying, and the things that look wrong and are not.  For how to use the controls, see [Users Guide.md](Users%20Guide.md).

**Delphi 13 (RAD Studio 37.0), Win32 and Win64, VCL.**

---

## 1. What is where

| Path | What |
|---|---|
| `Source\gllImage.View.pas` | `TgllCustomImageView` (all the viewing) and `TgllImageView` |
| `Source\gllImage.DB.pas` | `TgllDBImage`: the data link on top of the viewer |
| `Source\gllImage.Utils.pas` | Format detection, loading, rotate / flip / thumbnail / print, the loader registry |
| `Source\gllImage.Consts.pas` | Resource strings and constants |
| `Source\gllImage.Register.pas` + `.dcr` | Palette registration and icons (design-time only) |
| `Packages\gllImageR` / `gllImageD` | Runtime and design-time packages; `gllImage.groupproj` builds both, the tests and the demo |
| `Tests\gllImageTests` | DUnitX suite (console runner; results in `gllImageTests-results.xml`) |
| `Demo\gllImageDemo` | Both controls side by side, with `Sample-Landscape.jxl` (lossy) and `Sample-Portrait.jxl` (lossless) |

## 2. Building

- Build the packages in all four modes (Win32 / Win64 × Debug / Release), runtime before design-time, Release last.  The group project lists them in that order and makes `gllImageD` depend on `gllImageR`.
- Outputs follow the estate standard: BPL / DCP in `$(BDSCOMMONDIR)\Bpl|Dcp\<Platform>` (Release) and `...\<Platform>\Debug`; DCUs project-local.
- `gllImageR` **requires `LibJxl`**, the package of [libjxl-delphi](https://github.com/ijbranch/libjxl-delphi); build it first if its DCP is missing (`E2202 Required package 'LibJxl' not found`).
- An application compiling the source needs **both** gllImage's `Source` folder and libjxl-delphi's `Source` folder on its search path.
- **The tests and the demo look for libjxl-delphi at `D:\gllLibJxl\delphi`** (search path, and the post-build step that runs its `CopyJxlDlls.ps1`).  With it elsewhere, change both in `Tests\gllImageTests.dproj` and `Demo\gllImageDemo.dproj`.
- Install `gllImageD` from `bin64\bds.exe` only.  If a form reports `Class TgllDBImage not found`, the package is not installed: **never click Ignore** (saving would remove the control from the `.dfm`).

## 3. Deploying: `jxl.dll`

The JPEG XL binding loads `jxl.dll` (or upstream's `jxl.dll` + `jxl_threads.dll` + `jxl_cms.dll`) **only when a JPEG XL is decoded or encoded**.  Without it every other format works, and a JPEG XL fails with a load error in `LastError`.  libjxl-delphi's `CopyJxlDlls.ps1 -Platform Win64 -OutputDir <exe folder>` copies the right DLLs and checks them; the tests and the demo run it as a post-build step.

## 4. Things that look wrong and are not

- **`Stretch` and `Proportional` are never written to a `.dfm`.**  They are `TDBImage` compatibility: reading an old form maps them onto `ShrinkToFit`, `ZoomToFit` and `MaintainAspectRatio`, which are what gets saved.
- **A rotated or flipped JPEG is re-encoded.**  Changing pixels needs a new encode; the format and its settings are kept, but a lossy format loses a little each time.  PNG and BMP are lossless.  A decoded JPEG XL does not know how its file was encoded, so it is re-encoded at libjxl's default (distance 1.0, visually lossless).
- **`ZoomFactor` changes when you zoom a fitted picture.**  Zooming leaves fit mode at the scale shown, so the next step starts from what is on screen.
- **Setting `Picture` on a `TgllDBImage` marks the record modified.**  That is how a change reaches the field.  For a display-only turn (an EXIF orientation, say) set `Rotation`, never rotate `Picture`.
- **`LoadFromFile` on `TgllDBImage` leaves the record in edit.**  The field holds the file's bytes; **Post** stores them.  It no longer re-encodes them on Post (it did until 2026-10-19).
- **TIFF without GraphicEx.**  The optional GraphicEx support was removed; TIFF decodes through the VCL's `TWICImage` (Windows Imaging Component).

## 5. Tests

`Tests\gllImageTests` (DUnitX, Win64 Release console, `FailsOnNoAsserts`): the loader registry, the viewer (load, read-only, flips and rotation keeping their format, pan limits centred / uncentred / rotated / fitted, zoom from fit, `Stretch` / `Proportional`, a real `WM_DROPFILES`, `.jxl` saving), the data link (load from the field, edit / modify / Post, read-only, the old header, byte-exact `LoadFromFile`, a JPEG XL round trip, the `TGDBImage` alias) and format detection.  The JPEG XL tests need `jxl.dll` beside the runner (the post-build step copies it).  Every behaviour fix is mutation-checked: the fix was reverted and the suite shown to fail.
