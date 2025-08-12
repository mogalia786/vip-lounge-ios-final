import Flutter
import FirebaseCore
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    // Configure Firebase as early as possible to avoid plugins triggering a default configure().
    if FirebaseApp.app() == nil {
      if let filePath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
         let options = FirebaseOptions(contentsOfFile: filePath) {
        FirebaseApp.configure(options: options)
      } else {
        let options = FirebaseOptions(googleAppID: "1:320766440190:ios:fbb35c9873c09977842baf", gcmSenderID: "320766440190")
        options.apiKey = "AIzaSyBsWZEujXS0Kk5Ua2QCozfVnrsT4NrwD1c"
        options.projectID = "vip-lounge-f3730"
        options.storageBucket = "vip-lounge-f3730.appspot.com"
        FirebaseApp.configure(options: options)
        NSLog("[Firebase] Configured early in willFinish with inline FirebaseOptions fallback.")
      }
    }
    return true
  }
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Configure Firebase early in app launch. Required by Firebase plugins.
    if FirebaseApp.app() == nil {
      if let filePath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
         let options = FirebaseOptions(contentsOfFile: filePath) {
        FirebaseApp.configure(options: options)
      } else {
        // Fallback: Inline FirebaseOptions so app can run even if the plist isn't bundled.
        // Values mirror ios/Runner/GoogleService-Info.plist
        let options = FirebaseOptions(googleAppID: "1:320766440190:ios:fbb35c9873c09977842baf", gcmSenderID: "320766440190")
        options.apiKey = "AIzaSyBsWZEujXS0Kk5Ua2QCozfVnrsT4NrwD1c"
        options.projectID = "vip-lounge-f3730"
        options.storageBucket = "vip-lounge-f3730.appspot.com"
        // Note: Bundle ID comes from target settings; options.bundleID is set automatically.
        FirebaseApp.configure(options: options)
        NSLog("[Firebase] Configured with inline FirebaseOptions fallback.")
      }
    }
    GeneratedPluginRegistrant.register(with: self)
    // Ensure notifications delegate and APNs registration are set up
    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()
    if let app = FirebaseApp.app() {
      let opts = app.options
      NSLog("[Firebase] Active options => appID: \(opts.googleAppID), projectID: \(opts.projectID ?? "nil"), gcmSenderID: \(opts.gcmSenderID ?? "nil"), storageBucket: \(opts.storageBucket ?? "nil")")
    } else {
      NSLog("[Firebase] ERROR: FirebaseApp not configured at end of didFinishLaunching")
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
