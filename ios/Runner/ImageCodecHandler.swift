import Flutter
import UIKit

/// HEIC/HEIF → JPEG for formats the Dart image package cannot decode.
enum ImageCodecHandler {
  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "app.atl.scanme/image_codec",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "heicToJpeg" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let args = call.arguments as? [String: Any],
        let path = args["path"] as? String
      else {
        result(
          FlutterError(code: "bad_args", message: "path required", details: nil)
        )
        return
      }
      guard let image = UIImage(contentsOfFile: path),
            let data = image.jpegData(compressionQuality: 0.9)
      else {
        result(
          FlutterError(
            code: "decode",
            message: "Could not decode HEIC",
            details: nil
          )
        )
        return
      }
      result(FlutterStandardTypedData(bytes: data))
    }
  }
}
