# Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

> The change record of the `gllImageTests` test suite (`Tests`).  Kept beside the suite since 2026-10-25 (Ian: "every
> test suite should have its own change log"); test-only entries recorded before that in the repository's
> `CHANGELOG.md` were moved here the same day.  Product changes, including those that change a product unit together
> with its tests, stay in the repository's `CHANGELOG.md`.

## [In-Service]

### Added

- (2026-10-25) **This change log** — `CHANGELOG.md`.  The suite's own record, per the estate rule that every test
  suite has one; test-only history moved in from `..\CHANGELOG.md` ( 1 entry ).

### Changed

- (2026-10-26) **Unit-scope names in every `uses` clause** — `TestGllImage.pas`.  2 scoped names respelt as the unit declares itself; generated code is byte-identical in every mode built.  **Why:** Ian, 2026-10-26: "all the gll* forks are our own code because they have all been modified to suite our needs/preferences/standards".
- (2026-10-23) The test suite now runs under the Aqua Light Slate VCL style — `gllImageTests.dpr`, `gllImageTests.dproj`.  The view tests parent a `TgllImageView` to a form and paint it, and Ian's rule (2026-10-23) is that any test producing UI uses the style "to ensure that all UI presents properly and completely".  The `.dproj` embeds the style and the runner activates it with `TStyleManager.TrySetStyle` before any form exists.  All 50 tests pass on Win64 and Win32 with no test changed.  The runner calls `TrySetStyle` without its error dialog and, when the style is not linked, prints one line and stops with exit code 251 (the runner-failed code), so it can neither hang on a modal nor run unstyled; a scratch build without the style proved it.
