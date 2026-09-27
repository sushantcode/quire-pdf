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

1. **Load** local PDFs: use ⌘O, the + button, or drop files onto the window.
2. **Arrange pages across files.** The main area shows every page of every file in the order they'll be merged. Drag a page onto another to move it there, even to a spot among another file's pages. A coloured badge on each page shows which file and page it came from.
   - ⌘-click adds a page to the selection, and Shift-click selects a range. Dragging a selected page moves the whole selection.
   - Right-click a page to move it to the start or end, or to delete it. Delete also removes the selected pages.
   - Selecting a file in the sidebar selects its pages and scrolls to them.
   - **Reset Pages** restores every page of every file, in file order.
3. **Rearrange files** by dragging rows in the sidebar. This regroups the pages file by file, so any pages you moved between files go back to their own file.
4. **Merge** with the button in the bar under the pages, or with ⌘E. It saves straight away and then shows the file size, with a link to show the file in Finder.
5. **Compress** while merging. Choose a level in the same bar:
   - **None** keeps the content exactly.
   - **Balanced** re-encodes images as JPEG and scales large ones down to 150 dpi. Text and vector content stay as they are, so text is still selectable. It never scales small images up.
   - **Maximum** renders each page as a JPEG, so text is no longer selectable.

   If compression would make the file bigger, the uncompressed data is saved instead.

**Start Over** in the toolbar, or ⇧⌘⌫, removes every file so you can begin again. It asks first.

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
| `QuirePDF/Model` | `PDFFile` (one loaded PDF and its pages) and `Workspace` (the files, and the one page order they merge in) |
| `QuirePDF/Services/PDFComposer.swift` | Merging, plus the compression levels |
| `QuirePDF/Views` | Sidebar, page grid, merge bar |
| `QuirePDFTests` | Swift Testing tests for moving pages within and across files, merge order and compression |
