//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import flutter_secure_storage_darwin
import local_auth_darwin
import package_info_plus
import path_provider_foundation
import sentry_flutter
import sqlcipher_flutter_libs

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  FlutterSecureStorageDarwinPlugin.register(with: registry.registrar(forPlugin: "FlutterSecureStorageDarwinPlugin"))
  LocalAuthPlugin.register(with: registry.registrar(forPlugin: "LocalAuthPlugin"))
  FPPPackageInfoPlusPlugin.register(with: registry.registrar(forPlugin: "FPPPackageInfoPlusPlugin"))
  PathProviderPlugin.register(with: registry.registrar(forPlugin: "PathProviderPlugin"))
  SentryFlutterPlugin.register(with: registry.registrar(forPlugin: "SentryFlutterPlugin"))
  Sqlite3FlutterLibsPlugin.register(with: registry.registrar(forPlugin: "Sqlite3FlutterLibsPlugin"))
}
