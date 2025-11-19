import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // OneSignal Flutter SDK handles push notification setup automatically
    // The plugin will register for remote notifications when initialized
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Handle notification registration
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    // OneSignal SDK handles this automatically, but we call super to ensure proper handling
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
  
  // Handle notification registration failure
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    // OneSignal SDK handles this automatically, but we call super to ensure proper handling
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
}
