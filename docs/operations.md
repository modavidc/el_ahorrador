# Delivery, observability and operations

Every pull request must pass `Quality gate / quality`: formatting, static
analysis without errors, generated-source drift, tests with at least 25% line
coverage, repository readiness and
a signed release AAB smoke build. The AAB, checksum and LCOV are retained as
commit-addressed evidence. Protect `master` and require this check and one review.

Production releases are immutable semantic tags matching `pubspec.yaml`. The
production environment must require approval and contain the upload-keystore and
Sentry secrets. The workflow verifies the signature, publishes SHA-256 and build
provenance, and refuses to overwrite an existing release.

Remote reporting requires both `SENTRY_DSN` and `TELEMETRY_CONSENT=true`; the
default is off. Sentry sends no default PII, screenshots or request bodies. The
application accepts only allowlisted scalar operational dimensions, rejecting
OCR, paths, descriptions, accounts, amounts and nested payloads.

Operational targets:

- P0: startup failure or data loss. Stop promotion immediately; release owner
  rolls back to the last verified artifact and opens an incident.
- P1: new crash or crash-free sessions below 99.5%. Mobile on-call responds
  within one business day and compares release/revision.
- P2: p95 share-processing duration above 30 seconds for 15 minutes. Triage
  against the previous release.

Before promotion, install the exact AAB from the internal track, execute every
item in `release-evidence-template.md`, provoke one controlled synthetic error,
verify alert delivery and inspect the event for PII. Never attach OCR, databases,
receipts or user identifiers to incidents. Preserve the completed evidence with
the GitHub Release.
