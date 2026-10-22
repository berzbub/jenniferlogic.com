import XCTest
@testable import GHMSLogic

final class ClinicalLogicTests: XCTestCase {
    func testReorderFlag() {
        XCTAssertTrue(ClinicalLogic.needsReorder(stockLevel: 5, reorderPoint: 10))
        XCTAssertTrue(ClinicalLogic.needsReorder(stockLevel: 10, reorderPoint: 10))
        XCTAssertFalse(ClinicalLogic.needsReorder(stockLevel: 11, reorderPoint: 10))
    }

    func testExpiry() {
        let now = Date()
        XCTAssertTrue(ClinicalLogic.isExpired(now.addingTimeInterval(-1), now: now))
        XCTAssertFalse(ClinicalLogic.isExpired(now.addingTimeInterval(86400), now: now))
    }

    func testTelURL() {
        XCTAssertEqual(ClinicalLogic.telURL(for: "+1 (555) 123-4567"), "tel:+15551234567")
        XCTAssertNil(ClinicalLogic.telURL(for: "abc"))
        XCTAssertNil(ClinicalLogic.telURL(for: "+"))
    }

    func testReminderOneHourBefore() {
        let d = Date(timeIntervalSince1970: 100000)
        XCTAssertEqual(ClinicalLogic.reminderDate(for: d).timeIntervalSince1970, 96400)
    }

    func testAuditVariance() {
        XCTAssertEqual(ClinicalLogic.auditVariance(systemStock: 50, countedStock: 45), -5)
        XCTAssertEqual(ClinicalLogic.auditVariance(systemStock: 50, countedStock: 55), 5)
    }

    func testAuditPercentAndTolerance() {
        XCTAssertEqual(ClinicalLogic.auditVariancePercent(systemStock: 200, countedStock: 190)!, -5, accuracy: 0.001)
        XCTAssertNil(ClinicalLogic.auditVariancePercent(systemStock: 0, countedStock: 3))
        XCTAssertTrue(ClinicalLogic.auditWithinTolerance(systemStock: 100, countedStock: 100))
        XCTAssertFalse(ClinicalLogic.auditWithinTolerance(systemStock: 100, countedStock: 99))
        XCTAssertTrue(ClinicalLogic.auditWithinTolerance(systemStock: 100, countedStock: 97, tolerancePercent: 5))
        XCTAssertFalse(ClinicalLogic.auditWithinTolerance(systemStock: 0, countedStock: 3, tolerancePercent: 5))
    }
}
