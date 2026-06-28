import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as! FlutterViewController
    FlutterMethodChannel(name: "com.example.finazaap/device_info",
                         binaryMessenger: controller.binaryMessenger)
      .setMethodCallHandler { call, result in
        if call.method == "getTotalRam" {
          result(Int64(bitPattern: ProcessInfo.processInfo.physicalMemory))
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
