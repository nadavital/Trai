# Trai internal release pipeline

Only pushes to `release/trai-49-cloud` in `nadavital/Trai` run this workflow.
The GitHub-hosted Ubuntu runner starts the existing Apple Cloud workflow;
Apple builds, signs, and distributes to the existing single-tester internal group.
No local Mac is involved after a push is accepted by GitHub.

Environment `trai-internal-release` must allow only the exact release branch.
It holds `ASC_PRIVATE_KEY`, `ASC_KEY_ID`, and `ASC_ISSUER_ID`. Never commit values.
The runner writes the key only to a private temporary file and removes it on exit.
Only the release step receives credentials. No pull-request trigger is configured.

Keep Apple's native branch start condition absent: GitHub is the sole automatic
trigger owner. The script fails closed if native triggering is enabled, the internal
audience changes, or the built commit differs from the push. Concurrent releases
are serialized; reruns reuse an existing Apple run for the same SHA. Superseded
queued pushes are skipped. An uncertain POST is never automatically retried.
Inspect Apple's existing runs before retrying a failed job. A failed existing
Apple run is not automatically replaced.

The API reports bridge-created runs as MANUAL because they use the start-build
API; correlate the GitHub push event, job log and commit to establish automation.
The workflow verifies VALID, IN_BETA_TESTING and the exact internal group.
GitHub/Apple outages, credential revocation, legal agreements or app build errors
can still stop delivery. Administrators can edit environment restrictions; the
existing key retains its account-level authority and must be treated accordingly.

Run local logic tests with:
`python3 -m unittest discover -s scripts/ci -p 'test_*.py'`
