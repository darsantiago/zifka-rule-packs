# Zifka — Signed Public Data Packs

Serverless, signed, license-clean data feed for the
[Zifka Valuation Suite](https://github.com/darsantiago/zifka-valuation-studio)
apps. Nothing here is a proprietary API — everything is a re-serve of a
public source, packaged for the app to consume with a single HTTP GET
and a single Ed25519 signature check.

## What's inside

| File | Contents | Refresh |
|---|---|---|
| `rule_packs.json` | Regulatory compliance packs (US retirement / NAIC / Colombia DIAN / Colombia pensions / …). Each pack lists authority, review date, validity window. | Manual on regulatory change |
| `valuation_pack.json` | Valuation reference constants — country risk premiums (77 countries), mature-market Rf & ERP, size-premium bands, industry-premium hints. | Bi-annual (Damodaran Jan / Jul) |
| `data_feeds.json` | Public macro feeds: US Treasury yields (FRED), core CPI, World Bank GDP / inflation / unemployment / govt debt for the 6 priority EM markets, IMF WEO growth forecast, SEC EDGAR company tickers index. | **Weekly (GitHub Action)** |
| `*.sig` | Detached Ed25519 signature for each pack. Base64-encoded. | Automatic |

## Verifying a pack

The app runs this check on every load; you can reproduce it in the
shell of any Dart / Node / Python / OpenSSL environment. The public
key that verifies every pack is baked into the app at
`lib/core/services/signed_rule_pack_service.dart:publicKeyHex` and
matches:

```
adc008715d83d3774236508c3d592c3eacc0ce6a2f3e05facea40bee334052e5
```

A tampered payload or signature causes the app to discard the pack and
keep whatever it had cached locally.

## Publishing an update

Automatic:

```
# Weekly cron in .github/workflows/refresh-feeds.yml. No manual step.
```

Manual (a regulatory change, a Damodaran vintage update):

```
cd tool
dart pub get
dart run bin/refresh_feeds.dart ../data_feeds.json
dart run bin/sign_pack.dart <path/to/ed25519_private.key> ../data_feeds.json
cd ..
git commit -am "feat(feeds): refresh $(date -u +%Y-%m-%d)"
git push
```

The private key lives outside this repository (see
`zifka-keystores` for the secrets store on maintainer devices,
and `ED25519_PRIVATE_KEY_B64` in GitHub Actions Secrets for CI).

## Sources & attribution

Each pack carries an `attribution` field naming the upstream source
and its licence. In summary:

- **FRED** — Federal Reserve Bank of St Louis. US federal government
  output; public domain in the United States.
- **World Bank Open Data** — Creative Commons Attribution 4.0
  International. We list the indicator code so downstream consumers
  can re-verify.
- **IMF DataMapper API** — IMF terms; re-served here under fair-use
  with attribution.
- **SEC EDGAR** — SEC public filings; public domain.
- **Damodaran** (in `valuation_pack.json`) — reformatted from the NYU
  Stern country-risk workbook, which Damodaran publishes for
  educational and informational use.
- **Kroll Cost of Capital handbook framework** (in `valuation_pack.json`) —
  size-premium *bands* are our own bands built to model the SAME
  dimensions; the Handbook's proprietary decile figures are NOT
  reproduced here.

## License

See [LICENSE.md](LICENSE.md) — Business Source License 1.1. TL;DR: the
Additional Use Grant allows anyone to consume the packs when running
the official Zifka Valuation Suite apps; every other use (redistribution,
embedding in another app, offering as a service) needs a separate
commercial license. Each pack rolls into Apache 2.0 four years after its
publication date.

For commercial use before the Change Date, contact `darsantiago@gmail.com`.
