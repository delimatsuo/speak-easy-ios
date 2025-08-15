//
//  AnonymousCreditsManagerTests.swift
//  UniversalTranslator Unit Tests
//
//  Unit tests for the anonymous credits management system
//

import XCTest
@testable import UniversalTranslator

@MainActor
final class AnonymousCreditsManagerTests: XCTestCase {
    var creditsManager: AnonymousCreditsManager!
    
    override func setUp() async throws {
        try await super.setUp()
        creditsManager = AnonymousCreditsManager.shared
        // Clear any existing state
        creditsManager.clearAfterMigration()
    }
    
    override func tearDown() async throws {
        // Clean up after tests
        creditsManager.clearAfterMigration()
        try await super.tearDown()
    }
    
    // MARK: - Basic Functionality Tests
    
    func testInitialState() {
        XCTAssertEqual(creditsManager.remainingSeconds, 0, "Should start with 0 credits")
        XCTAssertFalse(creditsManager.canStartTranslation(), "Should not allow translation without credits")
    }
    
    func testAddCredits() {
        creditsManager.add(seconds: 300) // 5 minutes
        XCTAssertEqual(creditsManager.remainingSeconds, 300, "Should add 300 seconds")
        XCTAssertTrue(creditsManager.canStartTranslation(), "Should allow translation with credits")
    }
    
    func testDeductCredits() {
        creditsManager.add(seconds: 300)
        creditsManager.deduct(seconds: 120) // 2 minutes
        XCTAssertEqual(creditsManager.remainingSeconds, 180, "Should have 180 seconds remaining")
        XCTAssertTrue(creditsManager.canStartTranslation(), "Should still allow translation")
    }
    
    func testDeductMoreThanAvailable() {
        creditsManager.add(seconds: 60)
        creditsManager.deduct(seconds: 120) // Try to deduct more than available
        XCTAssertEqual(creditsManager.remainingSeconds, 0, "Should not go below 0")
        XCTAssertFalse(creditsManager.canStartTranslation(), "Should not allow translation without credits")
    }
    
    func testDeductWithNoCredits() {
        XCTAssertEqual(creditsManager.remainingSeconds, 0, "Should start with 0")
        creditsManager.deduct(seconds: 30)
        XCTAssertEqual(creditsManager.remainingSeconds, 0, "Should remain at 0")
    }
    
    func testInvalidAddCredits() {
        let initialCredits = creditsManager.remainingSeconds
        creditsManager.add(seconds: 0)
        XCTAssertEqual(creditsManager.remainingSeconds, initialCredits, "Should not change for 0 seconds")
        
        creditsManager.add(seconds: -50)
        XCTAssertEqual(creditsManager.remainingSeconds, initialCredits, "Should not change for negative seconds")
    }
    
    func testInvalidDeductCredits() {
        creditsManager.add(seconds: 300)
        let initialCredits = creditsManager.remainingSeconds
        
        creditsManager.deduct(seconds: 0)
        XCTAssertEqual(creditsManager.remainingSeconds, initialCredits, "Should not change for 0 seconds")
        
        creditsManager.deduct(seconds: -50)
        XCTAssertEqual(creditsManager.remainingSeconds, initialCredits, "Should not change for negative seconds")
    }
    
    // MARK: - Monday Reset Tests
    
    func testMondayResetWithLowCredits() {
        // Set credits below weekly limit
        creditsManager.add(seconds: 30) // 30 seconds < 60 second limit
        
        // Trigger Monday reset
        creditsManager.checkMondayReset()
        
        XCTAssertEqual(creditsManager.remainingSeconds, 60, "Should reset to 60 seconds (1 minute)")
    }
    
    func testMondayResetWithHighCredits() {
        // Set credits above weekly limit
        creditsManager.add(seconds: 300) // 5 minutes > 60 second limit
        
        // Trigger Monday reset
        creditsManager.checkMondayReset()
        
        XCTAssertEqual(creditsManager.remainingSeconds, 300, "Should maintain existing credits when above limit")
    }
    
    func testMondayResetWithExactLimit() {
        // Set credits exactly at weekly limit
        creditsManager.add(seconds: 60) // Exactly 1 minute
        
        // Trigger Monday reset
        creditsManager.checkMondayReset()
        
        XCTAssertEqual(creditsManager.remainingSeconds, 60, "Should maintain credits when at exact limit")
    }
    
    // MARK: - Migration Tests
    
    func testMigrationToAccount() {
        creditsManager.add(seconds: 450) // 7.5 minutes
        
        let creditsToMigrate = creditsManager.migrateToAccount()
        XCTAssertEqual(creditsToMigrate, 450, "Should return correct amount for migration")
        
        // Original credits should remain until clearAfterMigration is called
        XCTAssertEqual(creditsManager.remainingSeconds, 450, "Original credits should remain")
    }
    
    func testClearAfterMigration() {
        creditsManager.add(seconds: 300)
        XCTAssertEqual(creditsManager.remainingSeconds, 300, "Should have credits before migration")
        
        creditsManager.clearAfterMigration()
        XCTAssertEqual(creditsManager.remainingSeconds, 0, "Should have no credits after migration clear")
        XCTAssertFalse(creditsManager.canStartTranslation(), "Should not allow translation after clear")
    }
    
    func testMigrationWithZeroCredits() {
        XCTAssertEqual(creditsManager.remainingSeconds, 0, "Should start with 0")
        
        let creditsToMigrate = creditsManager.migrateToAccount()
        XCTAssertEqual(creditsToMigrate, 0, "Should return 0 for migration")
    }
    
    // MARK: - Edge Cases
    
    func testMaximumCredits() {
        // Test with large number of credits
        let maxCredits = 7200 // 2 hours
        creditsManager.add(seconds: maxCredits)
        XCTAssertEqual(creditsManager.remainingSeconds, maxCredits, "Should handle large credit amounts")
        
        // Test deduction
        creditsManager.deduct(seconds: 1800) // 30 minutes
        XCTAssertEqual(creditsManager.remainingSeconds, 5400, "Should correctly deduct from large amounts")
    }
    
    func testRapidAddAndDeduct() {
        // Simulate rapid credits operations
        for i in 1...10 {
            creditsManager.add(seconds: i * 30)
            creditsManager.deduct(seconds: i * 10)
        }
        
        // Should have: (30+60+90+...+300) - (10+20+30+...+100) = 1650 - 550 = 1100
        let expectedCredits = 1100
        XCTAssertEqual(creditsManager.remainingSeconds, expectedCredits, "Should handle rapid operations correctly")
    }
    
    func testSimultaneousOperations() {
        // Test thread safety with concurrent operations
        let group = DispatchGroup()
        
        // Add credits concurrently
        for _ in 1...5 {
            group.enter()
            DispatchQueue.global().async {
                Task { @MainActor in
                    self.creditsManager.add(seconds: 60)
                    group.leave()
                }
            }
        }
        
        // Deduct credits concurrently
        for _ in 1...3 {
            group.enter()
            DispatchQueue.global().async {
                Task { @MainActor in
                    self.creditsManager.deduct(seconds: 30)
                    group.leave()
                }
            }
        }
        
        let expectation = XCTestExpectation(description: "Concurrent operations")
        group.notify(queue: .main) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Should have: 5*60 - 3*30 = 300 - 90 = 210
        let expectedCredits = 210
        XCTAssertEqual(creditsManager.remainingSeconds, expectedCredits, "Should handle concurrent operations safely")
    }
}
