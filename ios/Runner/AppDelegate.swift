import Flutter
import UIKit
import UserNotifications

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
    // Timer and bedtime notifications also show while the app is open.
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let id = notification.request.identifier
    if id.hasPrefix(TimerChannel.idPrefix) || id.hasPrefix(NotifyChannel.bedtimePrefix) {
      completionHandler([.banner, .sound, .list])
      return
    }
    super.userNotificationCenter(
      center, willPresent: notification, withCompletionHandler: completionHandler)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AlarmKitChannel") {
      AlarmKitChannel.register(with: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ZonesChannel") {
      ZonesChannel.register(with: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "TimerChannel") {
      TimerChannel.register(with: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "NotifyChannel") {
      NotifyChannel.register(with: registrar)
    }
  }
}

/// UTC offsets of time zones for the world clocks (lib/tools/world_clock.dart).
class ZonesChannel: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "byebyesleep/zones", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(ZonesChannel(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "offsets", let args = call.arguments as? [String: Any] else {
      result(FlutterMethodNotImplemented)
      return
    }
    let zones = args["zones"] as? [String] ?? []
    let atMs = (args["atMs"] as? NSNumber)?.doubleValue ?? Date().timeIntervalSince1970 * 1000
    let date = Date(timeIntervalSince1970: atMs / 1000)
    var offsets: [String: Int] = [:]
    for id in zones {
      if let zone = TimeZone(identifier: id) { offsets[id] = zone.secondsFromGMT(for: date) }
    }
    result(offsets)
  }
}

/// Local notifications for timers (fallback) and the bedtime reminder.
enum LocalNotifications {
  /// Asks for permission the first time; true when notifications may show.
  @discardableResult
  static func ensureAuthorized() async -> Bool {
    let center = UNUserNotificationCenter.current()
    switch await center.notificationSettings().authorizationStatus {
    case .authorized, .provisional, .ephemeral:
      return true
    case .notDetermined:
      return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    default:
      return false
    }
  }

