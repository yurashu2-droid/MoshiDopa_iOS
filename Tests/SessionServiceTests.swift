import XCTest
import AVFoundation
import CoreVideo
import UIKit
@testable import MoshiDopa

private final class TestSessionRepository: SessionRepository {
    var values: [UUID: SessionRecord] = [:]
    var fail = false
    var writes = 0
    func records() throws -> [SessionRecord] {
        if fail { throw TestFailure.injected }
        return Array(values.values)
    }
    func save(_ record: SessionRecord) throws {
        if fail { throw TestFailure.injected }
        writes += 1
        values[record.id] = record
    }
}
private enum TestFailure: Error { case injected }

final class SessionServiceTests: XCTestCase {
    @MainActor func testBundledAndroidArtworkLoadsByRuntimeName() {
        for name in ["home_wordmark", "home_mascot_coin", "home_receipt_fiber", "paper_mascot_history", "paper_mascot_settings", "session_receipt_paper_texture", "whatif_part_old_normal", "whatif_part_young_body", "whatif_old_short_sheet_v2", "whatif_part_old_self_mic_v3", "whatif_interviewer_poses", "whatif_young_poses"] {
            XCTAssertNotNil(UIImage(named: name), "Missing runtime artwork: \(name)")
        }
    }

    func testAndroidAmountFixtures() {
        XCTAssertEqual(WageCalculator.amount(milliseconds: 100, hourlyRate: 1800), 0.05, accuracy: 0.0000001)
        XCTAssertEqual(WageCalculator.amount(milliseconds: 28 * 60 * 1000, hourlyRate: 1800), 840, accuracy: 0.0000001)
        XCTAssertEqual(WageCalculator.amount(milliseconds: 3_600_000, hourlyRate: 320000 / 160), 2000)
        XCTAssertFalse(WageCalculator.isValid(rate: .infinity))
        XCTAssertFalse(WageCalculator.isValid(rate: .nan))
        XCTAssertFalse(WageCalculator.isValid(rate: 0))
        XCTAssertFalse(WageCalculator.isValid(rate: 1_000_000_001))
    }

    @MainActor func testMonotonicAmountIgnoresWallClockAndTickCount() async throws {
        let repository = TestSessionRepository()
        var clock = 100.0
        var wall = Date(timeIntervalSince1970: 1000)
        let service = try SessionService(repository: repository, monotonic: { clock }, wall: { wall })
        let start = try service.start(hourlyRate: 1800)
        for _ in 0..<100 { _ = service.snapshot() }
        clock += 1680
        wall = Date(timeIntervalSince1970: 10) // deliberate backward wall jump
        let end = try service.stop(sessionID: start.id)
        XCTAssertEqual(end.elapsedMilliseconds, 1_680_000)
        XCTAssertEqual(end.amount, 840)
        XCTAssertEqual(end.endedAt, wall)
    }

    @MainActor func testAccumulatedCountingIntervalsExcludePausedTime() throws {
        let repository = TestSessionRepository()
        var clock = 100.0
        let service = try SessionService(repository: repository, monotonic: { clock })
        let started = try service.start(hourlyRate: 3_600, counting: false)

        XCTAssertFalse(service.isCounting)
        XCTAssertEqual(service.snapshot()?.elapsedMilliseconds, 0)

        try service.setCounting(true)
        clock += 3
        try service.setCounting(false)
        XCTAssertFalse(service.isCounting)
        XCTAssertEqual(service.snapshot()?.elapsedMilliseconds, 3_000)

        // Time while paused is excluded from the next interval.
        clock += 100
        XCTAssertEqual(service.snapshot()?.elapsedMilliseconds, 3_000)

        try service.setCounting(true)
        clock += 2
        try service.setCounting(false)
        let finished = try service.stop(sessionID: started.id)

        XCTAssertEqual(finished.elapsedMilliseconds, 5_000)
        XCTAssertEqual(finished.amount, 5, accuracy: 0.0000001)
    }

    @MainActor func testCheckpointDoesNotDoubleCountElapsedTime() throws {
        let repository = TestSessionRepository()
        var clock = 40.0
        let service = try SessionService(repository: repository, monotonic: { clock })
        let started = try service.start(hourlyRate: 3_600)

        clock += 1
        try service.checkpoint()
        let firstCheckpoint = try XCTUnwrap(repository.values[started.id])
        XCTAssertEqual(firstCheckpoint.elapsedMilliseconds, 1_000)
        XCTAssertEqual(firstCheckpoint.revision, 2)

        clock += 1
        try service.checkpoint()
        let secondCheckpoint = try XCTUnwrap(repository.values[started.id])
        XCTAssertEqual(secondCheckpoint.elapsedMilliseconds, 2_000)
        XCTAssertEqual(secondCheckpoint.revision, 3)
        XCTAssertEqual(service.snapshot()?.elapsedMilliseconds, 2_000)

        clock += 1
        XCTAssertEqual(try service.stop(sessionID: started.id).elapsedMilliseconds, 3_000)
    }

