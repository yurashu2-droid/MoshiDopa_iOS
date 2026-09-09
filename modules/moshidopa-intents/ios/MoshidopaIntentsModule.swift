import AppIntents
import ExpoModulesCore
import Foundation

private enum MoshidopaMode: String, Codable {
  case spend = "SPEND"
  case invest = "INVEST"
}

private struct NativeSession: Codable {
  let id: String
  let activityID: String
  let displayName: String
  let mode: MoshidopaMode
  let startedAt: Date
  var endedAt: Date?
  var elapsedMilliseconds: Int64?
  let hourlyWage: Double?
  var state: String
  var diagnostics: [String]
}

private struct NativeEvent: Codable {
  let id: String
  let kind: String
  let createdAt: Date
  let session: NativeSession?
  let diagnostic: String?
}

private struct NativeStoreFile: Codable {
  var configuredHourlyWage: Double?
  var openLastSessionRequested: Bool = false
  var sessions: [NativeSession]
  var events: [NativeEvent]
}

/// A deliberately small, native-owned append queue.
/// App Intents may run while React Native/JavaScript is not running, so this file
/// is the source of truth until the next app launch imports it into SQLite.
///
/// Every access to the mutable file-backed state is serialized by `lock`. The
/// unchecked Sendable conformance is intentional: App Intents can invoke this
/// store from background executors, and the lock is the synchronization
/// boundary for all stored state and encoder/decoder use.
private final class MoshidopaNativeStore: @unchecked Sendable {
  static let shared = MoshidopaNativeStore()

  private let lock = NSLock()
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder
  private let fileURL: URL

  private init() {
    encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    let directory = applicationSupport.appendingPathComponent("Moshidopa", isDirectory: true)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    fileURL = directory.appendingPathComponent("native-event-queue.json")
  }

  private func read() -> NativeStoreFile {
    guard let data = try? Data(contentsOf: fileURL), let value = try? decoder.decode(NativeStoreFile.self, from: data) else {
      return NativeStoreFile(configuredHourlyWage: nil, openLastSessionRequested: false, sessions: [], events: [])
    }
    return value
  }

  private func write(_ value: NativeStoreFile) {
    guard let data = try? encoder.encode(value) else { return }
    try? data.write(to: fileURL, options: [.atomic])
  }

  @discardableResult
  func setHourlyWage(_ wage: Double) throws -> Double {
    guard wage.isFinite, wage > 0 else { throw NativeStoreError.invalidWage }
    lock.lock(); defer { lock.unlock() }
    var value = read()
    value.configuredHourlyWage = wage
    write(value)
    return wage
  }

  func configuredHourlyWage() -> Double? {
    lock.lock(); defer { lock.unlock() }
    return read().configuredHourlyWage
  }

  func start(activityID: String, displayName: String, mode: String) {
    lock.lock(); defer { lock.unlock() }
    var value = read()
    let normalizedMode = MoshidopaMode(rawValue: mode.uppercased()) ?? .spend

    if let index = value.sessions.firstIndex(where: { $0.activityID == activityID && ($0.state == "running" || $0.state == "needsWage") }) {
      value.sessions[index].diagnostics.append("duplicate_start_ignored")
      value.events.append(NativeEvent(id: UUID().uuidString, kind: "diagnostic", createdAt: Date(), session: value.sessions[index], diagnostic: "duplicate_start_ignored"))
      write(value)
      return
    }

    let session = NativeSession(
      id: UUID().uuidString,
      activityID: activityID,
      displayName: displayName.isEmpty ? activityID : displayName,
      mode: normalizedMode,
      startedAt: Date(),
      endedAt: nil,
      elapsedMilliseconds: nil,
      hourlyWage: value.configuredHourlyWage,
      state: value.configuredHourlyWage == nil ? "needsWage" : "running",
      diagnostics: value.configuredHourlyWage == nil ? ["hourly_wage_not_configured"] : []
    )

    value.sessions.append(session)
    value.events.append(NativeEvent(id: UUID().uuidString, kind: "start", createdAt: Date(), session: session, diagnostic: nil))
    write(value)
  }

  func end(activityID: String) {
    lock.lock(); defer { lock.unlock() }
    var value = read()
    guard let index = value.sessions.lastIndex(where: { $0.activityID == activityID && ($0.state == "running" || $0.state == "needsWage") }) else {
      value.events.append(NativeEvent(id: UUID().uuidString, kind: "diagnostic", createdAt: Date(), session: nil, diagnostic: "end_without_active_session"))
      write(value)
      return
    }

    let now = Date()
    let rawMilliseconds = Int64((now.timeIntervalSince(value.sessions[index].startedAt) * 1000).rounded(.towardZero))
    let elapsed = max(0, rawMilliseconds)
    value.sessions[index].endedAt = now
    value.sessions[index].elapsedMilliseconds = elapsed
    // A session with no configured wage is still finished without an amount;
    // keeping it as an active session would make the dashboard look stuck.
    value.sessions[index].state = "finished"
    if rawMilliseconds < 0 { value.sessions[index].diagnostics.append("clock_rollback_clamped") }
    let finishedSession = value.sessions[index]
    value.events.append(NativeEvent(id: UUID().uuidString, kind: "end", createdAt: now, session: finishedSession, diagnostic: rawMilliseconds < 0 ? "clock_rollback_clamped" : nil))
    write(value)
  }

