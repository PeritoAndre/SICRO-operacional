import Flutter
import UIKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    SicroNativeBridge.shared.register(with: engineBridge.pluginRegistry)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    if SicroNativeBridge.shared.handleIncomingUrl(url) {
      return true
    }
    return super.application(app, open: url, options: options)
  }
}

private enum DocumentPickKind {
  case pdf
  case backup
}

final class SicroNativeBridge: NSObject, UIDocumentPickerDelegate {
  static let shared = SicroNativeBridge()

  private let packageChannelName =
    "br.gov.ap.policiacientifica.sicro_operacional/package_import"
  private let documentPickerChannelName =
    "br.gov.ap.policiacientifica.sicro_operacional/document_picker"

  private var packageChannel: FlutterMethodChannel?
  private var documentPickerChannel: FlutterMethodChannel?
  private var pendingPackage: [String: Any]?
  private var pendingPickerResult: FlutterResult?
  private var pendingPickerKind: DocumentPickKind?
  private var lastConsumedUrlKey: String?

  func register(with registry: FlutterPluginRegistry) {
    let packageRegistrar = registry.registrar(forPlugin: "SicroPackageImportPlugin")
    packageChannel = FlutterMethodChannel(
      name: packageChannelName,
      binaryMessenger: packageRegistrar.messenger()
    )
    packageChannel?.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(nil)
        return
      }
      switch call.method {
      case "getInitialPackage":
        let payload = self.pendingPackage
        self.pendingPackage = nil
        result(payload)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let documentRegistrar = registry.registrar(forPlugin: "SicroDocumentPickerPlugin")
    documentPickerChannel = FlutterMethodChannel(
      name: documentPickerChannelName,
      binaryMessenger: documentRegistrar.messenger()
    )
    documentPickerChannel?.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(nil)
        return
      }
      switch call.method {
      case "pickPdf":
        self.presentDocumentPicker(kind: .pdf, result: result)
      case "pickBackup":
        self.presentDocumentPicker(kind: .backup, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  @discardableResult
  func handleIncomingUrl(_ url: URL) -> Bool {
    guard isSupportedPackageUrl(url) else {
      return false
    }
    let urlKey = url.absoluteString
    if urlKey == lastConsumedUrlKey {
      return true
    }
    lastConsumedUrlKey = urlKey

    let payload = copyPackageFromUrl(url)
    if let channel = packageChannel {
      channel.invokeMethod("packageReceived", arguments: payload)
    } else {
      pendingPackage = payload
    }
    return true
  }

  private func presentDocumentPicker(kind: DocumentPickKind, result: @escaping FlutterResult) {
    guard pendingPickerResult == nil else {
      result(
        FlutterError(
          code: "document_picker_busy",
          message: "Ja existe uma selecao de documento em andamento.",
          details: nil
        )
      )
      return
    }

    guard let presenter = topViewController() else {
      result(
        FlutterError(
          code: "document_picker_error",
          message: "Nao foi possivel abrir o seletor de arquivos.",
          details: nil
        )
      )
      return
    }

    pendingPickerResult = result
    pendingPickerKind = kind

    let picker = UIDocumentPickerViewController(
      forOpeningContentTypes: contentTypes(for: kind),
      asCopy: true
    )
    picker.delegate = self
    picker.allowsMultipleSelection = false
    presenter.present(picker, animated: true)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    completePendingPicker(nil)
  }

  func documentPicker(
    _ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]
  ) {
    guard let url = urls.first, let kind = pendingPickerKind else {
      completePendingPicker(nil)
      return
    }

    let payload: [String: Any]
    switch kind {
    case .pdf:
      payload = copyDocumentToInternalStorage(
        url,
        fallbackName: "escala.pdf",
        destinationSubdir: "sicro_operacional/selected_documents",
        safeNameProvider: safePdfFileName
      )
    case .backup:
      payload = copyDocumentToInternalStorage(
        url,
        fallbackName: "backup.sicrobackup",
        destinationSubdir: "sicro_operacional/selected_backups",
        safeNameProvider: safeBackupFileName
      )
    }
    completePendingPicker(payload)
  }

  private func completePendingPicker(_ payload: [String: Any]?) {
    let result = pendingPickerResult
    pendingPickerResult = nil
    pendingPickerKind = nil
    result?(payload)
  }

  private func copyPackageFromUrl(_ url: URL) -> [String: Any] {
    copyDocumentToInternalStorage(
      url,
      fallbackName: "pacote_recebido.sicroapp",
      destinationSubdir: "sicro_operacional/imports",
      safeNameProvider: safePackageFileName
    )
  }

  private func copyDocumentToInternalStorage(
    _ url: URL,
    fallbackName: String,
    destinationSubdir: String,
    safeNameProvider: (String) -> String
  ) -> [String: Any] {
    let accessed = url.startAccessingSecurityScopedResource()
    defer {
      if accessed {
        url.stopAccessingSecurityScopedResource()
      }
    }

    do {
      let originalName = url.lastPathComponent.isEmpty ? fallbackName : url.lastPathComponent
      let timestamp = Int(Date().timeIntervalSince1970 * 1000)
      let safeName = safeNameProvider(originalName)
      let destinationDir = try destinationDirectory(for: destinationSubdir)
      let destination = destinationDir.appendingPathComponent("\(timestamp)_\(safeName)")

      if FileManager.default.fileExists(atPath: destination.path) {
        try FileManager.default.removeItem(at: destination)
      }
      try FileManager.default.copyItem(at: url, to: destination)

      return [
        "ok": true,
        "filePath": destination.path,
        "fileName": destination.lastPathComponent,
        "originalName": originalName,
        "sourceUri": url.absoluteString,
        "mimeType": mimeType(for: originalName),
        "sizeBytes": fileSize(destination),
        "sourceSizeBytes": fileSize(url),
        "receivedAtMillis": timestamp
      ]
    } catch {
      return [
        "ok": false,
        "filePath": "",
        "fileName": "",
        "originalName": url.lastPathComponent,
        "sourceUri": url.absoluteString,
        "mimeType": mimeType(for: url.lastPathComponent),
        "sizeBytes": 0,
        "sourceSizeBytes": fileSize(url),
        "receivedAtMillis": Int(Date().timeIntervalSince1970 * 1000),
        "error": error.localizedDescription
      ]
    }
  }

  private func contentTypes(for kind: DocumentPickKind) -> [UTType] {
    switch kind {
    case .pdf:
      return [.pdf]
    case .backup:
      return [
        UTType(filenameExtension: "sicrobackup"),
        UTType(filenameExtension: "zip"),
        UTType(filenameExtension: "bin"),
        .data
      ].compactMap { $0 }
    }
  }

  private func destinationDirectory(for subdir: String) throws -> URL {
    let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let directory = base.appendingPathComponent(subdir, isDirectory: true)
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    return directory
  }

  private func topViewController(
    _ base: UIViewController? = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }?
      .rootViewController
  ) -> UIViewController? {
    if let navigation = base as? UINavigationController {
      return topViewController(navigation.visibleViewController)
    }
    if let tab = base as? UITabBarController {
      return topViewController(tab.selectedViewController)
    }
    if let presented = base?.presentedViewController {
      return topViewController(presented)
    }
    return base
  }

