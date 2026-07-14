# Zifka Advisor — Signed Rule Packs

Static, serverless regulatory rule-pack feed for [Zifka Advisor](https://github.com/darsantiago/zifka-advisor).

- `rule_packs.json` — pack metadata (id, authority, validity window).
- `rule_packs.json.sig` — detached Ed25519 signature (base64).

The app fetches both files from `raw.githubusercontent.com`, verifies the
signature against its embedded public key, and only then applies the packs.
An invalid or tampered payload is discarded. The private signing key lives
in a private repository and is never published here.

To publish an update:

```
dart run tool/rule_packs_tool.dart sign <private.key> rule_packs.json
git commit -am "update packs" && git push
```
