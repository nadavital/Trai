# Internal TestFlight release: September 27, 2026

Target: iOS Trai 1.2 (42), existing internal Friends and Family group. No external distribution or App Review submission.

## Validation

See [core journey validation](core-journey-validation.md). Seven simulator journey tests, three cold-workout-launch regression runs, and all stages of the required live workout stability script passed. Native screenshots were inspected. Physical camera, live AI, Watch synchronization, and HealthKit export remain unverified in this pass.

## Delivery

- Signed Release archive succeeded: `/private/tmp/Trai-1.2-42-internal.xcarchive`.
- Archive includes `INTERNAL_TESTING`.
- Export succeeded: `/private/tmp/Trai-42-export/Trai.ipa`.
- Export options retain `testFlightInternalTestingOnly=true`; the exported application's Info.plist independently confirms `TFInternalTestingOnly=true`.
- App Store Connect upload committed successfully. Upload ID: `3a05a108-c41d-427d-8afb-28d9d757f203`.
- Processing completed: `VALID`. Export compliance completed with `usesNonExemptEncryption=false` (existing system cryptography and hashing; no custom encryption introduced).
- Internal build state: `IN_BETA_TESTING`. External build state: `NOT_APPLICABLE`.
- Confirmed build 42 in internal Friends and Family group `f0a703ac-4101-4f65-8a62-872a7b56a2f4` through its builds relationship. Automatic all-build access handled assignment.
- English What to Test notes were saved and independently read back.

Source changes remain uncommitted. No App Store metadata, screenshots, or review submission changed. No backend deployment was performed in this pass.
