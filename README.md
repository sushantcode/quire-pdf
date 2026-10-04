# Quire PDF
Arrange, merge and compress PDFs on macOS, iPhone and iPad.

Everything happens on the device. PDFs are read, rearranged and merged
locally, and the original files are never modified.

| Path | Contents |
| --- | --- |
| [`QuireKit/`](QuireKit) | The Swift package both apps share: the page model, merging and compression, and their tests |
| [`macos/`](macos) | The macOS app |
| [`ios/`](ios) | The iPhone and iPad app |
| [`branding/`](branding) | The logo, and every icon exported from it |
| `VERSION`, [`scripts/`](scripts) | The version both apps ship as |

## What the apps do

Both apps work the same way, because the rules live in QuireKit:

1. **Load** PDFs.
2. **Arrange pages across files.** The main area shows every page of every file in the order they'll be merged. Move a page anywhere, including among another file's pages. A coloured badge on each page shows which file and page it came from.
3. **Rearrange files.** This regroups the pages file by file, so any pages you moved between files go back to their own file.
4. **Merge**, with one of three compression levels:
   - **None** keeps the content exactly.
   - **Balanced** shrinks images to JPEG at up to 150 dpi. Text stays selectable. It never scales small images up.
   - **Maximum** renders each page as a JPEG, so text is no longer selectable.

   If compression would make the file bigger, the uncompressed data is saved instead.
5. **Start Over** removes every file, after asking.

**Reset Pages** restores every page of every file, in file order.

## QuireKit (`QuireKit/`)

A Swift package for macOS 14 and iOS 17. Anything that decides what ends up in
the merged file is here, so the apps cannot disagree about it. The apps hold
only their interfaces.

| File | Contents |
| --- | --- |
| `PDFFile.swift` | One loaded PDF and its pages, and how pages move |
| `MergeSession.swift` | The files, the one page order they merge in, the selection, and merging |
| `PDFComposer.swift` | Merging, and the compression levels |

**Balanced works differently on each platform.** PDFKit's own image options
turned out to do nothing on either one: they write the file back unchanged.

- **On macOS** it uses a Quartz filter, the mechanism behind Preview's Reduce File Size. Text and vector content are copied as they are.
- **On iOS** there are no Quartz filters, so each page that holds images is redrawn as one JPEG, when that at least halves it. An invisible text layer keeps the page's text selectable and searchable, as in a scanned document. Pages without images are never touched. Links and annotations on redrawn pages are not kept.

The tests run on both platforms with `make kit`.

## macOS app (`macos/`)

A SwiftUI app for macOS 14 or later.

- **Load:** use ⌘O, the + button, or drop files onto the window.
- **Select:** ⌘-click adds a page to the selection, and Shift-click selects a range. Dragging a selected page moves the whole selection.
- **Edit:** right-click a page to move it to the start or end, or to delete it. Delete also removes the selected pages.
- **Files:** selecting a file in the sidebar selects its pages and scrolls to them. Drag rows to reorder files.
- **Merge:** use the bar under the pages, or ⌘E. It saves straight away, then shows the file size with a link to show the file in Finder.
- **Start Over:** ⇧⌘⌫.

## iOS app (`ios/`)

A SwiftUI app for iPhone and iPad, iOS 17 or later.

- **Load:** use **Choose PDFs**, or **Add PDFs** in the ⋯ menu. You can also share a PDF to Quire PDF from Files, Mail or Safari, or drag PDFs onto the app on iPad.
- **Arrange:** touch and hold a page, then drag it onto another. Tap a page to preview it full size. Touch and hold, then let go, for Move to Start, Move to End and Delete.
- **Select:** tap **Select** to pick several pages, then move or delete them all from the bar at the bottom. Dragging a selected page moves the whole selection.
- **Files:** the files button opens a list of the files. Drag to reorder them, swipe to remove one, or tap one to select its pages.
- **Merge:** the result screen offers **Share**, **Save to Files**, and **Start New Merge**. **Done** keeps the pages for another merge.
- **Several windows:** each iPad window has its own merge.

It is built for public release:

