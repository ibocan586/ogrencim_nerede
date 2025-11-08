import UIKit
import Flutter
import GoogleMaps   // ✅ Google Maps kütüphanesini ekledik

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // ✅ Google Maps API anahtarını burada veriyoruz
    GMSServices.provideAPIKey("AIzaSyB20HiIBPVqfF8gAVCLCcC9qV-eiBEF_V8")

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
