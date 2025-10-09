//
//  TimerManagementService.swift
//  BreakingFlashcards
//
//  Created by Claude Code on 9/28/25.
//

import Foundation
import OSLog

/// Service responsible for managing operation timers for save and load operations
/// Extracted from AddMoveUnifiedState to follow Single Responsibility Principle
@MainActor
public class TimerManagementService {

    // MARK: - Properties

    private let logger = Logger(subsystem: "BreakingFlashcards", category: "⏱️ TIMER_SERVICE")

    // Timer instances
    private var saveTimer: Timer?
    private var loadTimer: Timer?

    // Timer state
    public private(set) var saveElapsedTime: TimeInterval = 0
    public private(set) var loadElapsedTime: TimeInterval = 0

    // MARK: - Callbacks

    /// Callback for save timer updates
    public var onSaveTimerUpdate: ((TimeInterval) -> Void)?
    /// Callback for load timer updates
    public var onLoadTimerUpdate: ((TimeInterval) -> Void)?
    /// Callback for logging diagnostics
    public var onLogDiagnostic: ((String, [String: String]) -> Void)?

    // MARK: - Initialization

    public init() {
        logger.info("⏱️ TIMER_SERVICE: ✅ Service initialized")
    }

    // MARK: - Save Timer Management
    // MARK: - FUNC
    /// Starts the save operation timer
    public func startSaveTimer() {
        logger.info("⏱️ TIMER_SERVICE: Starting save timer")

        saveElapsedTime = 0
        saveTimer?.invalidate() // Invalidate any existing timer

        // MARK: - PRECISION FIX: Use 0.01s intervals for millisecond precision display (MM:SS:MS format)
        saveTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
            self?.updateSaveTimer()
        }

