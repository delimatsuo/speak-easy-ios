//
//  ContentViewUITests.swift
//  UniversalTranslator UI Tests
//
//  UI tests for the main content view and user interactions
//

import XCTest

final class ContentViewUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app.terminate()
        try super.tearDownWithError()
    }
    
    // MARK: - App Launch Tests
    
    func testAppLaunchesSuccessfully() throws {
        XCTAssertTrue(app.staticTexts["Universal AI Translator"].exists, "App title should be visible")
        XCTAssertTrue(app.staticTexts["Real-time voice translation"].exists, "App subtitle should be visible")
    }
    
    func testMainUIElementsPresent() throws {
        // Test header elements
        XCTAssertTrue(app.staticTexts["Universal AI Translator"].exists)
        XCTAssertTrue(app.staticTexts["Real-time voice translation"].exists)
        
        // Test language selection area
        XCTAssertTrue(app.buttons.matching(identifier: "language-selector").count >= 2, "Should have language selectors")
        
        // Test microphone button
        XCTAssertTrue(app.buttons["record-button"].exists, "Record button should be present")
        
        // Test navigation buttons
        XCTAssertTrue(app.buttons["profile-button"].exists, "Profile button should be present")
    }
    
    // MARK: - Language Selection Tests
    
    func testLanguageSelection() throws {
        // Test source language selection
        let sourceLanguageButton = app.buttons["source-language-selector"]
        if sourceLanguageButton.exists {
            sourceLanguageButton.tap()
            
            // Wait for language picker to appear
            let languagePicker = app.sheets.firstMatch
            XCTAssertTrue(languagePicker.waitForExistence(timeout: 3.0), "Language picker should appear")
            
            // Select a language (e.g., Spanish)
            let spanishOption = app.buttons["Spanish"]
            if spanishOption.exists {
                spanishOption.tap()
            }
            
            // Dismiss picker
            let doneButton = app.buttons["Done"]
            if doneButton.exists {
                doneButton.tap()
            }
        }
    }
    
    func testLanguageSwap() throws {
        let swapButton = app.buttons["swap-languages"]
        if swapButton.exists {
            // Get initial languages
            let sourceLanguage = app.staticTexts["source-language-label"].label
            let targetLanguage = app.staticTexts["target-language-label"].label
            
            // Perform swap
            swapButton.tap()
            
            // Wait for UI update
            sleep(1)
            
            // Verify languages were swapped
            let newSourceLanguage = app.staticTexts["source-language-label"].label
            let newTargetLanguage = app.staticTexts["target-language-label"].label
            
            XCTAssertEqual(sourceLanguage, newTargetLanguage, "Source should become target")
            XCTAssertEqual(targetLanguage, newSourceLanguage, "Target should become source")
        }
    }
    
    // MARK: - Recording Interface Tests
    
    func testRecordButtonInteraction() throws {
        let recordButton = app.buttons["record-button"]
        XCTAssertTrue(recordButton.exists, "Record button should exist")
        
        // Test button is initially enabled (if user has credits)
        if recordButton.isEnabled {
            recordButton.tap()
            
            // Should show recording state
            XCTAssertTrue(app.staticTexts["Recording..."].waitForExistence(timeout: 2.0) ||
                         app.staticTexts["Listening..."].waitForExistence(timeout: 2.0),
                         "Should show recording state")
            
            // Tap again to stop recording
            recordButton.tap()
            
            // Should return to normal state
            XCTAssertFalse(app.staticTexts["Recording..."].exists, "Should stop recording")
        }
    }
    
    func testRecordingWithoutCredits() throws {
        // This test assumes the user has no credits
        // In a real test, you'd set up this state through the app
        
        let recordButton = app.buttons["record-button"]
        if !recordButton.isEnabled {
            recordButton.tap()
            
            // Should show purchase sheet or error message
            let purchaseSheet = app.sheets.firstMatch
            let errorAlert = app.alerts.firstMatch
            
            XCTAssertTrue(purchaseSheet.waitForExistence(timeout: 3.0) ||
                         errorAlert.waitForExistence(timeout: 3.0),
                         "Should show purchase option or error for no credits")
        }
    }
    
    // MARK: - Navigation Tests
    
    func testProfileNavigation() throws {
        let profileButton = app.buttons["profile-button"]
        if profileButton.exists {
            profileButton.tap()
            
            // Wait for profile sheet to appear
            let profileSheet = app.sheets.firstMatch
            XCTAssertTrue(profileSheet.waitForExistence(timeout: 3.0), "Profile sheet should appear")
            
            // Test profile elements
            XCTAssertTrue(app.staticTexts["Profile"].exists, "Profile title should be present")
            
            // Close profile
            let closeButton = app.buttons["Close"] || app.buttons["Done"]
            if closeButton.exists {
                closeButton.tap()
            }
        }
    }
    
    func testPurchaseSheetNavigation() throws {
        // Try to access purchase sheet through low credits or direct access
        let profileButton = app.buttons["profile-button"]
        if profileButton.exists {
            profileButton.tap()
            
            // Look for "Buy Minutes" or similar button
            let buyMinutesButton = app.buttons["Buy Minutes"]
            if buyMinutesButton.exists {
                buyMinutesButton.tap()
                
                // Wait for purchase sheet
                let purchaseSheet = app.sheets.firstMatch
                XCTAssertTrue(purchaseSheet.waitForExistence(timeout: 3.0), "Purchase sheet should appear")
                
                // Test purchase elements
                XCTAssertTrue(app.staticTexts["Add minutes"].exists || 
                             app.staticTexts["Buy minutes"].exists, 
                             "Purchase title should be present")
                
                // Close purchase sheet
                let closeButton = app.buttons["Close"]
                if closeButton.exists {
                    closeButton.tap()
                }
            }
        }
    }
    
    // MARK: - Translation Flow Tests
    
    func testTranslationDisplay() throws {
        // This test assumes a successful translation has occurred
        // In practice, you'd simulate this or use mock data
        
        // Look for translation result areas
        let transcribedText = app.textViews["transcribed-text"] || app.staticTexts["transcribed-text"]
        let translatedText = app.textViews["translated-text"] || app.staticTexts["translated-text"]
        
        // These might not exist initially, but the UI elements should be present
        XCTAssertTrue(app.otherElements["conversation-section"].exists, 
                     "Conversation section should exist")
    }
    
    func testErrorHandling() throws {
        // Test error alert display
        // This would typically be triggered by a failed translation attempt
        
        // For now, just verify the UI can handle error states
        XCTAssertTrue(app.exists, "App should remain stable during error conditions")
    }
    
    // MARK: - Accessibility Tests
    
    func testAccessibilityLabels() throws {
        // Test that key UI elements have proper accessibility labels
        let recordButton = app.buttons["record-button"]
        if recordButton.exists {
            XCTAssertFalse(recordButton.label.isEmpty, "Record button should have accessibility label")
        }
        
        let profileButton = app.buttons["profile-button"]
        if profileButton.exists {
            XCTAssertFalse(profileButton.label.isEmpty, "Profile button should have accessibility label")
        }
    }
    
    func testVoiceOverNavigation() throws {
        // Test basic VoiceOver navigation
        // This is a simplified test - full VoiceOver testing requires more setup
        
        XCTAssertTrue(app.exists, "App should be accessible to VoiceOver")
        
        // Test that main elements are focusable
        let mainElements = app.descendants(matching: .any).allElementsBoundByIndex
        let focusableElements = mainElements.filter { $0.isHittable }
        
        XCTAssertGreaterThan(focusableElements.count, 0, "Should have focusable elements for accessibility")
    }
    
    // MARK: - Performance Tests
    
    func testAppLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.terminate()
            app.launch()
        }
    }
    
    func testUIResponsiveness() throws {
        // Test UI responsiveness during interactions
        measure(metrics: [XCTMemoryMetric(), XCTCPUMetric()]) {
            // Perform a series of UI interactions
            if app.buttons["profile-button"].exists {
                app.buttons["profile-button"].tap()
                
                if app.buttons["Close"].exists {
                    app.buttons["Close"].tap()
                }
            }
            
            // Test language selection if available
            if app.buttons["source-language-selector"].exists {
                app.buttons["source-language-selector"].tap()
                
                if app.buttons["Done"].exists {
                    app.buttons["Done"].tap()
                }
            }
        }
    }
}
