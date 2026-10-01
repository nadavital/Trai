# Internal TestFlight release: 2026-09-22

Target: iOS Trai 1.2 (41), existing internal Friends and Family group. No App Review submission or external distribution authorized.

Backend deployed successfully:
- Model: gpt-6-luna
- Staging revision: trai-backend-staging-00015-wcb
- Production revision: trai-backend-production-00026-lrp
- Both health checks confirmed model and 100% revision traffic.
- Adapter, Firestore, Apple verification and synthetic live structured-output/function-call probes passed.
- No private meal photo was sent; no authenticated physical-app end-to-end claim.

Signed archive succeeded: `/private/tmp/Trai-1.2-41-internal.xcarchive`.
Archive includes `INTERNAL_TESTING` compilation condition to expose long-press Log food > Try camera sheet in this release.
Export options `/private/tmp/Trai-internal-export.plist` set `testFlightInternalTestingOnly=true`, `destination=upload`, version management disabled.

Upload initially failed because Xcode's Apple account credential lacks Xcode-Token. On 2026-09-23, API-authenticated Xcode export succeeded after Keychain access: Uploaded Trai / EXPORT SUCCEEDED. The internal-only export option remained enabled. Build ID cacc768a-84db-448c-948d-97ec4ed35b5a processed VALID. Encryption compliance completed. Confirmed in internal Friends and Family group f0a703ac-4101-4f65-8a62-872a7b56a2f4 via automatic all-build access; manual association was rejected because Apple manages this internal group automatically. External build state NOT_APPLICABLE. English testing notes updated.

Source changes remain uncommitted. No App Store metadata, screenshots, or review state changed.
