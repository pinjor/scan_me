import Flutter
import UIKit

/// Copies files opened via “Open in ScanMe” into the app cache and notifies Flutter.
final class OpenFileIntentHandler {
  static let shared = OpenFileIntentHandler()

  private let channelName = "app.atl.scanme/open_file"
  private var channel: FlutterMethodChannel?
  private var pendingPayload: [String: String]?

  private init() {}

  func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      switch call.method {
      case "getInitialFile":
        let payload = self.pendingPayload
        self.pendingPayload = nil
        result(payload)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel
  }

  func handle(url: URL) {
    let accessed = url.startAccessingSecurityScopedResource()
    defer {
      if accessed {
        url.stopAccessingSecurityScopedResource()
      }
    }

    do {
      let name = url.lastPathComponent.isEmpty
        ? "scanme_open_\(Int(Date().timeIntervalSince1970)).bin"
        : url.lastPathComponent
      let dest = FileManager.default.temporaryDirectory
        .appendingPathComponent("incoming_\(name)")
      if FileManager.default.fileExists(atPath: dest.path) {
        dest = FileManager.default.temporaryDirectory
          .appendingPathComponent(
            "incoming_\(Int(Date().timeIntervalSince1970))_\(name)"
          )
      }
      try FileManager.default.copyItem(at: url, to: dest)
      let payload = ["path": dest.path, "action": "view"]
      pendingPayload = payload
      channel?.invokeMethod("onOpenFile", arguments: payload)
    } catch {
      // Ignore — user can reopen.
    }
  }
}
