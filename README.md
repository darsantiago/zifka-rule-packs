# Zifka — Signed Public Data Packs

## Current Valuation Suite feed scope (2026-09-15)

`data_feeds.json` includes only five reviewed World Bank indicators for six
markets and SEC ticker metadata. Direct FRED and IMF observations are excluded,
including when credentials or an old environment flag exist. The weekly
publisher has the same scope. A signature proves authenticity, not permissions,
freshness, accuracy or professional approval.

The public feed was repackaged as version 9 from the signed September 14 baseline.
Observation periods and publishedAt are preserved: repackaging is not a refresh.
Source and licensing evidence is maintained in the app's
[scoped review](https://github.com/darsantiago/zifka-valuation-studio/blob/main/docs/rights/public-data-scope.md).
Third-party data remains subject to its own terms; repository licensing cannot
override rights already granted by a source.

`valuation_pack.json` is a legacy, unreviewed reference dataset, not consumed by
Valuation Suite 14231. No blanket rights clearance is claimed for other payloads
or historical commits in this repository. Regulatory packs are separate.

## Refresh and sign

The weekly workflow tests the producer before refreshing World Bank/SEC data,
then signs using the existing private identity stored outside this repository.
The next successfully refreshed version is strictly greater than the current one.

```
cd tool
dart pub get
dart test
dart run bin/refresh_feeds.dart ../data_feeds.json
dart run bin/sign_pack.dart <existing-private-key-path> ../data_feeds.json
```

The public verification identity is pinned in `tool/test/feed_scope_test.dart`
and in the app's `SignedRulePackService.publicKeyHex`.

No private key belongs in a commit. Clients verify both the signature and their
own source allowlist, and retain a valid scoped baseline on failure.
Contact: info@sari-ai.com.
