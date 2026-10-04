# App Store listing

What App Store Connect asks for, kept with the app so it changes with it.
Paste each field as written. Lengths are checked against App Store Connect's
limits.

## Version information (English U.S.)

**Promotional text** (153/170). It can be changed without a new build.

```
Combine PDFs and put every page exactly where you want it, even between files. Then shrink the result to share. Private: everything stays on your device.
```

**Description** (1402/4000)

```
Quire PDF puts several PDFs together into one, with every page exactly where you want it.

Most merge tools glue whole files end to end. Quire PDF shows every page of every file in one grid, in the order they'll be merged, so you can move page 4 of the second file to the very front, or slip a receipt between two pages of a report.

ARRANGE
• See every page of every file at once, in merge order
• Drag any page anywhere, including between files
• Select several pages to move or delete them together
• Colour-coded badges show which file and page each one came from
• Preview any page full size before you decide
• Reset to the original order at any time

MERGE AND SHRINK
• Merge everything into one PDF in a tap
• Choose how much to compress: None, Balanced or Maximum
• Balanced shrinks images and keeps text selectable and searchable
• Never makes a file bigger: if compressing wouldn't help, it doesn't
• Save to Files or share straight away, then start a new merge or keep editing

PRIVATE BY DESIGN
• Everything happens on your device. No uploads, no account, no tracking
• Your original files are never changed

WORKS THE WAY YOU DO
• Open PDFs from Files, or share them to Quire PDF from Mail, Safari and other apps
• Drag PDFs in on iPad, and work on separate merges in separate windows
• Full VoiceOver support, including moving pages without dragging
• Supports Dynamic Type and Dark Mode
```

**Keywords** (99/100). Comma-separated, no spaces. The app name and
subtitle already count, so "PDF" and "merge" need no extra weight here.

```
merge,combine,join,reorder,arrange,organize,pages,compress,shrink,documents,binder,assemble,collate
```

**Support URL:** the support page, `docs/index.html`, published with GitHub Pages.

**Marketing URL** (optional): the same page.

**Screenshots:** run `make screenshots`, then upload from
`ios/AppStore/Screenshots/`:

| Folder | App Store Connect slot | Size |
| --- | --- | --- |
| `iPhone 6.9in - 1320x2868` | iPhone 6.9" display | 1320 × 2868 |
| `iPhone 6.5in - 1284x2778` | iPhone 6.5" display | 1284 × 2778 |
| `iPad 13in - 2064x2752` | iPad 13" display | 2064 × 2752 |

Each slot accepts only its own sizes: the 6.9-inch images are rejected in the
6.5-inch slot.

Upload them in file order: pages, select, files, preview, merged.

**Copyright:** the year, then the name of the person or company that owns the
app, for example `2026 <owner name>`.

## App information

**Subtitle** (27/30)

```
Merge & rearrange PDF pages
```

**Category:** Productivity. Secondary: Business.

**Content rights:** "No, it does not contain, show, or access third-party
content." The app only opens the user's own files.

**Age rating:** 4+. Answer None or No to every question. Quire PDF has no web
access, user-generated content, chat, ads, gambling or social features.

## App Privacy

**Privacy Policy URL:** the privacy page, `docs/privacy.html`, published with
GitHub Pages.

**Data collection:** "No, we do not collect data from this app." That matches
`ios/QuirePDF/PrivacyInfo.xcprivacy`, and the code makes no network
connections. An Admin of the App Store Connect account must publish this answer.

## Pricing

Your choice. Choosing Free needs no agreements beyond the standard one. Any paid
tier needs the Paid Apps agreement, tax and banking forms completed first.

## App Review contact

A real person App Review can reach during review: first name, last name, email,
and a phone number in international format with the country code, such as
`+1 555 123 4567`. It is shown only to Apple.

No demo account is needed: the app has no sign-in. Notes for the reviewer:

```
Quire PDF needs no account. To try it, tap Choose PDFs and pick two or more PDFs from Files. Touch and hold a page and drag it to move it, including between files, then tap Merge. Everything runs on the device; the app makes no network connections.
```
