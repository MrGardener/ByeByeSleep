import Flutter
import UIKit

#if canImport(AlarmKit)
  import AlarmKit
  import AppIntents
  import SwiftUI
#endif

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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AlarmKitChannel") {
      AlarmKitChannel.register(with: registrar)
    }
  }
}

/// Native side of `byebyesleep/alarmkit` (lib/alarm/ios/ios_engine.dart).
/// Dart decides when to ring; this keeps AlarmKit's alarms equal to that plan.
class AlarmKitChannel: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "byebyesleep/alarmkit", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(AlarmKitChannel(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "openSettings":
      if let url = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(url)
      }
      result(nil)
    case "authorization", "requestAuthorization", "sync":
      #if canImport(AlarmKit)
        if #available(iOS 26.0, *) {
          Task { @MainActor in
            do {
              result(try await AlarmKitBridge.handle(call.method, call.arguments))
            } catch {
              result(
                FlutterError(
                  code: "alarmkit", message: error.localizedDescription, details: nil))
            }
          }
          return
        }
      #endif
      result(call.method == "sync" ? nil : "unsupported")
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

#if canImport(AlarmKit)
  @available(iOS 26.0, *)
  struct ByeByeSleepAlarm: AlarmMetadata {}

  /// The alert's second button: opens the app on the alarm's challenges
  /// (lib/ringing/ring_launcher.dart notices the ringing alarm).
  @available(iOS 26.0, *)
  struct StartChallengesIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Start challenges"
    static let openAppWhenRun = true
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult { .result() }
  }

  @available(iOS 26.0, *)
  @MainActor
  enum AlarmKitBridge {
    /// Plan key ("alarmId@epochMs") → AlarmKit id, kept across launches.
    private static let idsKey = "alarmkit.ids"

    static func handle(_ method: String, _ arguments: Any?) async throws -> Any? {
      let manager = AlarmManager.shared
      switch method {
      case "authorization":
        return name(manager.authorizationState)
      case "requestAuthorization":
        return name(try await manager.requestAuthorization())
      default:
        try await sync(arguments as? [[String: Any]] ?? [])
        return nil
      }
    }

    private static func name(_ state: AlarmManager.AuthorizationState) -> String {
      switch state {
      case .authorized: return "authorized"
      case .denied: return "denied"
      case .notDetermined: return "notDetermined"
      @unknown default: return "denied"
      }
    }

    private static func sync(_ plan: [[String: Any]]) async throws {
      let manager = AlarmManager.shared
      var ids = UserDefaults.standard.dictionary(forKey: idsKey) as? [String: String] ?? [:]
      var wanted: [String: [String: Any]] = [:]
      for ring in plan {
        if let key = ring["key"] as? String { wanted[key] = ring }
      }
      // Cancel what is no longer planned, including alarms we lost track of.
      let known = Set(ids.values)
      for alarm in try manager.alarms where !known.contains(alarm.id.uuidString) {
        try? manager.cancel(id: alarm.id)
      }
      for (key, uuid) in ids where wanted[key] == nil {
        if let id = UUID(uuidString: uuid) { try? manager.cancel(id: id) }
        ids[key] = nil
      }
      let now = Date()
      for (key, ring) in wanted where ids[key] == nil {
        guard let atMs = (ring["atMs"] as? NSNumber)?.doubleValue else { continue }
        let date = Date(timeIntervalSince1970: atMs / 1000)
        if date <= now { continue }
        let title = ring["title"] as? String ?? "Alarm"
        let id = UUID()
        do {
          _ = try await manager.schedule(
            id: id, configuration: configuration(title: title, at: date))
          ids[key] = id.uuidString
        } catch {
          // Keep the others; the next sync retries this one.
        }
      }
      UserDefaults.standard.set(ids, forKey: idsKey)
    }

    private static func configuration(title: String, at date: Date)
      -> AlarmManager.AlarmConfiguration<ByeByeSleepAlarm>
    {
      let alert = AlarmPresentation.Alert(
        title: LocalizedStringResource(stringLiteral: title),
        stopButton: AlarmButton(
          text: "Stop", textColor: .white, systemImageName: "stop.circle"),
        secondaryButton: AlarmButton(
          text: "Challenges", textColor: .white, systemImageName: "figure.walk"),
        secondaryButtonBehavior: .custom)
      let attributes = AlarmAttributes<ByeByeSleepAlarm>(
        presentation: AlarmPresentation(alert: alert), tintColor: .orange)
      return .alarm(
        schedule: .fixed(date),
        attributes: attributes,
        secondaryIntent: StartChallengesIntent())
    }
  }
#endif
