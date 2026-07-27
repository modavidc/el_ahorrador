import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';

/// Must run before the first sqlite3 call in every isolate.
void configureSqlCipherRuntime() {
  open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
}
