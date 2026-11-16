import Flutter
import UIKit

/// Bridges iOS “Open in ReadBeat” document URLs into Dart.
enum IncomingFilesBridge {
  static let channelName = "read_beat/open_files"
  private static var channel: FlutterMethodChannel?
  private static var pending: [[String: String]] = []

  private static let allowedExtensions: Set<String> = ["epub", "pdf", "mp3", "m4a"]

  static func attach(to messenger: FlutterBinaryMessenger) {
    let ch = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel = ch
    ch.setMethodCallHandler { call, result in
      switch call.method {
      case "getInitial":
        result(pending)
        pending.removeAll()
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  static func handle(urlContexts: Set<UIOpenURLContext>) -> Bool {
    let paths = urlContexts.compactMap { ingest(url: $0.url) }
    guard !paths.isEmpty else { return false }
    deliver(paths: paths)
    return true
  }

  static func handle(connectionOptions: UIScene.ConnectionOptions) {
    let paths = connectionOptions.urlContexts.compactMap { ingest(url: $0.url) }
    guard !paths.isEmpty else { return }
    deliver(paths: paths)
  }

  private static func deliver(paths: [String]) {
    let payload = paths.map { path -> [String: String] in
      [
        "path": path,
        "name": URL(fileURLWithPath: path).lastPathComponent,
      ]
    }
    // Always queue — Dart may not have set a method handler yet.
    pending.append(contentsOf: payload)
    channel?.invokeMethod("onFiles", arguments: payload)
  }

  /// Copies a security-scoped document into a temp folder the Dart side can read.
  private static func ingest(url: URL) -> String? {
    // Share-extension custom scheme is handled by receive_sharing_intent.
    if url.scheme?.lowercased().hasPrefix("sharemedia") == true { return nil }

    let ext = url.pathExtension.lowercased()
    guard allowedExtensions.contains(ext) else { return nil }

    let accessing = url.startAccessingSecurityScopedResource()
    defer {
      if accessing { url.stopAccessingSecurityScopedResource() }
    }

    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("read_beat_incoming", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    do {
      try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
      let dest = dir.appendingPathComponent(url.lastPathComponent)
      if FileManager.default.fileExists(atPath: dest.path) {
        try FileManager.default.removeItem(at: dest)
      }
      try FileManager.default.copyItem(at: url, to: dest)
      return dest.path
    } catch {
      NSLog("IncomingFilesBridge failed to copy %@: %@", url.path, error.localizedDescription)
      return nil
    }
  }
}
