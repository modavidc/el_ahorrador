import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let privacyCoverTag = 9042026

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationWillResignActive(_ application: UIApplication) {
    super.applicationWillResignActive(application)
    guard let window = window, window.viewWithTag(privacyCoverTag) == nil else { return }
    let cover = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    cover.tag = privacyCoverTag
    cover.frame = window.bounds
    cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    window.addSubview(cover)
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    window?.viewWithTag(privacyCoverTag)?.removeFromSuperview()
  }
}
