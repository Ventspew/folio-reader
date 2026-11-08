# Folio × Readium LCP (authorized path)

## Status in this build

| Capability | Status |
|---|---|
| Detect `.lcpdf`, parse `manifest.json` + `license.lcpl` | ✅ |
| Show rights (print/copy/dates), cover, page count | ✅ |
| Passphrase UI + Keychain storage | ✅ |
| Decrypt via EDRLab `R2LCPClient` | ⏳ requires vendor framework |
| Custom/unofficial DRM bypass | ❌ not implemented |

## Why decryption is blocked without EDRLab

1. Production LCP profiles (`profile-1.0` … `profile-2.9`) use confidential transforms shipped only inside EDRLab’s private client.
2. The open-source Readium **Swift** toolkit does **not** currently compile for macOS ([issue #783](https://github.com/readium/swift-toolkit/issues/783)).
3. Thorium Desktop uses a **certified** native LCP module from EDRLab (not redistributable into Folio).
4. EDRLab FAQ: precompiled LCP libraries exist for **macOS**, provided to trusted integrators after contact + certification.

## How to enable genuine LCP in Folio

1. Email **contact@edrlab.org** (draft is copyable from Folio’s LCP screen).
2. Request a **test-grade macOS R2LCPClient**.
3. Unzip into `Vendor/R2LCPClient/`.
4. In `project.yml` / Xcode:
   - Link `R2LCPClient.framework`
   - Add Swift flag `FOLIO_LCP_CLIENT`
5. Rebuild. `LCPClientFactory` will use `R2LCPClientAdapter`.
6. Before public distribution: sign LCP Terms of Use, switch to production module, pass EDRLab certification.

Test licenses: https://front-test.edrlab.org

## Architecture in Folio

- `PublicationManager` — format detection + open orchestration
- `LCPDocumentProvider` — package open / decrypt pipeline
- `LicenseManager` — Keychain passphrases + SHA-256 hashing
- `LCPClientProviding` — seam for R2LCPClient
- `ClipboardManager` — enforces LCP copy allowances
- `ReadingSession` — active document + progress
