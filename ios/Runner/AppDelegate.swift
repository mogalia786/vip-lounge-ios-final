import Flutter
import FirebaseCore
import FirebaseMessaging
import UIKit
import UserNotifications
import EventKit
import CoreLocation

// Lightweight EventKit bridge exposed via Flutter MethodChannel.
// Embedded here to ensure it's compiled without extra Xcode project edits.
final class CalendarBridge {
  private let eventStore = EKEventStore()
  private let channel: FlutterMethodChannel

  init(messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(name: "com.vip/calendar", binaryMessenger: messenger)
    self.channel.setMethodCallHandler(handle)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "addEvent":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "BAD_ARGS", message: "Arguments must be a map", details: nil))
        return
      }
      addEvent(args: args, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func addEvent(args: [String: Any], result: @escaping FlutterResult) {
    let title = args["title"] as? String ?? ""
    let notes = args["description"] as? String
    let location = args["location"] as? String
    let startMillis = args["startMillis"] as? Int64 ?? 0
    let endMillis = args["endMillis"] as? Int64 ?? 0
    let reminderMinutes = args["reminderMinutes"] as? Int ?? 0

    if title.isEmpty || startMillis <= 0 || endMillis <= 0 {
      result(FlutterError(code: "BAD_ARGS", message: "title/startMillis/endMillis are required", details: nil))
      return
    }

    eventStore.requestAccess(to: .event) { [weak self] granted, error in
      if let error = error {
        result(FlutterError(code: "PERMISSION_ERROR", message: error.localizedDescription, details: nil))
        return
      }
      guard granted, let self = self else {
        result(false)
        return
      }

      let event = EKEvent(eventStore: self.eventStore)
      event.title = title
      event.location = location
      event.notes = notes
      event.startDate = Date(timeIntervalSince1970: TimeInterval(startMillis) / 1000.0)
      event.endDate = Date(timeIntervalSince1970: TimeInterval(endMillis) / 1000.0)
      event.calendar = self.eventStore.defaultCalendarForNewEvents

      if reminderMinutes > 0 {
        let alarm = EKAlarm(relativeOffset: -TimeInterval(reminderMinutes * 60))
        event.addAlarm(alarm)
      }

      do {
        try self.eventStore.save(event, span: .thisEvent, commit: true)
        result(true)
      } catch {
        result(FlutterError(code: "SAVE_ERROR", message: error.localizedDescription, details: nil))
      }
    }
  }
}

// Lightweight CoreLocation bridge exposed via Flutter MethodChannel.
final class LocationBridge: NSObject, CLLocationManagerDelegate {
  private let manager = CLLocationManager()
  private let channel: FlutterMethodChannel
  private var pendingResult: FlutterResult?

