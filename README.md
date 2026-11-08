# Folio

Native macOS academic reader — Swift 6, SwiftUI, PDFKit — with a prepared **authorized** Readium LCP integration seam.

## Features

- Standard PDFs: selection, ⌘C copy, search, zoom, navigation
- Highlights, bookmarks, notes, reading progress (local)
- Citation copy (⇧⌘C)
- Light / dark appearance
- Professional Folio app icon
- `.lcpdf` import: metadata, cover, license rights, passphrase UI + Keychain
- LCP decryption via EDRLab `R2LCPClient` when linked (see [docs/LCP-INTEGRATION.md](docs/LCP-INTEGRATION.md))

## LCP status

Folio does **not** bypass DRM. Production LCP profiles require EDRLab’s private macOS client and certification. Until that framework is linked, Folio inspects LCP packages and guides you through the official request process. Use [Thorium](https://www.thoriumreader.com) for certified encrypted reading today.

## Build

```bash
brew install xcodegen
xcodegen generate
xcodebuild -scheme Folio -configuration Release -derivedDataPath build \
  -destination 'platform=macOS,arch=arm64' ONLY_ACTIVE_ARCH=YES \
  CODE_SIGNING_ALLOWED=NO
```

GitHub Actions builds a DMG on every `main` push.

## License

MIT
