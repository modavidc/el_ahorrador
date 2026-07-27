import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var privacyView: UIView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationWillResignActive(_ application: UIApplication) {
    super.applicationWillResignActive(application)
    guard privacyView == nil, let window = window else { return }
    let shield = UIView(frame: window.bounds)
    shield.backgroundColor = .systemBackground
    shield.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    window.addSubview(shield)
    privacyView = shield
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    privacyView?.removeFromSuperview()
    privacyView = nil
    super.applicationDidBecomeActive(application)
  }
}
