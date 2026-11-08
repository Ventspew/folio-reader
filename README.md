# Folio

Native macOS academic e-book reader (Swift 6 + SwiftUI + PDFKit).

## Features

- Open standard PDFs with PDFKit
- Mouse text selection, ⌘C / Edit → Copy / context menu copy
- Full-text search, zoom, page navigation
- Highlights (multiple colors), bookmarks, notes
- Persistent library + reading progress
- Citation copy with page numbers (⇧⌘C)
- Light / dark appearance
- Readium `.lcpdf` **metadata inspection** (license rights, title, page count, cover)

## Readium LCP status

Official Readium Swift LCP support requires EDRLab’s private `R2LCPClient` and currently targets iOS. Folio does **not** decrypt LCP content or bypass DRM.

When you open an `.lcpdf`, Folio shows license metadata and explains the limitation. Use [Thorium Reader](https://www.thoriumreader.com) for encrypted LCP reading.

## Requirements

- macOS 14+
- Xcode 16+ (for local builds)

## Local build

```bash
brew install xcodegen
xcodegen generate
xcodebuild -scheme Folio -configuration Release -derivedDataPath build CODE_SIGNING_ALLOWED=NO
open build/Build/Products/Release/Folio.app
```

## GitHub DMG

Pushing to `main` or running the **Build DMG** workflow produces a downloadable `Folio.dmg` artifact (and a GitHub Release on tags `v*`).

## License

MIT
