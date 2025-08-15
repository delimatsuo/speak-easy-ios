//
//  TranslationIntegrationTests.swift
//  UniversalTranslator Integration Tests
//
//  Comprehensive integration tests for the translation workflow
//

import XCTest
import Combine
@testable import UniversalTranslator

@MainActor
final class TranslationIntegrationTests: XCTestCase {
    var translationService: TranslationService!
    var creditsManager: CreditsManager!
    var anonymousCreditsManager: AnonymousCreditsManager!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        translationService = TranslationService.shared
        creditsManager = CreditsManager.shared
        anonymousCreditsManager = AnonymousCreditsManager.shared
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() async throws {
        cancellables.removeAll()
        try await super.tearDown()
    }
    
    // MARK: - Translation Service Tests
    
    func testTranslationAPIHealth() async throws {
        let isHealthy = await translationService.checkAPIHealth()
        XCTAssertTrue(isHealthy, "Translation API should be healthy")
    }
    
    func testTextTranslation() async throws {
        let testText = "Hello, how are you?"
        let sourceLanguage = "en"
        let targetLanguage = "es"
        
        do {
            let result = try await translationService.translateText(
                text: testText,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            )
            
            XCTAssertFalse(result.isEmpty, "Translation result should not be empty")
            XCTAssertNotEqual(result, testText, "Translation should differ from source")
            
            // Basic Spanish validation
            XCTAssertTrue(result.contains("Hola") || result.lowercased().contains("hola"), 
                         "Spanish translation should contain greeting")
        } catch {
            XCTFail("Translation failed with error: \(error)")
        }
    }
    
    func testVoiceTranslationWorkflow() async throws {
        let testText = "Good morning"
        let sourceLanguage = "en"
        let targetLanguage = "fr"
        
        do {
            let result = try await translationService.translateWithAudio(
                text: testText,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                voiceGender: "neutral",
                speakingRate: 1.0
            )
            
            XCTAssertFalse(result.translatedText.isEmpty, "Translated text should not be empty")
            XCTAssertGreaterThan(result.audioData.count, 0, "Audio data should be present")
            
            // Basic French validation
            XCTAssertTrue(result.translatedText.lowercased().contains("bonjour") || 
                         result.translatedText.lowercased().contains("bon"), 
                         "French translation should contain greeting")
        } catch {
            XCTFail("Voice translation failed with error: \(error)")
        }
    }
    
    func testMultipleLanguageSupport() async throws {
        let testText = "Thank you"
        let testCases = [
            ("en", "es", "gracias"),
            ("en", "fr", "merci"),
            ("en", "de", "danke"),
            ("en", "it", "grazie")
        ]
        
        for (source, target, expectedWord) in testCases {
            do {
                let result = try await translationService.translateText(
                    text: testText,
                    sourceLanguage: source,
                    targetLanguage: target
                )
                
                XCTAssertTrue(result.lowercased().contains(expectedWord.lowercased()),
                            "Translation from \(source) to \(target) should contain '\(expectedWord)'")
            } catch {
                XCTFail("Translation from \(source) to \(target) failed: \(error)")
            }
        }
    }
    
    // MARK: - Credits System Tests
    
    func testAnonymousCreditSystem() async throws {
        // Reset to known state
        anonymousCreditsManager.clearAfterMigration()
        
        // Test initial state
        XCTAssertEqual(anonymousCreditsManager.remainingSeconds, 0, "Should start with 0 credits")
        
        // Test Monday reset
        anonymousCreditsManager.checkMondayReset()
        XCTAssertEqual(anonymousCreditsManager.remainingSeconds, 60, "Should reset to 60 seconds")
        
        // Test credit deduction
        anonymousCreditsManager.deduct(seconds: 30)
        XCTAssertEqual(anonymousCreditsManager.remainingSeconds, 30, "Should deduct 30 seconds")
        
        // Test adding credits
        anonymousCreditsManager.add(seconds: 120)
        XCTAssertEqual(anonymousCreditsManager.remainingSeconds, 150, "Should add 120 seconds")
        
        // Test can start translation
        XCTAssertTrue(anonymousCreditsManager.canStartTranslation(), "Should allow translation with credits")
        
        // Test migration
        let creditsToMigrate = anonymousCreditsManager.migrateToAccount()
        XCTAssertEqual(creditsToMigrate, 150, "Should return correct migration amount")
    }
    
    func testCreditDeductionDuringTranslation() async throws {
        // Setup initial credits
        anonymousCreditsManager.add(seconds: 300) // 5 minutes
        let initialCredits = anonymousCreditsManager.remainingSeconds
        
        // Simulate recording for 10 seconds
        let recordingDuration = 10
        anonymousCreditsManager.deduct(seconds: recordingDuration)
        
        XCTAssertEqual(anonymousCreditsManager.remainingSeconds, 
                      initialCredits - recordingDuration,
                      "Credits should be deducted for recording time")
        
        // Verify can still translate
        XCTAssertTrue(anonymousCreditsManager.canStartTranslation(), 
                     "Should still allow translation with remaining credits")
    }
    
    // MARK: - End-to-End Workflow Tests
    
    func testCompleteTranslationWorkflow() async throws {
        // 1. Check API health
        let isHealthy = await translationService.checkAPIHealth()
        XCTAssertTrue(isHealthy, "API should be healthy before starting workflow")
        
        // 2. Setup credits
        anonymousCreditsManager.add(seconds: 120)
        XCTAssertTrue(anonymousCreditsManager.canStartTranslation(), "Should have credits to start")
        
        // 3. Perform translation
        let testText = "Welcome to our app"
        let result = try await translationService.translateWithAudio(
            text: testText,
            sourceLanguage: "en",
            targetLanguage: "es",
            voiceGender: "neutral",
            speakingRate: 1.0
        )
        
        // 4. Verify results
        XCTAssertFalse(result.translatedText.isEmpty, "Translation should be successful")
        XCTAssertGreaterThan(result.audioData.count, 0, "Audio should be generated")
        
        // 5. Verify credit deduction (simulated)
        anonymousCreditsManager.deduct(seconds: 15) // Simulate 15 second recording
        XCTAssertLessThan(anonymousCreditsManager.remainingSeconds, 120, "Credits should be deducted")
    }
    
    func testErrorHandlingWorkflow() async throws {
        // Test invalid language code
        do {
            _ = try await translationService.translateText(
                text: "Test",
                sourceLanguage: "invalid",
                targetLanguage: "es"
            )
            XCTFail("Should throw error for invalid language")
        } catch {
            // Expected error
            XCTAssertTrue(true, "Correctly handled invalid language error")
        }
        
        // Test empty text
        do {
            _ = try await translationService.translateText(
                text: "",
                sourceLanguage: "en",
                targetLanguage: "es"
            )
            XCTFail("Should throw error for empty text")
        } catch {
            // Expected error
            XCTAssertTrue(true, "Correctly handled empty text error")
        }
    }
    
    // MARK: - Performance Tests
    
    func testTranslationPerformance() async throws {
        let testText = "This is a performance test for translation speed"
        
        measure {
            let expectation = XCTestExpectation(description: "Translation performance")
            
            Task {
                do {
                    _ = try await translationService.translateText(
                        text: testText,
                        sourceLanguage: "en",
                        targetLanguage: "es"
                    )
                    expectation.fulfill()
                } catch {
                    XCTFail("Performance test failed: \(error)")
                    expectation.fulfill()
                }
            }
            
            wait(for: [expectation], timeout: 20.0)
        }
    }
}
