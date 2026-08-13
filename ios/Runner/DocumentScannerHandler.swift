import Flutter
import UIKit
import VisionKit

/// VisionKit document scanner — returns JPEG paths (color originals).
/// B&W / compression run in Dart.
final class DocumentScannerHandler: NSObject, VNDocumentCameraViewControllerDelegate {
  private var pendingResult: FlutterResult?
  private weak var presenter: UIViewController?

  func scan(presenter: UIViewController, result: @escaping FlutterResult) {
    guard VNDocumentCameraViewController.isSupported else {
      result(
        FlutterError(
          code: "UNSUPPORTED",
          message: "Document scanner is not supported on this device",
          details: nil
        )
      )
      return
    }
    if pendingResult != nil {
      result(
        FlutterError(
          code: "BUSY",
          message: "Scan already in progress",
          details: nil
        )
      )
      return
    }
    pendingResult = result
    self.presenter = presenter
    let controller = VNDocumentCameraViewController()
    controller.delegate = self
    presenter.present(controller, animated: true)
  }

  func documentCameraViewController(
    _ controller: VNDocumentCameraViewController,
    didFinishWith scan: VNDocumentCameraScan
  ) {
    controller.dismiss(animated: true)
    let pageCount = scan.pageCount
    var pageImages: [UIImage] = []
    pageImages.reserveCapacity(pageCount)
    for index in 0..<pageCount {
      pageImages.append(scan.imageOfPage(at: index))
    }

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      var paths: [String] = []
      for image in pageImages {
        let oriented = self.normalizedOrientation(image)
        if let path = self.saveJpegToCache(oriented) {
          paths.append(path)
        }
      }
      DispatchQueue.main.async {
        defer {
          self.pendingResult = nil
          self.presenter = nil
        }
        if paths.isEmpty {
          self.pendingResult?(
            FlutterError(
              code: "NO_PAGES",
              message: "No pages returned from scanner",
              details: nil
            )
          )
        } else {
          self.pendingResult?(paths)
        }
      }
    }
  }

  func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
    controller.dismiss(animated: true)
    pendingResult?(
      FlutterError(
        code: "CANCELLED",
        message: "User cancelled scan",
        details: nil
      )
    )
    pendingResult = nil
    presenter = nil
  }

  func documentCameraViewController(
    _ controller: VNDocumentCameraViewController,
    didFailWithError error: Error
  ) {
    controller.dismiss(animated: true)
    pendingResult?(
      FlutterError(
        code: "SCAN_FAILED",
        message: error.localizedDescription,
        details: nil
      )
    )
    pendingResult = nil
    presenter = nil
  }

  private func normalizedOrientation(_ image: UIImage) -> UIImage {
    if image.imageOrientation == .up { return image }
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = image.scale
    let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
    return renderer.image { _ in
      image.draw(in: CGRect(origin: .zero, size: image.size))
    }
  }

  private func saveJpegToCache(_ image: UIImage) -> String? {
    guard let data = image.jpegData(compressionQuality: 0.92) else { return nil }
    let dir = FileManager.default.temporaryDirectory
    let name = "scan_\(Int(Date().timeIntervalSince1970 * 1000))_\(UUID().uuidString).jpg"
    let url = dir.appendingPathComponent(name)
    do {
      try data.write(to: url, options: .atomic)
      return url.path
    } catch {
      return nil
    }
  }
}
