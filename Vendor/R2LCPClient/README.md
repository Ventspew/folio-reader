# Vendor: R2LCPClient

Place the EDRLab-provided `R2LCPClient.framework` (or SPM package) here after you receive it.

Then:

1. Add the framework to the Folio target.
2. Set Swift active compilation condition `FOLIO_LCP_CLIENT`.
3. Rebuild.

Until then, Folio uses `UnavailableLCPClient` and still parses LCPDF metadata/rights safely.
