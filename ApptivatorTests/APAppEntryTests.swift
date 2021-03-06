//
//  APAppEntryTests.swift
//  ApptivatorTests
//

import XCTest
import SwiftyJSON

@testable import Apptivator

class APAppEntryTests: XCTestCase {
    func testMustBeValidFilePath() {
        let entry = APAppEntry(url: URL(fileURLWithPath: "/file/does/not/exist.app"), config: nil)
        XCTAssert(entry == nil)
    }

    // Since APAppEntry instances have some closures associated with them, it's a good idea to
    // ensure that they're cleaned up once they go out of scope to prevent memory leaks.
    // MASShortcutMonitor also retains some strong references to their `shortcutValue`s.
    func testEntryIsDeinitialised() {
        // Add a hook into the instance's `deinit` block.
        class MockEntry: APAppEntry {
            var deinitCalled: (() -> Void)?
            deinit { deinitCalled!() }
        }

        resetState(withSampleEntries: false)

        let expectation = self.expectation(description: "deinit")
        expectation.expectedFulfillmentCount = 2

        // Place tests within blocks so they go out of scope afterwards.

        do {
            // Simple init
            let entryOne = MockEntry(url: URL(fileURLWithPath: "/Applications/Xcode.app"), config: nil)!
            entryOne.deinitCalled = { expectation.fulfill() }
            XCTAssert(entryOne.isActive == true)

            // Init with shortcut
            let data = "{\"url\":\"file:///Applications/Xcode.app\",\"sequence\":[{\"keyCode\":120,\"modifierFlags\":0}]}"
                .data(using: .utf8, allowLossyConversion: false)!
            let entryTwo = try MockEntry(json: try JSON(data: data))!
            entryTwo.deinitCalled = { expectation.fulfill() }

            APState.shared.addEntry(entryOne)
            APState.shared.addEntry(entryTwo)
            while APState.shared.getEntries().count > 0 {
                APState.shared.removeEntry(at: 0)
            }
            print(APState.shared.getEntries())
        } catch { XCTFail(error.localizedDescription) }

        self.waitForExpectations(timeout: 0.5, handler: nil)
    }

    func testSerialisesAndDeserialises() {
        let entriesBefore = getSampleEntries()
        let json = APAppEntry.serialiseList(entries: entriesBefore[0..<entriesBefore.count])
        let entriesAfter = APAppEntry.deserialiseList(fromJSON: json)
        for i in (0..<entriesBefore.count) {
            let a = entriesBefore[i]
            let b = entriesAfter[i]
            XCTAssert(a.url == b.url)
            XCTAssert(a.name == b.name)
            XCTAssert(a.config == b.config)
            XCTAssert(a.shortcutString == b.shortcutString)
        }
    }

    func testShortcutStrings() {
        let shortcutStrings = ["nil", "⇧⌘S", "F2"]
        for (i, entry) in getSampleEntries().enumerated() {
            let str = entry.shortcutString ?? "nil"
            XCTAssert(str == shortcutStrings[i], "\(str) != \(shortcutStrings[i])")
        }
    }

    func getSampleEntries() -> [APAppEntry] {
        do {
            return try [
                "{\"url\":\"file:///Applications/Xcode.app\",\"config\":{\"showOnScreenWithMouse\":true}}",
                "{\"url\":\"file:///Applications/Chess.app\",\"sequence\":[{\"keyCode\":1,\"modifierFlags\":1179648}]}",
                "{\"url\":\"file:///Applications/Calculator.app\",\"sequence\":[{\"keyCode\":120,\"modifierFlags\":0}]}",
            ]
                .map({ try JSON(data: $0.data(using: .utf8, allowLossyConversion: false)!) })
                .map({ try APAppEntry(json: $0)! })
        } catch {
            XCTFail(error.localizedDescription)
        }

        return []
    }
}
