import Flutter
import UIKit
import VisionKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let documentScanner = DocumentScannerHandler()
  private var scannerChannelRegistered = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerDocumentScannerChannel(
      messenger: engineBridge.applicationRegistrar.messenger()
    )
  }

  private func registerDocumentScannerChannel(
    messenger: FlutterBinaryMessenger
  ) {
    guard !scannerChannelRegistered else { return }
    scannerChannelRegistered = true

    let channel = FlutterMethodChannel(
      name: "app.atl.scanme/document_scanner",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      switch call.method {
      case "isSupported":
        result(VNDocumentCameraViewController.isSupported)
      case "scan":
        guard let presenter = self.topViewController() else {
          result(
            FlutterError(
              code: "NO_PRESENTER",
              message: "Could not find a view controller to present the scanner",
              details: nil
            )
          )
          return
        }
        self.documentScanner.scan(presenter: presenter, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Resolves the top-most VC at scan time (UIScene-safe; avoids nil AppDelegate.window).
  private func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
    let window = scenes
      .flatMap(\.windows)
      .first(where: \.isKeyWindow)
      ?? scenes.first?.windows.first
      ?? self.window
    var top = window?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }
}