  init(messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(name: "com.yourcompany.vip/location", binaryMessenger: messenger)
    super.init()
    self.channel.setMethodCallHandler(handle)
    self.manager.delegate = self
    self.manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getCurrentLocation":
      getCurrentLocation(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func getCurrentLocation(result: @escaping FlutterResult) {
    // Avoid multiple concurrent requests
    if pendingResult != nil {
      result(FlutterError(code: "BUSY", message: "Location request already in progress", details: nil))
      return
    }
    pendingResult = result

    let status = CLLocationManager.authorizationStatus()
    switch status {
    case .notDetermined:
      manager.requestWhenInUseAuthorization()
    case .restricted, .denied:
      finishWithError(code: "PERMISSION_DENIED", message: "Location permission denied")
    case .authorizedWhenInUse, .authorizedAlways:
      manager.requestLocation()
    @unknown default:
      finishWithError(code: "PERMISSION_UNKNOWN", message: "Unknown authorization status")
    }
  }

  func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    guard pendingResult != nil else { return }
    switch status {
    case .authorizedWhenInUse, .authorizedAlways:
      manager.requestLocation()
    case .denied, .restricted:
      finishWithError(code: "PERMISSION_DENIED", message: "Location permission denied")
    case .notDetermined:
      break
    @unknown default:
      finishWithError(code: "PERMISSION_UNKNOWN", message: "Unknown authorization status")
    }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    finishWithError(code: "LOCATION_ERROR", message: error.localizedDescription)
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let loc = locations.last else {
      finishWithError(code: "NO_LOCATION", message: "No location available")
      return
    }
    let payload: [String: Any] = [
      "latitude": loc.coordinate.latitude,
      "longitude": loc.coordinate.longitude
    ]
    if let res = pendingResult { res(payload) }
    pendingResult = nil
  }

  private func finishWithError(code: String, message: String) {
    if let res = pendingResult { res(FlutterError(code: code, message: message, details: nil)) }
    pendingResult = nil
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate {
  // Retain the calendar bridge so the channel stays alive
  var calendarBridge: CalendarBridge?
  // Retain the location bridge so the channel stays alive
  var locationBridge: LocationBridge?
  // Keep willFinish lightweight to avoid first-boot stalls
  override func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    NSLog("[Launch] willFinishLaunchingWithOptions: enter")
    return true
  }
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    NSLog("[Launch] didFinishLaunchingWithOptions: enter")
    // TEMP: Minimal native init to isolate white screen on first boot
    // Ensure Flutter engine is fully initialized before registering plugins (prevents nil registrar on device)
    let superResult = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    NSLog("[Launch] super.application returned: \(superResult)")
    // Ensure any interim background is black instead of white while waiting for first frame
    if let win = self.window {
      win.backgroundColor = UIColor.black
    } else {
      self.window?.backgroundColor = UIColor.black
    }
    // Explicitly create and run a FlutterEngine, then attach a FlutterViewController
    NSLog("[Launch] Creating FlutterEngine 'primary'")
    let engine = FlutterEngine(name: "primary")
    let ran = engine.run()
    NSLog("[Launch] engine.run() => \(ran)")
    // Register plugins for this engine (GeneratedPluginRegistrant honors commented-out plugins)
    GeneratedPluginRegistrant.register(with: engine)
    let flutterVC = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
    // Set notification center delegate to receive foreground notifications
    UNUserNotificationCenter.current().delegate = self
    // Initialize native bridges for iOS MethodChannel usage
    self.calendarBridge = CalendarBridge(messenger: flutterVC.binaryMessenger)
    self.locationBridge = LocationBridge(messenger: flutterVC.binaryMessenger)
    if self.window == nil {
      self.window = UIWindow(frame: UIScreen.main.bounds)
    }
    self.window?.rootViewController = flutterVC
    self.window?.makeKeyAndVisible()
    self.window?.backgroundColor = UIColor.black
    NSLog("[Launch] FlutterViewController attached and window visible")
    // Native temporary overlay to avoid a black gap between launch screen and first Flutter frame
    if let win = self.window, let splash = UIImage(named: "LaunchImage") {
      let overlay = UIImageView(frame: win.bounds)
      overlay.image = splash
      overlay.contentMode = .scaleAspectFill
      overlay.translatesAutoresizingMaskIntoConstraints = false
      win.addSubview(overlay)
      NSLayoutConstraint.activate([
        overlay.leadingAnchor.constraint(equalTo: win.leadingAnchor),
        overlay.trailingAnchor.constraint(equalTo: win.trailingAnchor),
        overlay.topAnchor.constraint(equalTo: win.topAnchor),
        overlay.bottomAnchor.constraint(equalTo: win.bottomAnchor)
      ])
      // Remove overlay shortly after; if needed we can tie this to a Flutter signal later
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
        overlay.removeFromSuperview()
        NSLog("[Launch] Removed native overlay splash")
      }
    }
    // TEMP: Skip plugin registration, calendar bridge init, Firebase configure, and notification delegate
    // Firebase logging disabled during isolation
    // if let app = FirebaseApp.app() {
    //   let opts = app.options
    //   NSLog("[Firebase] Active options => appID: \(opts.googleAppID), projectID: \(opts.projectID ?? "nil"), gcmSenderID: \(opts.gcmSenderID ?? "nil"), storageBucket: \(opts.storageBucket ?? "nil")")
    // } else {
    //   NSLog("[Firebase] ERROR: FirebaseApp not configured at end of didFinishLaunching")
    // }
    NSLog("[Launch] didFinishLaunchingWithOptions: exit -> \(superResult)")
    return superResult
  }

  // Bridge APNs token to Firebase Messaging so FCM can deliver notifications on iOS
  override func application(_ application: UIApplication,
                            didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    Messaging.messaging().apnsToken = deviceToken
    let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    NSLog("[APNs] Device token: \(tokenString)")
  }

  // Foreground presentation options
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       willPresent notification: UNNotification,
                                       withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    completionHandler([.banner, .list, .sound, .badge])
  }

  override func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       didReceive response: UNNotificationResponse,
                                       withCompletionHandler completionHandler: @escaping () -> Void) {
    completionHandler()
  }
}
