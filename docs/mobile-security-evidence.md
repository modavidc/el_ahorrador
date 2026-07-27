# Mobile security and privacy evidence

This checklist maps each mobile control to repository evidence and to a
repeatable verification step. It is intentionally conservative: a control is
not considered release-verified until its device check has been recorded for
the signed build being distributed.

## Automated repository evidence

| Control | Implementation | Regression evidence |
| --- | --- | --- |
| Database encryption at rest | SQLCipher with a random 256-bit key stored through OS secure storage | `test/sqlcipher_migrator_test.dart`: plaintext migration, wrong-key rejection, encrypted header, integrity check, interrupted swap and orphan cleanup |
| Portable backup confidentiality | Password encryption with authenticated integrity validation | `test/data_backup_service_test.dart`: encrypted round trip, wrong-password rejection and tamper rejection before mutation |
| Android screen privacy | `FLAG_SECURE` set by `MainActivity` | `test/mobile_security_configuration_test.dart` |
| Android data exfiltration defaults | Backup disabled and cleartext traffic blocked in the application manifest | `test/mobile_security_configuration_test.dart` |
| iOS task-switcher privacy | Opaque shield added while the app resigns active | `test/mobile_security_configuration_test.dart` |
| Apple privacy declaration | `PrivacyInfo.xcprivacy`, included in Runner resources | `test/mobile_security_configuration_test.dart` |
| Telemetry secret hygiene | DSN supplied at build time; no embedded DSN | `test/mobile_security_configuration_test.dart` |

Run from the repository root:

```sh
flutter test test/sqlcipher_migrator_test.dart \
  test/data_backup_service_test.dart \
  test/mobile_security_configuration_test.dart
```

Some desktop test environments provide SQLite but not the native SQLCipher
library. The migration tests explicitly report those native cases as skipped;
that is not release evidence. They must also pass in Android/iOS integration
testing with the packaged native library.

## Signed-build device checklist

Record app version, commit, device/OS, tester, date, result, and a link to the
redacted artifact for every row. Never attach a database, key, receipt image,
OCR text, amount, merchant, user identifier, or unredacted device log.

- Upgrade a populated legacy install. Confirm record counts and relationships,
  then prove the database header is not the SQLite plaintext header.
- Force-stop during export and during swap. Relaunch and prove that all records
  remain present and the temporary marker/rollback artifacts are cleaned up.
- Attempt to open a copied database without the key and with a different key;
  both attempts must fail. Run `PRAGMA cipher_integrity_check` with the correct
  key and require a clean result.
- Corrupt a disposable copy of the encrypted database. The app must fail closed
  without replacing the copy or creating a plaintext database.
- Android: verify screenshots and recent-app thumbnails reveal no app content;
  verify `adb backup`/cloud restore cannot recover the private database; verify
  an HTTP endpoint is rejected.
- iOS: background the app from every sensitive screen and inspect the app
  switcher snapshot; validate the archived app contains `PrivacyInfo.xcprivacy`.
- Export an encrypted backup, alter one byte, and confirm restore is rejected
  before current data changes. Restore the untouched backup on a clean device.
- Inspect release logs and crash reports. Confirm there is no OCR text, receipt
  path, SQL, key material, amount, merchant, backup payload, or user identifier.

## Release gate and defensible score

The repository supports a defensible **85/100** for category 04 once the host
suite passes. Raise this to **90/100** only after the signed-build checklist is
completed on both platforms and retained as redacted evidence. A score above
90 requires additional product controls not evidenced here: app-level
biometric/PIN re-authentication, per-file encryption for receipt images, key
rotation/recovery design, and an independent mobile penetration test.

Any failed integrity, rollback, wrong-key, screenshot, backup, or cleartext
transport check blocks release. Follow `docs/sqlcipher-beta-runbook.md`; never
downgrade or reinstall as a recovery action before preserving recoverable data.