- **VoiceOver:** every page can be moved earlier, later, to the start or to the end, without dragging.
- **Dynamic Type:** text sizes follow the system setting.
- **Translation:** the interface text is in a String Catalog, ready to translate.
- **Privacy manifest:** `PrivacyInfo.xcprivacy` declares no tracking and no data collected. Its one declared API is UserDefaults, which remembers the last compression level.
- **Export compliance:** the app declares that it uses no non-exempt encryption, so each upload needs no extra paperwork. `ios/Tools/check-encryption.sh` keeps that true. `make ios` fails if the shipped code starts encrypting anything, including writing or unlocking a password-protected PDF. It then says how to resolve it: change the declaration, or narrow the check. The check is itself tested against planted code by `make ci`.
- **Temporary files:** files the system copies in for sharing, or that a drop creates, are deleted once read. Merged files are written with complete file protection and deleted when their result screen closes.

## Build and test

```sh
make projects   # regenerate both Xcode projects from their project.yml (needs XcodeGen)
make version    # stamp the version into both apps
make kit        # QuireKit's tests, on macOS and in the iOS Simulator
make macos      # build the macOS app
make ios        # build the iOS app and run its UI tests in the Simulator
make ci         # all of the above, plus the version-script and encryption-check tests
open macos/QuirePDF.xcodeproj   # or ios/QuirePDF.xcodeproj
```

The iOS tests run on an iPhone 17 simulator. Choose another with, for example,
`make ios IOS_SIMULATOR="iPad Pro 11-inch (M5)"`.

[XcodeGen](https://github.com/yonaskolb/XcodeGen) generates each Xcode project
from its `project.yml`. Those files are the source of truth, so don't change the
projects through Xcode's settings UI. Regenerate after adding or removing a
source file.

The iOS UI tests launch the app with `-UITestSamples`, which loads two sample
PDFs in debug builds. They don't depend on the document picker.

## Signing

Each app's signing keys live in its `Config/Base.xcconfig`, and default to no
team.

- **macOS** signs ad-hoc, so anyone can build and run the app on their own Mac without an Apple account.
- **iOS** builds for the Simulator without a team. A device, TestFlight or the App Store needs one.

To sign with your team, create `Config/Local.xcconfig` (gitignored) next to that
app's `Base.xcconfig`, and set the keys `Base.xcconfig` lists. The settings there
override the defaults and survive `xcodegen generate`.

Both apps use the placeholder bundle identifier `com.example.QuirePDF`, set in
each `project.yml`. They share it so one purchase can cover both. Change it in
both files before you distribute.

## Versioning

`VERSION` at the repository root holds `MAJOR.MINOR`. The patch number is the
number of commits since `VERSION` last changed, and the build number is the
total commit count. `make version` writes both into each app's
`Config/Version.xcconfig`, which is generated and gitignored. Both apps
therefore ship the same version from a given commit.

Until you run it, builds show the fallback version `0.0.0`. It fails, and writes
nothing, until `VERSION` has been committed.

## Logo (`branding/`)

`branding/logo.svg` is the mark, and every client's icon comes from it. It shows
three fanned pages with a coral stitch down the spine: a quire is a set of
sheets sewn together, which is what merging does. Run `make icon` after changing
it. That needs Chrome, which does the rendering.

| File | Use it for |
| --- | --- |
| `logo.svg` | Web favicons and in-app logos. `make icon` copies it into the iOS app, which shows it on its first screen. Port it by hand for an Android VectorDrawable. |
| `logo-mono.svg` | Print, light backgrounds, and Android 13 themed icons. It uses `currentColor`. |
| `dist/icon-1024.png`, `dist/icon-512.png` | iOS, Android and store listings. They have square corners and no alpha, because those platforms apply their own mask. `make icon` copies the 1024 one into the iOS app. |
| `dist/apple-touch-icon.png` | The web app's home-screen icon. |
| `dist/icon-macos-1024.png` | The finished macOS tile. `make icon` also writes every macOS size into the app's icon set. |

Check the icon at 16px as well as full size before changing the mark. At the
small end, only the page silhouette survives.
