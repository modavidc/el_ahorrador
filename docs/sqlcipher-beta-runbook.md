# SQLCipher beta migration runbook

This migration is intentionally isolated from broad quality refactors. It
replaces the on-device plaintext SQLite file with SQLCipher and stores a random
256-bit key in the operating-system secure storage.

## Safety properties

- The app refuses to open a database when the SQLCipher native library is not
  present. A missing library must never silently create or open plaintext data.
- Migration exports to `misgastos.sqlite.encrypted.partial`, validates it, and
  only then swaps files. `misgastos.sqlite.plaintext.rollback` remains available
  during the swap and is restored on failure.
- A small migration marker lets the next launch finish a validated swap or
  restore the rollback copy after process termination.
- Android cloud backup is disabled. Restoring an encrypted database without its
  Android Keystore wrapping key would make the data unrecoverable. User-driven,
  password-encrypted export remains the portable recovery mechanism.

## Required beta evidence

1. Build the signed AAB in CI with ephemeral credentials. Do not upload it.
2. On Android 8, 11, and the current target SDK, install a build that contains a
   populated plaintext v1 database, then upgrade in place.
3. Verify transaction counts, category relationships, `PRAGMA user_version`,
   and that the first 16 bytes are not `SQLite format 3\0`.
4. Kill the process once during export and once during the file swap; relaunch
   and verify recovery without lost records.
5. Verify password-encrypted export and restore before enrolling beta users.
6. Start with internal testers, then 5%, 25%, and 100% beta cohorts. Hold each
   cohort for at least 24 hours with no database-open or recovery regression.

## Rollback

Do not downgrade an already-migrated installation to a plaintext build: the old
binary cannot read SQLCipher. Stop rollout and ship a forward-fix using the same
secure-storage key. A user who cannot open the database should not reinstall;
reinstallation may remove the database or its key. Escalate for recovery first.

## Observability and privacy

Sentry is already gated by environment-provided configuration. If enabled for
the beta, report only migration result/stage, app version, platform, and a
coarse error class. Never attach database paths, SQL, keys, OCR text, merchant
names, amounts, backup contents, or user identifiers. Alerts should cover a
database-open failure rate above 0.5% and any rollback/recovery failure.
