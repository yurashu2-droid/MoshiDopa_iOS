import XCTest
import UIKit
@testable import MoshiDopa

final class ShareImageTests: XCTestCase {
    @MainActor func testReceiptSharePNGEvidence() throws {
        for (fixture, mode, hideTime) in [
            (MDFixture.populated, MDMode.spend, false),
            (.populated, .invest, true),
            (.large, .spend, true),
            (.large, .invest, false)
        ] {
            let activities = MDFixtureData.make(fixture).activities.filter { $0.mode == mode }
            // Stress the large amount and long activity label already in the fixture.
            let activity = try XCTUnwrap(fixture == .large
                ? activities.max(by: { $0.amount < $1.amount }) : activities.first)
            try attach(MDReceiptView.shareUIImage(for: activity, hideTime: hideTime),
                       name: "share-receipt-\(fixture.rawValue)-\(mode.rawValue)-\(hideTime ? "hidden" : "visible")")
        }
    }

    @MainActor func testStatementSharePNGEvidence() throws {
        for (fixture, mode, period, hideTime) in [
            (MDFixture.populated, MDMode.spend, MDPeriod.day, false),
            (.populated, .invest, .month, true),
            (.large, .spend, .month, true)
        ] {
            let activities = MDFixtureData.make(fixture).activities(for: period, mode: mode)
            let lines = MDStatementView.groupedLines(activities: activities, mode: mode)
            XCTAssertFalse(lines.isEmpty)
            try attach(MDStatementView.shareUIImage(period: period, mode: mode,
                                                    lines: lines, hideTime: hideTime),
                       name: "share-statement-\(fixture.rawValue)-\(mode.rawValue)-\(period.rawValue)-\(hideTime ? "hidden" : "visible")")
        }
    }

    @MainActor func testWhatIfSharePNGEvidence() throws {
        for (fixture, mode, period, hideTime) in [
            (MDFixture.populated, MDMode.spend, MDWhatIfPeriod.day, false),
            (.populated, .invest, .month, true),
            (.large, .spend, .month, true)
        ] {
            let story = try XCTUnwrap(MDWhatIfStory.make(data: MDFixtureData.make(fixture),
                                                       period: period, mode: mode))
            try attach(MDWhatIfView.shareUIImage(story, hideTime: hideTime),
                       name: "share-whatif-\(fixture.rawValue)-\(mode.rawValue)-\(period.rawValue)-\(hideTime ? "hidden" : "visible")")
        }
    }

    @MainActor func testInterviewPhasePNGEvidence() throws {
        for mode in MDMode.allCases {
            let story = try XCTUnwrap(MDWhatIfStory.make(data: MDFixtureData.make(.populated),
                                                       period: .day, mode: mode))
            let phases: [TimeInterval] = mode == .spend
                ? [0, 1.3, 4.25, 8.85, 13.5, 15.83, 18.7] : [4.25, 15.83, 18.7]
            for elapsed in phases {
                try attach(MDWhatIfView.previewUIImage(story, elapsed: elapsed, hideTime: false),
                           name: "interview-phase-\(mode.rawValue)-\(elapsed)")
            }
        }
    }

    private func attach(_ image: UIImage?, name: String,
                        file: StaticString = #filePath, line: UInt = #line) throws {
        let image = try XCTUnwrap(image, name, file: file, line: line)
        let bitmap = try XCTUnwrap(image.cgImage, name, file: file, line: line)
        XCTAssertGreaterThan(bitmap.width, 0, file: file, line: line)
        XCTAssertGreaterThan(bitmap.height, 0, file: file, line: line)
        let png = try XCTUnwrap(image.pngData(), name, file: file, line: line)
        XCTAssertGreaterThan(png.count, 0, file: file, line: line)
        XCTAssertNotNil(UIImage(data: png), file: file, line: line)
        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
