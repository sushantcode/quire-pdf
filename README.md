# Quire PDF
Arrange, merge and compress PDFs on macOS.

## Logo (`branding/`)

`branding/logo.svg` is the mark, and every client's icon comes from it. It shows
three fanned pages with a coral stitch down the spine: a quire is a set of
sheets sewn together, which is what merging does. Run `make icon` after changing
it. That needs Chrome, which does the rendering.

| File | Use it for |
| --- | --- |
| `logo.svg` | Web favicons and in-app logos. Xcode asset catalogs take SVG too. Port it by hand for an Android VectorDrawable. |
| `logo-mono.svg` | Print, light backgrounds, and Android 13 themed icons. It uses `currentColor`. |
| `dist/icon-1024.png`, `dist/icon-512.png` | iOS, Android and store listings. They have square corners and no alpha, because those platforms apply their own mask. |
| `dist/apple-touch-icon.png` | The web app's home-screen icon. |
| `dist/icon-macos-1024.png` | The finished macOS tile. `make icon` also writes every macOS size into the app's icon set. |

Check the icon at 16px as well as full size before changing the mark. At the
small end, only the page silhouette survives.

## macOS app (`macos/`)

A SwiftUI + PDFKit app for macOS 14 or later. It can:

1. **Load** local PDFs: use ⌘O, the + button, or drop files onto the sidebar.
2. **Rearrange pages** within a PDF: drag one thumbnail onto another. To delete a page, right-click it or select it and press Delete. ⌘-click selects several pages. **Reset Pages** undoes all edits to that file.
3. **Rearrange files**: drag rows in the sidebar. Their order is the merge order.
4. **Merge** every file into one PDF with ⌘E or **Merge & Export**.
5. **Compress** while exporting:
   - **None** keeps the content exactly.
   - **Balanced** re-encodes images as screen-resolution JPEG, and text stays selectable.
   - **Maximum** renders each page as a JPEG, so text is no longer selectable.

   If compression would make the file bigger, the uncompressed data is saved instead.

Your edits change only what gets exported. The original files are never modified.

### Build

```sh
make macos-project   # regenerate the Xcode project from macos/project.yml (needs XcodeGen)
make macos           # build and run the tests
make ci              # the above, plus the version-script tests
open macos/QuirePDF.xcodeproj
```

[XcodeGen](https://github.com/yonaskolb/XcodeGen) generates the Xcode project
from `macos/project.yml`. That file is the source of truth, so don't change the
project through Xcode's settings UI.

### Signing

All three signing keys live in [`macos/Config/Base.xcconfig`](macos/Config/Base.xcconfig).
It defaults to ad-hoc signing with no team, so anyone can build and run the app
on their own Mac without an Apple account. To sign with your own team, create
`macos/Config/Local.xcconfig` (gitignored) and set the three keys shown in
`Base.xcconfig`. The settings there override the defaults for every target and
survive `xcodegen generate`.

The bundle identifier is a placeholder in `project.yml`. Change it before you
distribute the app.

### Versioning

`VERSION` at the repository root holds `MAJOR.MINOR`. The patch number is the
number of commits since `VERSION` last changed, and the build number is the
total commit count. `make macos-version` writes both into
`macos/Config/Version.xcconfig`, which is generated and gitignored. Until you
run it, builds show the fallback version `0.0.0`. It fails, and writes nothing,
until `VERSION` has been committed.

### Layout

| Path | Contents |
| --- | --- |
| `QuirePDF/Model` | `PDFFile` (one loaded PDF and its edited page order) and `Workspace` (files in merge order) |
| `QuirePDF/Services/PDFComposer.swift` | Merging, plus the compression levels |
| `QuirePDF/Views` | Sidebar, page grid, export sheet |
| `QuirePDFTests` | Swift Testing tests for moving pages, merge order and compression |