    @MainActor func testDuplicateCountingEventsAreIdempotent() throws {
        let repository = TestSessionRepository()
        var clock = 0.0
        let service = try SessionService(repository: repository, monotonic: { clock })
        _ = try service.start(hourlyRate: 3_600, counting: false)

        let writesAfterStart = repository.writes
        try service.setCounting(false)
        XCTAssertEqual(repository.writes, writesAfterStart)

        try service.setCounting(true)
        let writesAfterResume = repository.writes
        clock += 4
        try service.setCounting(true)
        XCTAssertEqual(repository.writes, writesAfterResume)
        XCTAssertEqual(service.snapshot()?.elapsedMilliseconds, 4_000)

        try service.setCounting(false)
        let writesAfterPause = repository.writes
        clock += 50
        try service.setCounting(false)
        XCTAssertEqual(repository.writes, writesAfterPause)
        XCTAssertEqual(service.snapshot()?.elapsedMilliseconds, 4_000)
    }

    @MainActor func testFailedCountingTransitionExcludesPausedTimeBeforeRetry() throws {
        let repository = TestSessionRepository()
        var clock = 10.0
        let service = try SessionService(repository: repository, monotonic: { clock })
        let started = try service.start(hourlyRate: 3_600)

        clock += 5
        repository.fail = true
        XCTAssertThrowsError(try service.setCounting(false))
        XCTAssertFalse(service.isCounting)

        // A failed durable boundary must still stop accrual immediately.
        clock += 100
        XCTAssertEqual(service.snapshot()?.elapsedMilliseconds, 5_000)

        repository.fail = false
        try service.checkpoint()
        let saved = try XCTUnwrap(repository.values[started.id])
        XCTAssertEqual(saved.elapsedMilliseconds, 5_000)
        XCTAssertEqual(saved.revision, 3)
        XCTAssertFalse(service.isCounting)
    }

    @MainActor func testDuplicateStopDoesNotWriteAgainOrStopNewSession() async throws {
        let repository = TestSessionRepository()
        var clock = 0.0
        let service = try SessionService(repository: repository, monotonic: { clock })
        let first = try service.start(hourlyRate: 1800)
        clock = 1
        let finished = try service.stop(sessionID: first.id)
        let second = try service.start(hourlyRate: 2000)
        let count = repository.writes
        XCTAssertEqual(try service.stop(sessionID: first.id), finished)
        XCTAssertEqual(repository.writes, count)
        XCTAssertEqual(service.active?.id, second.id)
        XCTAssertEqual(service.active?.hourlyRateAtStart, 2000)
        XCTAssertEqual(finished.hourlyRateAtStart, 1800)
    }

    @MainActor func testStopFailureRetainsFrozenResultForRetry() async throws {
        let repository = TestSessionRepository()
        var clock = 0.0
        let service = try SessionService(repository: repository, monotonic: { clock })
        let started = try service.start(hourlyRate: 3600)
        clock = 10
        repository.fail = true
        XCTAssertThrowsError(try service.stop(sessionID: started.id))
        XCTAssertEqual(service.active?.id, started.id)
        clock = 100
        repository.fail = false
        let saved = try service.stop(sessionID: started.id)
        XCTAssertEqual(saved.elapsedMilliseconds, 10_000)
        XCTAssertEqual(saved.amount, 10)
        XCTAssertNil(service.active)
    }

    @MainActor func testPendingStopCannotResumeOrAccrueAfterSaveFailure() throws {
        let repository = TestSessionRepository()
        var clock = 0.0
        let service = try SessionService(repository: repository, monotonic: { clock })
        let started = try service.start(hourlyRate: 3_600)
        clock = 3

        repository.fail = true
        XCTAssertThrowsError(try service.stop(sessionID: started.id))
        let frozen = try XCTUnwrap(service.snapshot())
        XCTAssertEqual(frozen.state, .finished)
        XCTAssertEqual(frozen.elapsedMilliseconds, 3_000)
        XCTAssertFalse(service.isCounting)

        let writesBeforeResumeAttempt = repository.writes
        clock = 300
        try service.setCounting(true)
        XCTAssertEqual(service.snapshot(), frozen)
        XCTAssertFalse(service.isCounting)
        XCTAssertEqual(repository.writes, writesBeforeResumeAttempt)

        repository.fail = false
        XCTAssertEqual(try service.stop(sessionID: started.id), frozen)
        XCTAssertNil(service.active)
    }

    @MainActor func testFailedStartNeverCreatesActiveState() async throws {
        let repository = TestSessionRepository()
        let service = try SessionService(repository: repository)
        repository.fail = true
        XCTAssertThrowsError(try service.start(hourlyRate: 1800))
        XCTAssertNil(service.active)
        XCTAssertTrue(repository.values.isEmpty)
    }

