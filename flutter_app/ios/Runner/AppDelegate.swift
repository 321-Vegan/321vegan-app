import Flutter
import QuickLook
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var filePreview: FilePreview?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Configure local notifications
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }

    GeneratedPluginRegistrant.register(with: self)

    // Files given to the person (lib/helpers/pdf_download.dart)
    if let registrar = registrar(forPlugin: "FilePreview") {
      let channel = FlutterMethodChannel(
        name: "app.321vegan/files", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { [weak self] call, result in
        guard call.method == "previewFile",
          let args = call.arguments as? [String: Any],
          let path = args["path"] as? String
        else {
          result(FlutterMethodNotImplemented)
          return
        }
        guard let presenter = self?.topViewController() else {
          result(FlutterError(code: "no_view", message: "No view to present from", details: nil))
          return
        }
        // Kept while shown: QLPreviewController holds its data source weakly
        let preview = FilePreview(url: URL(fileURLWithPath: path))
        self?.filePreview = preview
        let controller = QLPreviewController()
        controller.dataSource = preview
        presenter.present(controller, animated: true)
        result(nil)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func topViewController() -> UIViewController? {
    var top = window?.rootViewController
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }
}

/// One file shown in a QuickLook preview (its share button saves it to Fichiers).
class FilePreview: NSObject, QLPreviewControllerDataSource {
  let url: URL

  init(url: URL) {
    self.url = url
  }

  func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

  func previewController(_ controller: QLPreviewController, previewItemAt index: Int)
    -> QLPreviewItem
  {
    url as NSURL
  }
}