  private func isSupportedPackageUrl(_ url: URL) -> Bool {
    let lower = url.pathExtension.lowercased()
    return ["sicroapp", "sicrobackup", "sicrocampo", "zip", "bin"].contains(lower)
  }

  private func safePackageFileName(_ name: String) -> String {
    let clean = sanitizedFileName(name, fallback: "pacote_recebido.sicroapp")
    let lower = clean.lowercased()
    if lower.hasSuffix(".sicroapp") ||
      lower.hasSuffix(".sicrobackup") ||
      lower.hasSuffix(".sicrocampo") ||
      lower.hasSuffix(".zip") ||
      lower.hasSuffix(".bin") {
      return clean
    }
    return "\(clean).sicroapp"
  }

  private func safePdfFileName(_ name: String) -> String {
    let clean = sanitizedFileName(name, fallback: "escala.pdf")
    return clean.lowercased().hasSuffix(".pdf") ? clean : "\(clean).pdf"
  }

  private func safeBackupFileName(_ name: String) -> String {
    let clean = sanitizedFileName(name, fallback: "backup.sicrobackup")
    let lower = clean.lowercased()
    if lower.hasSuffix(".sicrobackup") ||
      lower.hasSuffix(".zip") ||
      lower.hasSuffix(".bin") {
      return clean
    }
    return "\(clean).sicrobackup"
  }

  private func sanitizedFileName(_ name: String, fallback: String) -> String {
    let cleaned = name
      .replacingOccurrences(
        of: "[^A-Za-z0-9._-]",
        with: "_",
        options: .regularExpression
      )
      .trimmingCharacters(in: CharacterSet(charactersIn: "._-"))
    return cleaned.isEmpty ? fallback : cleaned
  }

  private func fileSize(_ url: URL) -> Int {
    guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
      let size = attributes[.size] as? NSNumber else {
      return 0
    }
    return size.intValue
  }

  private func mimeType(for fileName: String) -> String {
    let lower = fileName.lowercased()
    if lower.hasSuffix(".pdf") {
      return "application/pdf"
    }
    if lower.hasSuffix(".sicrobackup") {
      return "application/vnd.sicrobackup"
    }
    if lower.hasSuffix(".sicroapp") || lower.hasSuffix(".sicrocampo") {
      return "application/vnd.sicroapp"
    }
    if lower.hasSuffix(".zip") {
      return "application/zip"
    }
    return "application/octet-stream"
  }
}