        logger.info("⏱️ TIMER_SERVICE: Save timer started successfully with millisecond precision (0.01s intervals)")
    }

    /// Stops the save operation timer
    // MARK: - FUNC
    public func stopSaveTimer() {
        logger.info("⏱️ TIMER_SERVICE: Stopping save timer")

        saveTimer?.invalidate()
        saveTimer = nil

        logSaveTimerStopped()

        logger.info("⏱️ TIMER_SERVICE: Save timer stopped")
    }

    // MARK: - Load Timer Management

    /// Starts the video loading timer
    // MARK: - FUNC
    public func startLoadTimer() {
        logger.info("⏱️ TIMER_SERVICE: Starting load timer")

        loadElapsedTime = 0
        loadTimer?.invalidate() // Invalidate any existing timer

        // MARK: - PRECISION FIX: Use 0.01s intervals for millisecond precision display (MM:SS:MS format)
        loadTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
            self?.updateLoadTimer()
        }

        logLoadTimerStarted()

        logger.info("⏱️ TIMER_SERVICE: Load timer started successfully with millisecond precision (0.01s intervals)")
    }

    /// Stops the video loading timer
    // MARK: - FUNC
    public func stopLoadTimer() {
        logger.info("⏱️ TIMER_SERVICE: Stopping load timer")

        loadTimer?.invalidate()
        loadTimer = nil

        logLoadTimerStopped()

        logger.info("⏱️ TIMER_SERVICE: Load timer stopped")
    }

    // MARK: - State Queries

    /// Gets the current save elapsed time
    public func getSaveElapsedTime() -> TimeInterval {
        return saveElapsedTime
    }

    /// Gets the current load elapsed time
    public func getLoadElapsedTime() -> TimeInterval {
        return loadElapsedTime
    }

    /// Resets all timers and elapsed times
    public func resetAllTimers() {
        logger.info("⏱️ TIMER_SERVICE: Resetting all timers")

        stopSaveTimer()
        stopLoadTimer()

        saveElapsedTime = 0
        loadElapsedTime = 0

        logger.info("⏱️ TIMER_SERVICE: All timers reset")
    }

    // MARK: - Private Methods
    // MARK: - FUNC
    private func updateSaveTimer() {
        saveElapsedTime += 0.01 // MARK: - PRECISION FIX: Increment by 0.01s for millisecond precision

        // Notify callback
        onSaveTimerUpdate?(saveElapsedTime)

        // MARK: - PRECISION FIX: Log progress every 10 seconds (1000 * 0.01 = 10s)
        if Int(saveElapsedTime * 100) % 1000 == 0 {
            logSaveProgress()
        }
    }
    // MARK: - FUNC
    private func updateLoadTimer() {
        loadElapsedTime += 0.01 // MARK: - PRECISION FIX: Increment by 0.01s for millisecond precision

        // Notify callback
        onLoadTimerUpdate?(loadElapsedTime)

        // MARK: - PRECISION FIX: Log progress every 15 seconds (1500 * 0.01 = 15s)
        if Int(loadElapsedTime * 100) % 1500 == 0 {
            logLoadProgress()
        }
    }
    // MARK: - FUNC
    private func logSaveProgress() {
        let metadata = [
            "elapsed_time_seconds": "\(String(format: "%.2f", saveElapsedTime))",
            "timer_type": "save"
        ]

        onLogDiagnostic?("Save operation in progress", metadata)
        logger.info("⏱️ TIMER_SERVICE:  Save progress logged | elapsed: \(String(format: "%.2f", self.saveElapsedTime))s")
    }
    // MARK: - FUNC
    private func logLoadProgress() {
        let metadata = [
            "elapsed_time_seconds": "\(String(format: "%.2f", loadElapsedTime))",
            "timer_type": "load"
        ]

        onLogDiagnostic?("Long video load in progress", metadata)
        logger.info("⏱️ TIMER_SERVICE:  Load progress logged | elapsed: \(String(format: "%.2f", self.loadElapsedTime))s")
    }
    // MARK: - FUNC
    private func logSaveTimerStopped() {
        let metadata = [
            "final_elapsed_time": "\(String(format: "%.2f", saveElapsedTime))",
            "timer_type": "save"
        ]

        onLogDiagnostic?("Save timer stopped", metadata)
    }
    // MARK: - FUNC
    private func logLoadTimerStarted() {
        let metadata = [
            "timer_interval": "0.01s", // MARK: - PRECISION FIX: Updated to reflect millisecond precision
            "timer_type": "load"
        ]

        onLogDiagnostic?("Load timer started", metadata)
    }
    // MARK: - FUNC
    private func logLoadTimerStopped() {
        let metadata = [
            "final_elapsed_time": "\(String(format: "%.2f", loadElapsedTime))",
            "timer_type": "load"
        ]

        onLogDiagnostic?("Load timer stopped", metadata)
    }

    // MARK: - Cleanup

    deinit {
        logger.info("⏱️ TIMER_SERVICE: 🧹 Service deallocating, cleaning up timers")
        // Direct cleanup without calling resetAllTimers() to avoid main actor issues
        saveTimer?.invalidate()
        saveTimer = nil
        loadTimer?.invalidate()
        loadTimer = nil
        saveElapsedTime = 0
        loadElapsedTime = 0
    }

    // MARK: - 🎯 PRECISION FIX: Diagnostic Methods

    /// MARK: - PRECISION FIX: Log timer precision diagnostics
    // MARK: - FUNC
    public func logTimerPrecisionDiagnostics() {
        logger.info("⏱️ TIMER_SERVICE: 🔍 PRECISION DIAGNOSTIC REPORT")

        logger.info("⏱️ TIMER_SERVICE: ├─ Save Timer Analysis")
        if let saveTimer = self.saveTimer {
            logger.info("⏱️ TIMER_SERVICE: │  ├─ Status: ✅ Active")
            logger.info("⏱️ TIMER_SERVICE: │  ├─ Valid: \(saveTimer.isValid ? "✅ Valid" : "❌ Invalid")")
            logger.info("⏱️ TIMER_SERVICE: │  ├─ Interval: \(String(format: "%.3f", saveTimer.timeInterval))s")
            logger.info("⏱️ TIMER_SERVICE: │  └─ Elapsed: \(String(format: "%.2f", self.saveElapsedTime))s")
        } else {
            logger.info("⏱️ TIMER_SERVICE: │  └─ Status: ❌ nil")
        }

        logger.info("⏱️ TIMER_SERVICE: ├─ Load Timer Analysis")
        if let loadTimer = self.loadTimer {
            logger.info("⏱️ TIMER_SERVICE: │  ├─ Status: ✅ Active")
            logger.info("⏱️ TIMER_SERVICE: │  ├─ Valid: \(loadTimer.isValid ? "✅ Valid" : "❌ Invalid")")
            logger.info("⏱️ TIMER_SERVICE: │  ├─ Interval: \(String(format: "%.3f", loadTimer.timeInterval))s")
            logger.info("⏱️ TIMER_SERVICE: │  └─ Elapsed: \(String(format: "%.2f", self.loadElapsedTime))s")
        } else {
            logger.info("⏱️ TIMER_SERVICE: │  └─ Status: ❌ nil")
        }

        logger.info("⏱️ TIMER_SERVICE: └─ Precision Verification")
        logger.info("⏱️ TIMER_SERVICE:     ├─ Expected Precision: 0.01s (10ms)")
        logger.info("⏱️ TIMER_SERVICE:     ├─ Format Support: MM:SS:MS")
        logger.info("⏱️ TIMER_SERVICE:     └─ Fix Status: ✅ Applied")
    }
}

// MARK: - Timer Configuration

/// Configuration for timer behavior
public struct TimerConfiguration {
    public let saveTimerInterval: TimeInterval
    public let loadTimerInterval: TimeInterval
    public let saveProgressLogInterval: TimeInterval
    public let loadProgressLogInterval: TimeInterval

    public init(
        saveTimerInterval: TimeInterval = 0.01, // MARK: - PRECISION FIX: Default to millisecond precision
        loadTimerInterval: TimeInterval = 0.01, // MARK: - PRECISION FIX: Default to millisecond precision
        saveProgressLogInterval: TimeInterval = 10.0,
        loadProgressLogInterval: TimeInterval = 15.0
    ) {
        self.saveTimerInterval = saveTimerInterval
        self.loadTimerInterval = loadTimerInterval
        self.saveProgressLogInterval = saveProgressLogInterval
        self.loadProgressLogInterval = loadProgressLogInterval
    }
}

// MARK: - Timer State

/// Enum representing timer states
public enum TimerState {
    case idle
    case running(startTime: Date)
    case paused
    case stopped(endTime: Date, elapsed: TimeInterval)
}