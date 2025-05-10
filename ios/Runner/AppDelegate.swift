import Flutter
import UIKit
import CoreLocation

@main
@objc class AppDelegate: FlutterAppDelegate, CLLocationManagerDelegate {
  let locationManager = CLLocationManager()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let locationChannel = FlutterMethodChannel(name: "com.yourcompany.vip/location",
                                              binaryMessenger: controller.binaryMessenger)
    locationChannel.setMethodCallHandler({ [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "getCurrentLocation" {
        self?.getCurrentLocation(result: result)
      } else {
        result(FlutterMethodNotImplemented)
      }
    })
    locationManager.delegate = self
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private var flutterLocationResult: FlutterResult?

  private func getCurrentLocation(result: @escaping FlutterResult) {
    locationManager.requestWhenInUseAuthorization()
    if CLLocationManager.locationServicesEnabled() {
      flutterLocationResult = result
      locationManager.requestLocation()
    } else {
      result(FlutterError(code: "PERMISSION_DENIED", message: "Location permission not granted", details: nil))
    }
  }

  // CLLocationManagerDelegate method
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    if let location = locations.last {
      flutterLocationResult?(["latitude": location.coordinate.latitude, "longitude": location.coordinate.longitude])
      flutterLocationResult = nil
    }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    flutterLocationResult?(FlutterError(code: "LOCATION_ERROR", message: "Could not fetch location", details: error.localizedDescription))
    flutterLocationResult = nil
  }
}