  func pendingEvents() -> [[String: Any]] {
    lock.lock(); defer { lock.unlock() }
    return read().events.map { event in
      var result: [String: Any] = [
        "eventId": event.id,
        "kind": event.kind,
        "createdAt": event.createdAt.timeIntervalSince1970 * 1000
      ]
      if let diagnostic = event.diagnostic { result["diagnostic"] = diagnostic }
      if let session = event.session {
        var sessionResult: [String: Any] = [
          "id": session.id,
          "activityId": session.activityID,
          "displayName": session.displayName,
          "mode": session.mode.rawValue,
          "startedAt": session.startedAt.timeIntervalSince1970 * 1000,
          "state": session.state,
          "diagnostics": session.diagnostics
        ]
        if let endedAt = session.endedAt { sessionResult["endedAt"] = endedAt.timeIntervalSince1970 * 1000 }
        if let elapsedMs = session.elapsedMilliseconds { sessionResult["elapsedMs"] = elapsedMs }
        if let hourlyWage = session.hourlyWage { sessionResult["hourlyWage"] = hourlyWage }
        result["session"] = sessionResult
      }
      return result
    }
  }

  func acknowledge(_ eventIDs: [String]) {
    lock.lock(); defer { lock.unlock() }
    var value = read()
    let ids = Set(eventIDs)
    value.events.removeAll { ids.contains($0.id) }
    value.sessions.removeAll { session in
      session.state == "finished" && !value.events.contains(where: { $0.session?.id == session.id })
    }
    write(value)
  }

  func requestOpenLastSession() {
    lock.lock(); defer { lock.unlock() }
    var value = read()
    value.openLastSessionRequested = true
    write(value)
  }

  func consumeOpenLastSessionRequest() -> Bool {
    lock.lock(); defer { lock.unlock() }
    var value = read()
    let requested = value.openLastSessionRequested
    value.openLastSessionRequested = false
    write(value)
    return requested
  }

  func snapshot() -> [String: Any] {
    lock.lock(); defer { lock.unlock() }
    let value = read()
    return [
      "pendingEventCount": value.events.count,
      "activeSessions": value.sessions.filter { $0.state == "running" || $0.state == "needsWage" }.map { $0.id },
      "fileURL": fileURL.path
    ]
  }
}

private enum NativeStoreError: Error {
  case invalidWage
}

public class MoshidopaIntentsModule: Module {
  public func definition() -> ModuleDefinition {
    Name("MoshidopaIntents")

    Function("setHourlyWage") { (wage: Double) in
      try MoshidopaNativeStore.shared.setHourlyWage(wage)
    }

    Function("getConfiguredHourlyWage") { () -> Double? in
      MoshidopaNativeStore.shared.configuredHourlyWage()
    }

    AsyncFunction("getPendingEvents") {
      MoshidopaNativeStore.shared.pendingEvents()
    }

    AsyncFunction("acknowledgeEvents") { (eventIDs: [String]) in
      MoshidopaNativeStore.shared.acknowledge(eventIDs)
    }

    Function("consumeOpenLastSessionRequest") {
      MoshidopaNativeStore.shared.consumeOpenLastSessionRequest()
    }

    Function("getDiagnosticSnapshot") {
      MoshidopaNativeStore.shared.snapshot()
    }
  }
}

@available(iOS 16.0, *)
public struct MoshidopaStartMeasurementIntent: AppIntent {
  public static let title: LocalizedStringResource = "もしドパ：計測開始"
  public static let description = IntentDescription("指定した活動の開始イベントを記録します。アプリ画面は開きません。")
  public static var openAppWhenRun: Bool { false }

  @Parameter(title: "活動識別子", default: "youtube") public var activityID: String
  @Parameter(title: "表示名", default: "YouTube") public var displayName: String
  @Parameter(title: "区分（SPEND / INVEST）", default: "SPEND") public var mode: String

  public init() {}

  public func perform() async throws -> some IntentResult {
    MoshidopaNativeStore.shared.start(activityID: activityID, displayName: displayName, mode: mode)
    return .result()
  }
}

@available(iOS 16.0, *)
public struct MoshidopaEndMeasurementIntent: AppIntent {
  public static let title: LocalizedStringResource = "もしドパ：計測終了"
  public static let description = IntentDescription("指定した活動の終了イベントを記録します。")
  public static var openAppWhenRun: Bool { false }

  @Parameter(title: "活動識別子", default: "youtube") public var activityID: String

  public init() {}

  public func perform() async throws -> some IntentResult {
    MoshidopaNativeStore.shared.end(activityID: activityID)
    return .result()
  }
}

@available(iOS 16.0, *)
public struct MoshidopaOpenLastSessionIntent: AppIntent {
  public static let title: LocalizedStringResource = "もしドパ：最新の明細を開く"
  public static let description = IntentDescription("計測終了後にもしドパを前面に表示します。ショートカットで自動表示をONにする場合に追加してください。")
  public static var openAppWhenRun: Bool { true }

  public init() {}

  public func perform() async throws -> some IntentResult {
    MoshidopaNativeStore.shared.requestOpenLastSession()
    return .result()
  }
}

@available(iOS 16.0, *)
public struct MoshidopaShortcuts: AppShortcutsProvider {
  public static var appShortcuts: [AppShortcut] {
    AppShortcut(intent: MoshidopaStartMeasurementIntent(), phrases: ["もしドパで\(.applicationName)の計測を開始"], shortTitle: "計測開始", systemImageName: "play.circle")
    AppShortcut(intent: MoshidopaEndMeasurementIntent(), phrases: ["もしドパで\(.applicationName)の計測を終了"], shortTitle: "計測終了", systemImageName: "stop.circle")
    AppShortcut(intent: MoshidopaOpenLastSessionIntent(), phrases: ["\(.applicationName)で最新の明細を開く"], shortTitle: "明細を開く", systemImageName: "doc.text")
  }
}
