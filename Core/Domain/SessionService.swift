import Foundation

enum ProcessElapsedClock {
    private static let clock = ContinuousClock()
    private static let origin = clock.now
    /// Continuous across device sleep, with an origin local to this process only.
    static func seconds() -> TimeInterval {
        let duration = origin.duration(to: clock.now).components
        return Double(duration.seconds) + Double(duration.attoseconds) / 1_000_000_000_000_000_000
    }
}

enum SessionState: String, Codable { case running, finished, interrupted }

struct SessionRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let startedAt: Date
    let hourlyRateAtStart: Double
    let sourceZone: String
    var elapsedMilliseconds: Int64
    var endedAt: Date?
    var state: SessionState
    var revision: Int
    var endReason: String?
    var amount: Double { WageCalculator.amount(milliseconds: elapsedMilliseconds, hourlyRate: hourlyRateAtStart) }
}

enum WageCalculator {
    static func amount(milliseconds: Int64, hourlyRate: Double) -> Double {
        Double(max(0, milliseconds)) / 3_600_000 * hourlyRate
    }
    static func isValid(rate: Double) -> Bool { rate.isFinite && rate > 0 && rate <= 1_000_000_000 }
}

protocol SessionRepository {
    func records() throws -> [SessionRecord]
    func save(_ record: SessionRecord) throws
}

enum SessionError: LocalizedError {
    case invalidRate, alreadyRunning, missingSession
    var errorDescription: String? {
        switch self {
        case .invalidRate: return "時給は0より大きい10億円以下の数値を入力してください。"
        case .alreadyRunning: return "すでに計測中です。先に停止・保存してください。"
        case .missingSession: return "対象の計測がありません。"
        }
    }
}

/// One process owns this service. Reopen never guesses elapsed time across process lifetimes.
@MainActor
final class SessionService {
    private let repository: SessionRepository
    private let monotonic: () -> TimeInterval
    private let wall: () -> Date
    private var anchor: TimeInterval?
    private var accruedMilliseconds: Int64 = 0
    var isCounting: Bool { anchor != nil && pendingStop == nil && active != nil }
    private var pendingStop: SessionRecord?
    private(set) var active: SessionRecord?

    init(repository: SessionRepository,
         monotonic: @escaping () -> TimeInterval = ProcessElapsedClock.seconds,
         wall: @escaping () -> Date = Date.init) throws {
        self.repository = repository
        self.monotonic = monotonic
        self.wall = wall
        // Keep the last durable checkpoint, explicitly requiring review rather than resuming.
        for var record in try repository.records() where record.state == .running {
            record.state = .interrupted
            record.endReason = "process_reopened_last_checkpoint_only"
            record.revision += 1
            try repository.save(record)
        }
    }

    @discardableResult
    func start(hourlyRate: Double, counting: Bool = true) throws -> SessionRecord {
        guard WageCalculator.isValid(rate: hourlyRate) else { throw SessionError.invalidRate }
        guard active == nil else { throw SessionError.alreadyRunning }
        let startAnchor = monotonic()
        let record = SessionRecord(id: UUID(), startedAt: wall(), hourlyRateAtStart: hourlyRate,
            sourceZone: TimeZone.current.identifier, elapsedMilliseconds: 0, endedAt: nil,
            state: .running, revision: 1, endReason: nil)
        try repository.save(record)
        active = record
        accruedMilliseconds = 0
        anchor = counting ? startAnchor : nil
        pendingStop = nil
        return record
    }

    func snapshot() -> SessionRecord? {
        if let pendingStop { return pendingStop }
        guard var record = active else { return nil }
        let seconds = anchor.map { max(0, monotonic() - $0) } ?? 0
        record.elapsedMilliseconds = Int64(min(Double(Int64.max - 1024), Double(accruedMilliseconds) + seconds * 1000))
        return record
    }

    /// Repeated lifecycle/automation events are idempotent. Excluded intervals never accrue.
    func setCounting(_ counting: Bool) throws {
        guard pendingStop == nil, var record = snapshot(), counting != isCounting else { return }
        accruedMilliseconds = record.elapsedMilliseconds
        anchor = counting ? monotonic() : nil
        record.revision += 1
        active = record
        // Apply the boundary even if persistence fails; retry must not count excluded time.
        try repository.save(record)
    }

    func checkpoint() throws {
        guard pendingStop == nil, var record = snapshot() else { return }
        record.revision += 1
        try repository.save(record)
        active = record
    }

    /// The first stop freezes the result. Persistence failure retains it for an identical retry.
    @discardableResult
    func stop(sessionID: UUID) throws -> SessionRecord {
        if let active, active.id == sessionID {
            if pendingStop == nil {
                guard var finished = snapshot() else { throw SessionError.missingSession }
                finished.state = .finished
                finished.endedAt = wall()
                finished.endReason = "explicit_user_stop"
                finished.revision += 1
                pendingStop = finished
            }
            let finished = pendingStop!
            try repository.save(finished)
            self.active = nil
            anchor = nil
            accruedMilliseconds = 0
            pendingStop = nil
            return finished
        }
        if let saved = try repository.records().first(where: { $0.id == sessionID && $0.state != .running }) {
            return saved
        }
        throw SessionError.missingSession
    }

    func history() throws -> [SessionRecord] { try repository.records() }
}
