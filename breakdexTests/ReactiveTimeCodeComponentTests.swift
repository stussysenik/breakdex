//import XCTest
//import SwiftUI
//import AVFoundation
//@testable import BreakingFlashcards
//
//final class ReactiveTimeCodeComponentTests: XCTestCase {
//
//    var testTime: CMTime!
//    let testFrameRate: Double = 30.0
//
//    override func setUp() {
//        super.setUp()
//        testTime = CMTime(seconds: 12.345, preferredTimescale: 600)
//    }
//
//    override func tearDown() {
//        testTime = nil
//        super.tearDown()
//    }
//
//    // MARK: - Initialization Tests
//
//    func testInitialization_withDefaultParameters() {
//        let component = ReactiveTimeCodeComponent(
//            time: testTime,
//            position: .start,
//            isActive: false,
//            displayMode: .timeOnly,
//            frameRate: testFrameRate
//        )
//
//        XCTAssertEqual(component.time, testTime)
//        XCTAssertEqual(component.position, .start)
//        XCTAssertFalse(component.isActive)
//        XCTAssertEqual(component.displayMode, .timeOnly)
//        XCTAssertEqual(component.frameRate, testFrameRate)
//    }
//
//    func testInitialization_withAllParameters() {
//        let component = ReactiveTimeCodeComponent(
//            time: testTime,
//            position: .end,
//            isActive: true,
//            displayMode: .timeAndFrame,
//            frameRate: 60.0,
//            showWarning: true,
//            minimumDuration: CMTime(seconds: 3.0, preferredTimescale: 600)
//        )
//
//        XCTAssertEqual(component.time, testTime)
//        XCTAssertEqual(component.position, .end)
//        XCTAssertTrue(component.isActive)
//        XCTAssertEqual(component.displayMode, .timeAndFrame)
//        XCTAssertEqual(component.frameRate, 60.0)
//        XCTAssertTrue(component.showWarning)
//        XCTAssertNotNil(component.minimumDuration)
//    }
//
//    // MARK: - TimeCodePosition Tests
//
//    func testTimeCodePosition_cases() {
//        let positions: [ReactiveTimeCodeComponent.TimeCodePosition] = [.start, .end, .duration]
//
//        for position in positions {
//            let component = ReactiveTimeCodeComponent(
//                time: testTime,
//                position: position,
//                frameRate: testFrameRate
//            )
//
//            XCTAssertEqual(component.position, position)
//        }
//    }
//
//    // MARK: - DisplayMode Tests
//
//    func testDisplayMode_cases() {
//        let modes: [ReactiveTimeCodeComponent.DisplayMode] = [.timeOnly, .frameOnly, .timeAndFrame, .durationOnly]
//
//        for mode in modes {
//            let component = ReactiveTimeCodeComponent(
//                time: testTime,
//                position: .start,
//                displayMode: mode,
//                frameRate: testFrameRate
//            )
//
//            XCTAssertEqual(component.displayMode, mode)
//        }
//    }
//
//    // MARK: - Frame Calculation Tests
//
//    func testFrameNumber_calculation() {
//        let component = ReactiveTimeCodeComponent(
//            time: CMTime(seconds: 2.5, preferredTimescale: 600),
//            position: .start,
//            frameRate: 30.0
//        )
//
//        // Frame number should be 75 for 2.5 seconds at 30fps
//        XCTAssertEqual(component.frameNumber, 75)
//    }
//
//    func testFrameNumber_zeroTime() {
//        let component = ReactiveTimeCodeComponent(
//            time: CMTime.zero,
//            position: .start,
//            frameRate: 30.0
//        )
//
//        XCTAssertEqual(component.frameNumber, 0)
//    }
//
//    func testFrameRateString_formatting() {
//        let component = ReactiveTimeCodeComponent(
//            time: testTime,
//            position: .start,
//            frameRate: 30.0
//        )
//
//        XCTAssertEqual(component.frameRateString, "30fps")
//    }
//
//    // MARK: - Time Formatting Tests
//
//    func testTimeDisplayString_timeOnlyMode() {
//        let component = ReactiveTimeCodeComponent(
//            time: CMTime(seconds: 65.432, preferredTimescale: 600),
//            position: .start,
//            displayMode: .timeOnly,
//            frameRate: testFrameRate
//        )
//
//        XCTAssertEqual(component.timeDisplayString, "01:05.432")
//    }
//
//    func testTimeDisplayString_frameOnlyMode() {
//        let component = ReactiveTimeCodeComponent(
//            time: CMTime(seconds: 2.5, preferredTimescale: 600),
//            position: .start,
//            displayMode: .frameOnly,
//            frameRate: 30.0
//        )
//
//        XCTAssertEqual(component.timeDisplayString, "75")
//    }
//
//    func testTimeDisplayString_timeAndFrameMode() {
//        let component = ReactiveTimeCodeComponent(
//            time: CMTime(seconds: 65.432, preferredTimescale: 600),
//            position: .start,
//            displayMode: .timeAndFrame,
//            frameRate: testFrameRate
//        )
//
//        XCTAssertEqual(component.timeDisplayString, "01:05.432")
//    }
//
//    func testTimeDisplayString_durationOnlyMode() {
//        let component = ReactiveTimeCodeComponent(
//            time: CMTime(seconds: 65.432, preferredTimescale: 600),
//            position: .duration,
//            displayMode: .durationOnly,
//            frameRate: testFrameRate
//        )
//
//        XCTAssertEqual(component.timeDisplayString, "01:05.432")
//    }
//
//    // MARK: - Warning State Tests
//
//    func testShouldShowWarning_withWarningAndMinimumDuration() {
//        let component = ReactiveTimeCodeComponent(
//            time: testTime,
//            position: .duration,
//            showWarning: true,
//            minimumDuration: CMTime(seconds: 3.0, preferredTimescale: 600),
//            frameRate: testFrameRate
//        )
//
//        XCTAssertTrue(component.shouldShowWarning)
//    }
//
//    func testShouldShowWarning_withoutWarning() {
//        let component = ReactiveTimeCodeComponent(
//            time: testTime,
//            position: .duration,
//            showWarning: false,
//            minimumDuration: CMTime(seconds: 3.0, preferredTimescale: 600),
//            frameRate: testFrameRate
//        )
//
//        XCTAssertFalse(component.shouldShowWarning)
//    }
//
//    func testShouldShowWarning_withoutMinimumDuration() {
//        let component = ReactiveTimeCodeComponent(
//            time: testTime,
//            position: .duration,
//            showWarning: true,
//            frameRate: testFrameRate
//        )
//
//        XCTAssertFalse(component.shouldShowWarning)
//    }
//
//    func testShouldShowFrameInfo_forTimeAndFrameMode() {
//        let component = ReactiveTimeCodeComponent(
//            time: testTime,
//            position: .start,
//            displayMode: .timeAndFrame,
//            frameRate: testFrameRate
//        )
//
//        XCTAssertTrue(component.shouldShowFrameInfo)
//    }
//
//    func testShouldShowFrameInfo_forFrameOnlyMode() {
//        let component = ReactiveTimeCodeComponent(
//            time: testTime,
//            position: .start,
//            displayMode: .frameOnly,
//            frameRate: testFrameRate
//        )
//
//        XCTAssertTrue(component.shouldShowFrameInfo)
//    }
//
//    func testShouldShowFrameInfo_forTimeOnlyMode() {
//        let component = ReactiveTimeCodeComponent(
//            time: testTime,
//            position: .start,
//            displayMode: .timeOnly,
//            frameRate: testFrameRate
//        )
//
//        XCTAssertFalse(component.shouldShowFrameInfo)
//    }
//
//    // MARK: - Font and Color Tests
//
//    func testFont_activeState() {
//        let activeComponent = ReactiveTimeCodeComponent(
//            time: testTime,
//            position: .start,
//            isActive: true,
//            frameRate: testFrameRate
//        )
//
//        let inactiveComponent = ReactiveTimeCodeComponent(
//            time: testTime,
//            position: .start,
//            isActive: false,
//            frameRate: testFrameRate
//        )
//
//        // Active component should have larger font size
//        // Note: We can't easily compare Font objects directly in tests
//        XCTAssertNotNil(activeComponent.font)
//        XCTAssertNotNil(inactiveComponent.font)
//    }
//
//    func testTextColor_warningState() {
//        let warningComponent = ReactiveTimeCodeComponent(
//            time: testTime,
//            position: .duration,
//            showWarning: true,
//            frameRate: testFrameRate
//        )
//
//        let normalComponent = ReactiveTimeCodeComponent(
//            time: testTime,
//            position: .duration,
//            showWarning: false,
//            frameRate: testFrameRate
//        )
//
//        // Warning state should affect text color
//        // Note: We can't easily compare Color objects directly in tests
//        XCTAssertNotNil(warningComponent.textColor)
//        XCTAssertNotNil(normalComponent.textColor)
//    }
//
//    // MARK: - Convenience Initializer Tests
//
//    func testStartTime_convenienceInitializer() {
//        let component = ReactiveTimeCodeComponent.startTime(
//            testTime,
//            isActive: true,
//            frameRate: 60.0
//        )
//
//        XCTAssertEqual(component.time, testTime)
//        XCTAssertEqual(component.position, .start)
//        XCTAssertTrue(component.isActive)
//        XCTAssertEqual(component.displayMode, .timeOnly)
//        XCTAssertEqual(component.frameRate, 60.0)
//    }
//
//    func testEndTime_convenienceInitializer() {
//        let component = ReactiveTimeCodeComponent.endTime(
//            testTime,
//            isActive: false,
//            frameRate: 25.0
//        )
//
//        XCTAssertEqual(component.time, testTime)
//        XCTAssertEqual(component.position, .end)
//        XCTAssertFalse(component.isActive)
//        XCTAssertEqual(component.displayMode, .timeOnly)
//        XCTAssertEqual(component.frameRate, 25.0)
//    }
//
//    func testDuration_convenienceInitializer() {
//        let minimumDuration = CMTime(seconds: 3.0, preferredTimescale: 600)
//        let component = ReactiveTimeCodeComponent.duration(
//            testTime,
//            minimumDuration: minimumDuration,
//            showWarning: true,
//            frameRate: 30.0
//        )
//
//        XCTAssertEqual(component.time, testTime)
//        XCTAssertEqual(component.position, .duration)
//        XCTAssertFalse(component.isActive)
//        XCTAssertEqual(component.displayMode, .durationOnly)
//        XCTAssertEqual(component.frameRate, 30.0)
//        XCTAssertTrue(component.showWarning)
//        XCTAssertEqual(component.minimumDuration, minimumDuration)
//    }
//
//    func testTimeWithFrame_convenienceInitializer() {
//        let component = ReactiveTimeCodeComponent.timeWithFrame(
//            testTime,
//            position: .end,
//            isActive: true,
//            frameRate: 120.0
//        )
//
//        XCTAssertEqual(component.time, testTime)
//        XCTAssertEqual(component.position, .end)
//        XCTAssertTrue(component.isActive)
//        XCTAssertEqual(component.displayMode, .timeAndFrame)
//        XCTAssertEqual(component.frameRate, 120.0)
//    }
//
//    // MARK: - Edge Case Tests
//
//    func testVeryShortTime_formatting() {
//        let component = ReactiveTimeCodeComponent(
//            time: CMTime(seconds: 0.001, preferredTimescale: 600),
//            position: .start,
//            displayMode: .timeOnly,
//            frameRate: testFrameRate
//        )
//
//        XCTAssertEqual(component.timeDisplayString, "00:00.001")
//    }
//
//    func testVeryLongTime_formatting() {
//        let component = ReactiveTimeCodeComponent(
//            time: CMTime(seconds: 6543.21, preferredTimescale: 600),
//            position: .start,
//            displayMode: .timeOnly,
//            frameRate: testFrameRate
//        )
//
//        XCTAssertEqual(component.timeDisplayString, "109:03.210")
//    }
//
//    func testHighFrameRate_frameCalculation() {
//        let component = ReactiveTimeCodeComponent(
//            time: CMTime(seconds: 1.0, preferredTimescale: 600),
//            position: .start,
//            displayMode: .frameOnly,
//            frameRate: 120.0
//        )
//
//        XCTAssertEqual(component.timeDisplayString, "120")
//    }
//
//    func testLowFrameRate_frameCalculation() {
//        let component = ReactiveTimeCodeComponent(
//            time: CMTime(seconds: 2.0, preferredTimescale: 600),
//            position: .start,
//            displayMode: .frameOnly,
//            frameRate: 15.0
//        )
//
//        XCTAssertEqual(component.timeDisplayString, "30")
//    }
//
//    // MARK: - Animation State Tests
//
//    func testInitialAnimationState_values() {
//        let component = ReactiveTimeCodeComponent(
//            time: testTime,
//            position: .start,
//            frameRate: testFrameRate
//        )
//
//        // These are private properties that would need to be tested via view behavior
//        // For now, we just verify the component can be created
//        XCTAssertEqual(component.time, testTime)
//    }
//
//    // MARK: - Utility Method Tests
//
//    func testFormatTimeWithMs_utility() {
//        // Test the private utility method indirectly through the component
//        let component = ReactiveTimeCodeComponent(
//            time: CMTime(seconds: 123.456, preferredTimescale: 600),
//            position: .start,
//            displayMode: .timeOnly,
//            frameRate: testFrameRate
//        )
//
//        XCTAssertEqual(component.timeDisplayString, "02:03.456")
//    }
//
//    func testFormatDurationWithMs_utility() {
//        // Test the private utility method indirectly through the component
//        let component = ReactiveTimeCodeComponent(
//            time: CMTime(seconds: 456.789, preferredTimescale: 600),
//            position: .duration,
//            displayMode: .durationOnly,
//            frameRate: testFrameRate
//        )
//
//        XCTAssertEqual(component.timeDisplayString, "456.789") // Duration mode shows absolute value
//    }
//}