  /// wallClock: at that local time even if the clock or time zone changes
  /// (bedtime); otherwise after exactly that long (timers).
  static func schedule(
    id: String, at date: Date, title: String, body: String, timeSensitive: Bool,
    wallClock: Bool
  ) async throws {
    await ensureAuthorized()
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    // Critical alerts need an entitlement we do not have.
    if timeSensitive { content.interruptionLevel = .timeSensitive }
    let trigger: UNNotificationTrigger
    if wallClock {
      let parts = Calendar.current.dateComponents(
        [.year, .month, .day, .hour, .minute, .second], from: date)
      trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
    } else {
      trigger = UNTimeIntervalNotificationTrigger(
        timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
    }
    try await UNUserNotificationCenter.current().add(
      UNNotificationRequest(identifier: id, content: content, trigger: trigger))
  }

  /// Removes pending and shown notifications with these ids.
  static func remove(ids: [String]) {
    let center = UNUserNotificationCenter.current()
    center.removePendingNotificationRequests(withIdentifiers: ids)
    center.removeDeliveredNotifications(withIdentifiers: ids)
  }

  /// Removes the pending notifications whose id starts with prefix; one
  /// already shown stays (re-planning must not wipe tonight's reminder).
  static func cancelPending(prefix: String) async {
    let center = UNUserNotificationCenter.current()
    let ids = await center.pendingNotificationRequests()
      .map { $0.identifier }
      .filter { $0.hasPrefix(prefix) }
    center.removePendingNotificationRequests(withIdentifiers: ids)
  }
}

/// Native side of `byebyesleep/notify` (lib/tools/ios_bedtime.dart): Dart
/// plans the bedtime reminders, this schedules them.
class NotifyChannel: NSObject, FlutterPlugin {
  static let bedtimePrefix = "bedtime-"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "byebyesleep/notify", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(NotifyChannel(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "schedule":
      guard let id = args["id"] as? String,
        let atMs = (args["atMs"] as? NSNumber)?.doubleValue
      else {
        result(FlutterError(code: "notify", message: "id and atMs needed", details: nil))
        return
      }
      let date = Date(timeIntervalSince1970: atMs / 1000)
      let title = args["title"] as? String ?? ""
      let body = args["body"] as? String ?? ""
      Task { @MainActor in
        do {
          if date > Date() {
            try await LocalNotifications.schedule(
              id: id, at: date, title: title, body: body, timeSensitive: false,
              wallClock: true)
          }
          result(nil)
        } catch {
          result(FlutterError(code: "notify", message: error.localizedDescription, details: nil))
        }
      }
    case "cancelPrefix":
      let prefix = args["prefix"] as? String ?? ""
      Task { @MainActor in
        if !prefix.isEmpty { await LocalNotifications.cancelPending(prefix: prefix) }
        result(nil)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

/// Native side of `byebyesleep/timer` (lib/tools/timer_bell.dart): rings when
/// a timer ends, also with the app closed. With AlarmKit allowed (the same
/// permission as the alarms) it is a real alarm that sounds through silent
/// mode and Focus; otherwise a time-sensitive notification.
class TimerChannel: NSObject, FlutterPlugin {
  static let idPrefix = "timer-"

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "byebyesleep/timer", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(TimerChannel(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    let id = (args["id"] as? NSNumber)?.intValue ?? 0
    switch call.method {
    case "schedule":
      guard let atMs = (args["atMs"] as? NSNumber)?.doubleValue else {
        result(FlutterError(code: "timer", message: "atMs needed", details: nil))
        return
      }
      let date = Date(timeIntervalSince1970: atMs / 1000)
      let label = args["label"] as? String ?? "Timer"
      Task { @MainActor in
        do {
          try await TimerChannel.schedule(id: id, at: date, label: label)
          result(nil)
        } catch {
          result(FlutterError(code: "timer", message: error.localizedDescription, details: nil))
        }
      }
    case "cancel":
      Task { @MainActor in
        TimerChannel.cancel(id: id)
        result(nil)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @MainActor
  static func schedule(id: Int, at date: Date, label: String) async throws {
    // Replaces this timer's bell (e.g. after "+1 min").
    cancel(id: id)
    #if canImport(AlarmKit)
      if #available(iOS 26.0, *) {
        if await TimerAlarms.schedule(id: id, at: date, label: label) { return }
      }
    #endif
    try await LocalNotifications.schedule(
      id: "\(idPrefix)\(id)", at: date, title: "Time's up", body: label, timeSensitive: true,
      wallClock: false)
  }

  /// Cancels a pending timer and silences one that is ringing.
  @MainActor
  static func cancel(id: Int) {
    #if canImport(AlarmKit)
      if #available(iOS 26.0, *) { TimerAlarms.cancel(id: id) }
    #endif
    LocalNotifications.remove(ids: ["\(idPrefix)\(id)"])
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
      // Cancel what is no longer planned, including alarms we lost track of
      // (but never a timer's: TimerAlarms keeps those).
      let known = Set(ids.values).union(TimerAlarms.uuids())
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
  /// AlarmKit alarms for timers, apart from the alarm plan: AlarmKitBridge.sync
  /// leaves every id kept here alone.
  @available(iOS 26.0, *)
  @MainActor
  enum TimerAlarms {
    /// Timer id -> AlarmKit id, kept across launches.
    private static let key = "alarmkit.timers"
    /// Timers being scheduled right now (kept even before AlarmKit lists them).
    private static var scheduling: Set<String> = []

    private static func stored() -> [String: String] {
      UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:]
    }

    private static func store(_ map: [String: String]) {
      UserDefaults.standard.set(map, forKey: key)
    }

    /// Every AlarmKit id that belongs to a timer.
    static func uuids() -> Set<String> { Set(stored().values) }

    /// False when AlarmKit is not allowed or failed: use a notification.
    static func schedule(id: Int, at date: Date, label: String) async -> Bool {
      let manager = AlarmManager.shared
      var state = manager.authorizationState
      if state == .notDetermined {
        state = (try? await manager.requestAuthorization()) ?? .denied
      }
      guard state == .authorized, date > Date() else { return false }
      let timer = String(id)
      let uuid = UUID()
      // Recorded before scheduling, so a sync running meanwhile keeps it.
      var map = stored()
      map[timer] = uuid.uuidString
      store(map)
      scheduling.insert(timer)
      defer { scheduling.remove(timer) }
      do {
        _ = try await manager.schedule(
          id: uuid, configuration: configuration(label: label, at: date))
        return true
      } catch {
        var map = stored()
        if map[timer] == uuid.uuidString { map[timer] = nil }
        store(map)
        return false
      }
    }

    static func cancel(id: Int) {
      let manager = AlarmManager.shared
      var map = stored()
      if let s = map[String(id)], let uuid = UUID(uuidString: s) {
        try? manager.stop(id: uuid)
        try? manager.cancel(id: uuid)
      }
      map[String(id)] = nil
      // Forget timers that already rang and were stopped.
      if let alarms = try? manager.alarms {
        let live = Set(alarms.map { $0.id.uuidString })
        map = map.filter { live.contains($0.value) || scheduling.contains($0.key) }
      }
      store(map)
    }

    private static func configuration(label: String, at date: Date)
      -> AlarmManager.AlarmConfiguration<ByeByeSleepAlarm>
    {
      let alert = AlarmPresentation.Alert(
        title: LocalizedStringResource(stringLiteral: "Time's up · \(label)"),
        stopButton: AlarmButton(
          text: "Stop", textColor: .white, systemImageName: "stop.circle"),
        secondaryButton: nil,
        secondaryButtonBehavior: nil)
      let attributes = AlarmAttributes<ByeByeSleepAlarm>(
        presentation: AlarmPresentation(alert: alert), tintColor: .orange)
      return .alarm(schedule: .fixed(date), attributes: attributes)
    }
  }
#endif