    @MainActor func testSQLiteReopenFinishedAndInterruptedCheckpoint() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("native-test.sqlite")
        var clock = 0.0
        var finished: SessionRecord!
        var interruptedID: UUID!
        do {
            let repository = try SQLiteSessionRepository(url: url)
            let service = try SessionService(repository: repository, monotonic: { clock })
            let start = try service.start(hourlyRate: 1800)
            clock = 28 * 60
            finished = try service.stop(sessionID: start.id)
            let another = try service.start(hourlyRate: 2400)
            interruptedID = another.id
            clock += 5
            try service.checkpoint()
            clock += 60 // deliberately not durable; reopen must not infer this time
        }
        let reopened = try SessionService(repository: SQLiteSessionRepository(url: url), monotonic: { clock })
        XCTAssertNil(reopened.active)
        let values = try reopened.history()
        XCTAssertEqual(values.count, 2)
        XCTAssertEqual(values.first(where: { $0.id == finished.id }), finished)
        let interrupted = try XCTUnwrap(values.first(where: { $0.id == interruptedID }))
        XCTAssertEqual(interrupted.state, .interrupted)
        XCTAssertEqual(interrupted.elapsedMilliseconds, 5000)
        XCTAssertNil(interrupted.endedAt)
        XCTAssertEqual(interrupted.hourlyRateAtStart, 2400)
    }

    @MainActor func testRecoveryFailureIsNotTreatedAsEmptyHistory() async throws {
        let repository = TestSessionRepository()
        let service = try SessionService(repository: repository)
        _ = try service.start(hourlyRate: 1800)
        repository.fail = true
        XCTAssertThrowsError(try SessionService(repository: repository))
    }

    func testSQLiteRejectsSecondRunningSessionWithoutPartialWrite() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = try SQLiteSessionRepository(url: directory.appendingPathComponent("constraint.sqlite"))
        let first = SessionRecord(id: UUID(), startedAt: Date(), hourlyRateAtStart: 1800,
            sourceZone: "Asia/Tokyo", elapsedMilliseconds: 0, endedAt: nil, state: .running, revision: 1, endReason: nil)
        let second = SessionRecord(id: UUID(), startedAt: Date(), hourlyRateAtStart: 2400,
            sourceZone: "Asia/Tokyo", elapsedMilliseconds: 0, endedAt: nil, state: .running, revision: 1, endReason: nil)
        try repository.save(first)
        XCTAssertThrowsError(try repository.save(second))
        XCTAssertEqual(try repository.records(), [first])
        var finished = first
        finished.state = .finished
        try repository.save(finished)
        try repository.save(second)
        XCTAssertEqual(try repository.records().count, 2)
    }

    @MainActor func testRealFrameDimensionsTimingAndChangingAmountPixels() async throws {
        var record = SessionRecord(id: UUID(), startedAt: Date(), hourlyRateAtStart: 1800,
            sourceZone: "Asia/Tokyo", elapsedMilliseconds: 0, endedAt: nil, state: .running, revision: 1, endReason: nil)
        let renderer = MoneyFrameRenderer()
        let first = try renderer.sample(record: record, presentationSeconds: 1)
        record.elapsedMilliseconds = 3_600_000
        let second = try renderer.sample(record: record, presentationSeconds: 2)
        XCTAssertTrue(CMSampleBufferDataIsReady(second))
        XCTAssertEqual(CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(second)), 2)
        XCTAssertEqual(CMTimeGetSeconds(CMSampleBufferGetDuration(second)), 0.1, accuracy: 0.0001)
        let buffer = try XCTUnwrap(CMSampleBufferGetImageBuffer(second))
        XCTAssertEqual(CVPixelBufferGetWidth(buffer), 640)
        XCTAssertEqual(CVPixelBufferGetHeight(buffer), 360)
        XCTAssertNotNil(CVPixelBufferGetIOSurface(buffer))
        func pixels(_ sample: CMSampleBuffer) throws -> Data {
            let image = try XCTUnwrap(CMSampleBufferGetImageBuffer(sample))
            CVPixelBufferLockBaseAddress(image, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(image, .readOnly) }
            return Data(bytes: try XCTUnwrap(CVPixelBufferGetBaseAddress(image)), count: CVPixelBufferGetBytesPerRow(image) * CVPixelBufferGetHeight(image))
        }
        XCTAssertNotEqual(try pixels(first), try pixels(second))
        let styles = try ["paper", "ink", "frost", "sticker"].map { style in
            try pixels(renderer.sample(record: record, presentationSeconds: 2.1, style: style))
        }
        for left in styles.indices {
            for right in styles.indices where right > left {
                XCTAssertNotEqual(styles[left], styles[right], "Each selected style must change the real PiP frame")
            }
        }
    }

}
