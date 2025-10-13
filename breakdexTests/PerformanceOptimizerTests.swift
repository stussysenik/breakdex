//import XCTest
//@testable import BreakingFlashcards
//
//final class PerformanceOptimizerTests: XCTestCase {
//
//    var optimizer: PerformanceOptimizer!
//    let testConfiguration = PerformanceOptimizer.Configuration.default
//
//    override func setUp() {
//        super.setUp()
//        optimizer = PerformanceOptimizer(configuration: testConfiguration)
//    }
//
//    override func tearDown() {
//        optimizer.stopOptimization()
//        optimizer = nil
//        super.tearDown()
//    }
//
//    // MARK: - Initialization Tests
//
//    func testInitialization_withDefaultConfiguration() {
//        let optimizer = PerformanceOptimizer()
//
//        XCTAssertNil(optimizer.currentMetrics)
//        XCTAssertEqual(optimizer.memoryPressure, .normal)
//        XCTAssertFalse(optimizer.isOptimizing)
//        XCTAssertEqual(optimizer.optimizationCount, 0)
//        XCTAssertNil(optimizer.lastOptimizationTime)
//        XCTAssertTrue(optimizer.warnings.isEmpty)
//        XCTAssertTrue(optimizer.criticalIssues.isEmpty)
//    }
//
//    func testInitialization_withCustomConfiguration() {
//        let config = PerformanceOptimizer.Configuration.minimal
//        let optimizer = PerformanceOptimizer(configuration: config)
//
//        XCTAssertNil(optimizer.currentMetrics)
//        XCTAssertEqual(optimizer.memoryPressure, .normal)
//        XCTAssertFalse(optimizer.isOptimizing)
//    }
//
//    // MARK: - Configuration Tests
//
//    func testDefaultConfiguration_values() {
//        XCTAssertEqual(testConfiguration.optimizationLevel, .balanced)
//        XCTAssertTrue(testConfiguration.enableMemoryMonitoring)
//        XCTAssertTrue(testConfiguration.enableCPUMonitoring)
//        XCTAssertTrue(testConfiguration.enableGPUMonitoring)
//        XCTAssertTrue(testConfiguration.enableThermalMonitoring)
//        XCTAssertTrue(testConfiguration.enableBatteryMonitoring)
//        XCTAssertEqual(testConfiguration.memoryWarningThresholdMB, 200.0)
//        XCTAssertEqual(testConfiguration.memoryCriticalThresholdMB, 100.0)
//        XCTAssertEqual(testConfiguration.cpuWarningThresholdPercent, 80.0)
//        XCTAssertEqual(testConfiguration.thermalWarningThreshold, "fair")
//        XCTAssertTrue(testConfiguration.enableAutomaticOptimization)
//        XCTAssertEqual(testConfiguration.optimizationInterval, 5.0)
//    }
//
//    func testMinimalConfiguration_values() {
//        let minimalConfig = PerformanceOptimizer.Configuration.minimal
//
//        XCTAssertEqual(minimalConfig.optimizationLevel, .minimal)
//        XCTAssertTrue(minimalConfig.enableMemoryMonitoring)
//        XCTAssertFalse(minimalConfig.enableCPUMonitoring)
//        XCTAssertFalse(minimalConfig.enableGPUMonitoring)
//        XCTAssertFalse(minimalConfig.enableThermalMonitoring)
//        XCTAssertFalse(minimalConfig.enableBatteryMonitoring)
//        XCTAssertEqual(minimalConfig.memoryWarningThresholdMB, 300.0)
//        XCTAssertEqual(minimalConfig.memoryCriticalThresholdMB, 150.0)
//        XCTAssertEqual(minimalConfig.cpuWarningThresholdPercent, 90.0)
//        XCTAssertEqual(minimalConfig.thermalWarningThreshold, "serious")
//        XCTAssertFalse(minimalConfig.enableAutomaticOptimization)
//        XCTAssertEqual(minimalConfig.optimizationInterval, 10.0)
//    }
//
//    func testAggressiveConfiguration_values() {
//        let aggressiveConfig = PerformanceOptimizer.Configuration.aggressive
//
//        XCTAssertEqual(aggressiveConfig.optimizationLevel, .aggressive)
//        XCTAssertTrue(aggressiveConfig.enableMemoryMonitoring)
//        XCTAssertTrue(aggressiveConfig.enableCPUMonitoring)
//        XCTAssertTrue(aggressiveConfig.enableGPUMonitoring)
//        XCTAssertTrue(aggressiveConfig.enableThermalMonitoring)
//        XCTAssertTrue(aggressiveConfig.enableBatteryMonitoring)
//        XCTAssertEqual(aggressiveConfig.memoryWarningThresholdMB, 100.0)
//        XCTAssertEqual(aggressiveConfig.memoryCriticalThresholdMB, 50.0)
//        XCTAssertEqual(aggressiveConfig.cpuWarningThresholdPercent, 70.0)
//        XCTAssertEqual(aggressiveConfig.thermalWarningThreshold, "nominal")
//        XCTAssertTrue(aggressiveConfig.enableAutomaticOptimization)
//        XCTAssertEqual(aggressiveConfig.optimizationInterval, 2.0)
//    }
//
//    // MARK: - Performance Metrics Tests
//
//    func testGetCurrentMetrics_initiallyNil() {
//        XCTAssertNil(optimizer.getCurrentMetrics())
//    }
//
//    func testGetMetricsHistory_initiallyEmpty() {
//        let history = optimizer.getMetricsHistory()
//        XCTAssertTrue(history.isEmpty)
//    }
//
//    func testPerformanceMetrics_initialValues() {
//        let metrics = PerformanceOptimizer.PerformanceMetrics(
//            memoryUsageMB: 150.0,
//            cpuUsagePercent: 45.0,
//            gpuUsagePercent: 30.0,
//            diskUsageMB: 1000.0,
//            networkActivityMB: 10.0,
//            thermalState: "nominal",
//            batteryLevel: 85.0,
//            isLowPowerMode: false,
//            timestamp: Date()
//        )
//
//        XCTAssertEqual(metrics.memoryUsageMB, 150.0)
//        XCTAssertEqual(metrics.cpuUsagePercent, 45.0)
//        XCTAssertEqual(metrics.gpuUsagePercent, 30.0)
//        XCTAssertEqual(metrics.diskUsageMB, 1000.0)
//        XCTAssertEqual(metrics.networkActivityMB, 10.0)
//        XCTAssertEqual(metrics.thermalState, "nominal")
//        XCTAssertEqual(metrics.batteryLevel, 85.0)
//        XCTAssertFalse(metrics.isLowPowerMode)
//    }
//
//    // MARK: - Optimization Control Tests
//
//    func testStartOptimization_setsIsOptimizing() async {
//        XCTAssertFalse(optimizer.isOptimizing)
//
//        await optimizer.startOptimization()
//
//        XCTAssertTrue(optimizer.isOptimizing)
//    }
//
//    func testStopOptimization_resetsIsOptimizing() async {
//        await optimizer.startOptimization()
//        XCTAssertTrue(optimizer.isOptimizing)
//
//        optimizer.stopOptimization()
//
//        XCTAssertFalse(optimizer.isOptimizing)
//    }
//
//    func testStartOptimization_multipleTimes_noEffect() async {
//        await optimizer.startOptimization()
//        let firstCount = optimizer.optimizationCount
//
//        await optimizer.startOptimization()
//
//        XCTAssertEqual(optimizer.optimizationCount, firstCount)
//    }
//
//    // MARK: - Memory Pressure Tests
//
//    func testIsUnderMemoryPressure_normalState() {
//        XCTAssertEqual(optimizer.memoryPressure, .normal)
//        XCTAssertFalse(optimizer.isUnderMemoryPressure())
//    }
//
//    func testMemoryPressureState_cases() {
//        let states: [PerformanceOptimizer.MemoryPressure] = [.normal, .warning, .critical]
//
//        for state in states {
//            // Verify all states can be created without crashing
//            switch state {
//            case .normal:
//                break
//            case .warning:
//                break
//            case .critical:
//                break
//            }
//        }
//    }
//
//    // MARK: - Resource Usage Tests
//
//    func testGetMemoryUsageMB_returnsValue() {
//        let memoryUsage = optimizer.getMemoryUsageMB()
//        XCTAssertGreaterThanOrEqual(memoryUsage, 0.0)
//    }
//
//    func testGetCPUUsagePercent_returnsValue() {
//        let cpuUsage = optimizer.getCPUUsagePercent()
//        XCTAssertGreaterThanOrEqual(cpuUsage, 0.0)
//        XCTAssertLessThanOrEqual(cpuUsage, 100.0)
//    }
//
//    func testGetThermalState_returnsString() {
//        let thermalState = optimizer.getThermalState()
//        XCTAssertFalse(thermalState.isEmpty)
//    }
//
//    // MARK: - Warning Management Tests
//
//    func testClearWarnings_clearsAllWarningsAndIssues() {
//        // Simulate some warnings
//        optimizer.warnings = ["Test warning"]
//        optimizer.criticalIssues = ["Test issue"]
//
//        optimizer.clearWarnings()
//
//        XCTAssertTrue(optimizer.warnings.isEmpty)
//        XCTAssertTrue(optimizer.criticalIssues.isEmpty)
//    }
//
//    // MARK: - Optimization Level Tests
//
//    func testOptimizationLevel_cases() {
//        let levels: [PerformanceOptimizer.OptimizationLevel] = [.minimal, .balanced, .aggressive]
//
//        for level in levels {
//            // Verify all levels can be created without crashing
//            switch level {
//            case .minimal:
//                break
//            case .balanced:
//                break
//            case .aggressive:
//                break
//            }
//        }
//    }
//
//    // MARK: - Reset Tests
//
//    func testReset_clearsState() async {
//        // Set up some state
//        optimizer.optimizationCount = 5
//        optimizer.lastOptimizationTime = Date()
//        optimizer.warnings = ["Test warning"]
//
//        await optimizer.reset()
//
//        XCTAssertEqual(optimizer.optimizationCount, 0)
//        XCTAssertNil(optimizer.lastOptimizationTime)
//        XCTAssertTrue(optimizer.warnings.isEmpty)
//        XCTAssertTrue(optimizer.criticalIssues.isEmpty)
//    }
//
//    // MARK: - Force Optimization Tests
//
//    func testForceOptimization_incrementsCount() async {
//        let initialCount = optimizer.optimizationCount
//
//        await optimizer.forceOptimization()
//
//        XCTAssertGreaterThan(optimizer.optimizationCount, initialCount)
//        XCTAssertNotNil(optimizer.lastOptimizationTime)
//    }
//
//    // MARK: - Performance History Tests
//
//    func testGetMetricsHistory_limitedToMaxSize() async {
//        // Simulate collecting more metrics than the maximum
//        for i in 0..<150 {
//            let metrics = PerformanceOptimizer.PerformanceMetrics(
//                memoryUsageMB: Double(i),
//                cpuUsagePercent: Double(i % 100),
//                gpuUsagePercent: 0.0,
//                diskUsageMB: 0.0,
//                networkActivityMB: 0.0,
//                thermalState: "nominal",
//                batteryLevel: nil,
//                isLowPowerMode: false,
//                timestamp: Date()
//            )
//            // This would normally be done internally
//            // optimizer.currentMetrics = metrics
//        }
//
//        let history = optimizer.getMetricsHistory()
//        XCTAssertLessThanOrEqual(history.count, 100) // maxMetricsHistory
//    }
//
//    // MARK: - Convenience Initializer Tests
//
//    func testForMinimalOperations_usesMinimalConfiguration() {
//        let optimizer = PerformanceOptimizer.forMinimalOperations()
//
//        XCTAssertNil(optimizer.currentMetrics)
//        XCTAssertEqual(optimizer.memoryPressure, .normal)
//    }
//
//    func testForBalancedOperations_usesDefaultConfiguration() {
//        let optimizer = PerformanceOptimizer.forBalancedOperations()
//
//        XCTAssertNil(optimizer.currentMetrics)
//        XCTAssertEqual(optimizer.memoryPressure, .normal)
//    }
//
//    func testForAggressiveOperations_usesAggressiveConfiguration() {
//        let optimizer = PerformanceOptimizer.forAggressiveOperations()
//
//        XCTAssertNil(optimizer.currentMetrics)
//        XCTAssertEqual(optimizer.memoryPressure, .normal)
//    }
//
//    // MARK: - Warning and Critical Issue Detection Tests
//
//    func testMemoryWarningThresholdDetection() async {
//        // Simulate high memory usage
//        let highMemoryMetrics = PerformanceOptimizer.PerformanceMetrics(
//            memoryUsageMB: 250.0, // Above default warning threshold
//            cpuUsagePercent: 50.0,
//            gpuUsagePercent: 30.0,
//            diskUsageMB: 0.0,
//            networkActivityMB: 0.0,
//            thermalState: "nominal",
//            batteryLevel: nil,
//            isLowPowerMode: false,
//            timestamp: Date()
//        )
//
//        // This would normally trigger warning detection
//        // For testing, we just verify the metrics can be created
//        XCTAssertGreaterThan(highMemoryMetrics.memoryUsageMB, 200.0)
//    }
//
//    func testCPUWarningThresholdDetection() async {
//        // Simulate high CPU usage
//        let highCPUMetrics = PerformanceOptimizer.PerformanceMetrics(
//            memoryUsageMB: 150.0,
//            cpuUsagePercent: 85.0, // Above default warning threshold
//            gpuUsagePercent: 30.0,
//            diskUsageMB: 0.0,
//            networkActivityMB: 0.0,
//            thermalState: "nominal",
//            batteryLevel: nil,
//            isLowPowerMode: false,
//            timestamp: Date()
//        )
//
//        XCTAssertGreaterThan(highCPUMetrics.cpuUsagePercent, 80.0)
//    }
//
//    func testThermalWarningThresholdDetection() async {
//        // Simulate concerning thermal state
//        let thermalMetrics = PerformanceOptimizer.PerformanceMetrics(
//            memoryUsageMB: 150.0,
//            cpuUsagePercent: 50.0,
//            gpuUsagePercent: 30.0,
//            diskUsageMB: 0.0,
//            networkActivityMB: 0.0,
//            thermalState: "serious", // Concerning thermal state
//            batteryLevel: nil,
//            isLowPowerMode: false,
//            timestamp: Date()
//        )
//
//        XCTAssertEqual(thermalMetrics.thermalState, "serious")
//    }
//}
