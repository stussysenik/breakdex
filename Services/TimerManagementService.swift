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

    /// Starts the save operation timer
    public func startSaveTimer() {
        logger.info("⏱️ TIMER_SERVICE: Starting save timer")

        saveElapsedTime = 0
        saveTimer?.invalidate() // Invalidate any existing timer

        saveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateSaveTimer()
        }

        logger.info("⏱️ TIMER_SERVICE: Save timer started successfully")
    }

    /// Stops the save operation timer
    public func stopSaveTimer() {
        logger.info("⏱️ TIMER_SERVICE: Stopping save timer")

        saveTimer?.invalidate()
        saveTimer = nil

        logSaveTimerStopped()

        logger.info("⏱️ TIMER_SERVICE: Save timer stopped")
    }

    // MARK: - Load Timer Management

    /// Starts the video loading timer
    public func startLoadTimer() {
        logger.info("⏱️ TIMER_SERVICE: Starting load timer")

        loadElapsedTime = 0
        loadTimer?.invalidate() // Invalidate any existing timer

        loadTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateLoadTimer()
        }

        logLoadTimerStarted()

        logger.info("⏱️ TIMER_SERVICE: Load timer started successfully")
    }

    /// Stops the video loading timer
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

    private func updateSaveTimer() {
        saveElapsedTime += 1

        // Notify callback
        onSaveTimerUpdate?(saveElapsedTime)

        // Log progress every 10 seconds for debugging
        if Int(saveElapsedTime) % 10 == 0 {
            logSaveProgress()
        }
    }

    private func updateLoadTimer() {
        loadElapsedTime += 1

        // Notify callback
        onLoadTimerUpdate?(loadElapsedTime)

        // Log progress every 15 seconds for debugging long loads
        if Int(loadElapsedTime) % 15 == 0 {
            logLoadProgress()
        }
    }

    private func logSaveProgress() {
        let metadata = [
            "elapsed_time_seconds": "\(Int(saveElapsedTime))",
            "timer_type": "save"
        ]

        onLogDiagnostic?("Save operation in progress", metadata)
        logger.info("⏱️ TIMER_SERVICE: 📊 Save progress logged | elapsed: \(Int(self.saveElapsedTime))s")
    }

    private func logLoadProgress() {
        let metadata = [
            "elapsed_time_seconds": "\(Int(loadElapsedTime))",
            "timer_type": "load"
        ]

        onLogDiagnostic?("Long video load in progress", metadata)
        logger.info("⏱️ TIMER_SERVICE: 📊 Load progress logged | elapsed: \(Int(self.loadElapsedTime))s")
    }

    private func logSaveTimerStopped() {
        let metadata = [
            "final_elapsed_time": "\(Int(saveElapsedTime))",
            "timer_type": "save"
        ]

        onLogDiagnostic?("Save timer stopped", metadata)
    }

    private func logLoadTimerStarted() {
        let metadata = [
            "timer_interval": "1.0s",
            "timer_type": "load"
        ]

        onLogDiagnostic?("Load timer started", metadata)
    }

    private func logLoadTimerStopped() {
        let metadata = [
            "final_elapsed_time": "\(Int(loadElapsedTime))",
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
}

// MARK: - Timer Configuration

/// Configuration for timer behavior
public struct TimerConfiguration {
    public let saveTimerInterval: TimeInterval
    public let loadTimerInterval: TimeInterval
    public let saveProgressLogInterval: TimeInterval
    public let loadProgressLogInterval: TimeInterval

    public init(
        saveTimerInterval: TimeInterval = 1.0,
        loadTimerInterval: TimeInterval = 1.0,
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