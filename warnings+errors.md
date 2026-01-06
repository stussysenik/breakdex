
Showing Recent Issues

Build target breakdex of project breakdex with configuration Debug

SwiftCompile normal arm64 Compiling\ SelectClip.swift,\ StatePillView.swift,\ ComboNamingSheet.swift /Users/s3nik/Desktop/creativity/programming\ scratchpads/dev\ playground/breakdex/breakdex/Features/AddMove/Views/SelectClip.swift /Users/s3nik/Desktop/creativity/programming\ scratchpads/dev\ playground/breakdex/breakdex/Features/Shared/UI/Components/StatePillView.swift /Users/s3nik/Desktop/creativity/programming\ scratchpads/dev\ playground/breakdex/breakdex/Features/Combo/Views/ComboNamingSheet.swift (in target 'breakdex' from project 'breakdex')

SwiftCompile normal arm64 /Users/s3nik/Desktop/creativity/programming\ scratchpads/dev\ playground/breakdex/breakdex/Features/AddMove/Views/SelectClip.swift (in target 'breakdex' from project 'breakdex')
    cd /Users/s3nik/Desktop/creativity/programming\ scratchpads/dev\ playground/breakdex
    

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/AddMove/Views/SelectClip.swift:206:112: warning: class property 'isMainThread' is unavailable from asynchronous contexts; Work intended for the main actor should be marked with @MainActor; this is an error in the Swift 6 language mode
                Logger.addMove.info("🎯 SelectClip: About to call onStepChange(.trimming) - Thread: \(Thread.isMainThread ? "MAIN" : "BACKGROUND")", emoji: "🎯")
/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS18.5.sdk/System/Library/Frameworks/Foundation.framework/Headers/NSThread.h:51:34: note: 'isMainThread' declared here
@property (class, readonly) BOOL isMainThread API_AVAILABLE(macos(10.5), ios(2.0), watchos(2.0), tvos(9.0)) NS_SWIFT_UNAVAILABLE_FROM_ASYNC("Work intended for the main actor should be marked with @MainActor"); // reports whether current thread is main
                                 ^
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/AddMove/Views/SelectClip.swift:227:112: warning: class property 'isMainThread' is unavailable from asynchronous contexts; Work intended for the main actor should be marked with @MainActor; this is an error in the Swift 6 language mode
                Logger.addMove.info("🎯 SelectClip: About to call onStepChange(.trimming) - Thread: \(Thread.isMainThread ? "MAIN" : "BACKGROUND")", emoji: "🎯")
/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS18.5.sdk/System/Library/Frameworks/Foundation.framework/Headers/NSThread.h:51:34: note: 'isMainThread' declared here
@property (class, readonly) BOOL isMainThread API_AVAILABLE(macos(10.5), ios(2.0), watchos(2.0), tvos(9.0)) NS_SWIFT_UNAVAILABLE_FROM_ASYNC("Work intended for the main actor should be marked with @MainActor"); // reports whether current thread is main
                                 ^

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/AddMove/Views/SelectClip.swift:206:112: Class property 'isMainThread' is unavailable from asynchronous contexts; Work intended for the main actor should be marked with @MainActor; this is an error in the Swift 6 language mode

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/AddMove/Views/SelectClip.swift:227:112: Class property 'isMainThread' is unavailable from asynchronous contexts; Work intended for the main actor should be marked with @MainActor; this is an error in the Swift 6 language mode

SwiftCompile normal arm64 Compiling\ MainView.swift,\ MinimalTrimmerView.swift,\ ComboTimelineView.swift /Users/s3nik/Desktop/creativity/programming\ scratchpads/dev\ playground/breakdex/breakdex/App/MainView.swift /Users/s3nik/Desktop/creativity/programming\ scratchpads/dev\ playground/breakdex/breakdex/Features/Shared/Video/MinimalTrimmerView.swift /Users/s3nik/Desktop/creativity/programming\ scratchpads/dev\ playground/breakdex/breakdex/Features/Combo/Views/ComboTimelineView.swift (in target 'breakdex' from project 'breakdex')

SwiftCompile normal arm64 /Users/s3nik/Desktop/creativity/programming\ scratchpads/dev\ playground/breakdex/breakdex/Features/Shared/Video/MinimalTrimmerView.swift (in target 'breakdex' from project 'breakdex')
    cd /Users/s3nik/Desktop/creativity/programming\ scratchpads/dev\ playground/breakdex
    

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/MinimalTrimmerView.swift:53:12: warning: unnecessary check for 'iOS'; enclosing scope ensures guard will always be true
        if #available(iOS 18.0, *) {
           ^
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/MinimalTrimmerView.swift:36:7: note: enclosing scope here
class iOS18PerformanceManager {
      ^
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/MinimalTrimmerView.swift:639:19: warning: value 'asset' was defined but never used; consider replacing with boolean test
        guard let asset = viewModel.selectedVideo else {
              ~~~~^~~~~~~~
                                                  != nil
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/MinimalTrimmerView.swift:1014:13: warning: initialization of immutable value 'cmTime' was never used; consider replacing with assignment to '_' or removing it
        let cmTime = CMTime(seconds: quantizedTime, preferredTimescale: CMTimeScale(frameRate * 100))
        ~~~~^~~~~~
        _
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/MinimalTrimmerView.swift:1184:15: warning: 'catch' block is unreachable because no errors are thrown in 'do' block
            } catch {
              ^
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/MinimalTrimmerView.swift:1411:16: warning: value 'player' was defined but never used; consider replacing with boolean test
        if let player = player {
           ~~~~^~~~~~~~~
                               != nil

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/MinimalTrimmerView.swift:53:12: Unnecessary check for 'iOS'; enclosing scope ensures guard will always be true

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/MinimalTrimmerView.swift:639:19: Value 'asset' was defined but never used; consider replacing with boolean test

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/MinimalTrimmerView.swift:1014:13: Initialization of immutable value 'cmTime' was never used; consider replacing with assignment to '_' or removing it

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/MinimalTrimmerView.swift:1184:15: 'catch' block is unreachable because no errors are thrown in 'do' block

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/MinimalTrimmerView.swift:1411:16: Value 'player' was defined but never used; consider replacing with boolean test

SwiftCompile normal arm64 Compiling\ MoveDetailView.swift,\ MoveListView.swift,\ AddMoveViewModel.swift /Users/s3nik/Desktop/creativity/programming\ scratchpads/dev\ playground/breakdex/breakdex/Features/Arsenal/Views/MoveDetailView.swift /Users/s3nik/Desktop/creativity/programming\ scratchpads/dev\ playground/breakdex/breakdex/Features/Arsenal/Views/MoveListView.swift /Users/s3nik/Desktop/creativity/programming\ scratchpads/dev\ playground/breakdex/breakdex/Features/AddMove/ViewModels/AddMoveViewModel.swift (in target 'breakdex' from project 'breakdex')

SwiftCompile normal arm64 /Users/s3nik/Desktop/creativity/programming\ scratchpads/dev\ playground/breakdex/breakdex/Features/AddMove/ViewModels/AddMoveViewModel.swift (in target 'breakdex' from project 'breakdex')
    cd /Users/s3nik/Desktop/creativity/programming\ scratchpads/dev\ playground/breakdex
    

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/AddMove/ViewModels/AddMoveViewModel.swift:168:14: warning: capture of 'self' in a closure that outlives deinit; this is an error in the Swift 6 language mode
        Task { @MainActor in
             ^

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/AddMove/ViewModels/AddMoveViewModel.swift:168:14: Capture of 'self' in a closure that outlives deinit; this is an error in the Swift 6 language mode

SwiftCompile normal arm64 Compiling\ FeedbackToast.swift,\ ComboListView.swift /Users/s3nik/Desktop/creativity/programming\ scratchpads/dev\ playground/breakdex/breakdex/Features/Shared/UI/Components/FeedbackToast.swift /Users/s3nik/Desktop/creativity/programming\ scratchpads/dev\ playground/breakdex/breakdex/Features/Arsenal/Views/ComboListView.swift (in target 'breakdex' from project 'breakdex')

SwiftCompile normal arm64 /Users/s3nik/Desktop/creativity/programming\ scratchpads/dev\ playground/breakdex/breakdex/Features/Arsenal/Views/ComboListView.swift (in target 'breakdex' from project 'breakdex')
    cd /Users/s3nik/Desktop/creativity/programming\ scratchpads/dev\ playground/breakdex
    

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Arsenal/Views/ComboListView.swift:255:10: warning: immutable value 'index' was never used; consider replacing with '_' or removing it
    for (index, name) in testCombos.enumerated() {
         ^~~~~
         _

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Arsenal/Views/ComboListView.swift:255:10: Immutable value 'index' was never used; consider replacing with '_' or removing it

SwiftCompile normal arm64 Compiling\ BreadcrumbView.swift,\ VideoPlayer.swift,\ ComboDetailView.swift /Users/s3nik/Desktop/creativity/programming\ scratchpads/dev\ playground/breakdex/breakdex/Features/Shared/UI/Components/BreadcrumbView.swift /Users/s3nik/Desktop/creativity/programming\ scratchpads/dev\ playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift /Users/s3nik/Desktop/creativity/programming\ scratchpads/dev\ playground/breakdex/breakdex/Features/Combo/Views/ComboDetailView.swift (in target 'breakdex' from project 'breakdex')

SwiftCompile normal arm64 /Users/s3nik/Desktop/creativity/programming\ scratchpads/dev\ playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift (in target 'breakdex' from project 'breakdex')
    cd /Users/s3nik/Desktop/creativity/programming\ scratchpads/dev\ playground/breakdex
    

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:126:91: warning: 'tracks' was deprecated in iOS 16.0: Use load(.tracks) instead
        Logger.loadingState.info("🎬 SharedVideoPlayer: Loading asset - tracks: \(asset.tracks.count), duration: \(asset.duration.seconds)s")
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:126:124: warning: 'duration' was deprecated in iOS 16.0: Use load(.duration) instead
        Logger.loadingState.info("🎬 SharedVideoPlayer: Loading asset - tracks: \(asset.tracks.count), duration: \(asset.duration.seconds)s")
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:131:71: warning: 'tracks' was deprecated in iOS 16.0: Use load(.tracks) instead
        logger.info("🔍 DIAGNOSTIC: Asset details - tracks: \(asset.tracks.count), duration: \(asset.duration.seconds)s")
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:131:104: warning: 'duration' was deprecated in iOS 16.0: Use load(.duration) instead
        logger.info("🔍 DIAGNOSTIC: Asset details - tracks: \(asset.tracks.count), duration: \(asset.duration.seconds)s")
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:221:75: warning: comparing non-optional value of type 'AVPlayer' to 'nil' always returns true
            logger.info("🔍 DIAGNOSTIC: Final player instance: \(player != nil ? "exists" : "nil")")
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:222:83: warning: comparing non-optional value of type 'AVPlayerItem' to 'nil' always returns true
            logger.info("🔍 DIAGNOSTIC: Final playerItem instance: \(playerItem != nil ? "exists" : "nil")")
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:479:47: warning: immutable value 'currentPlayerItem' was never used; consider replacing with '_' or removing it
        guard let currentPlayer = player, let currentPlayerItem = playerItem else {
                                          ~~~~^~~~~~~~~~~~~~~~~
                                          _
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:487:13: warning: initialization of immutable value 'currentTime' was never used; consider replacing with assignment to '_' or removing it
        let currentTime = CFAbsoluteTimeGetCurrent()
        ~~~~^~~~~~~~~~~
        _
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:604:64: warning: capture of 'keyPath' with non-sendable type 'KeyPath<T, Value>' in a '@Sendable' closure
            let observerKey = "\(String(describing: T.self)).\(keyPath)"
                                                               ^
Swift.KeyPath:1:14: note: generic class 'KeyPath' does not conform to the 'Sendable' protocol
public class KeyPath<Root, Value> : PartialKeyPath<Root> {
             ^
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:607:44: warning: main actor-isolated property 'registeredObservers' can not be referenced from a Sendable closure; this is an error in the Swift 6 language mode
            if let existingObserver = self.registeredObservers[observerKey] {
                                           ^
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:42:17: note: property declared here
    private var registeredObservers: [String: NSKeyValueObservation] = [:]
                ^
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:610:22: warning: main actor-isolated property 'registeredObservers' can not be mutated from a Sendable closure; this is an error in the Swift 6 language mode
                self.registeredObservers.removeValue(forKey: observerKey)
                     ^
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:42:17: note: mutation of this property is only permitted within the actor
    private var registeredObservers: [String: NSKeyValueObservation] = [:]
                ^
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:620:18: warning: main actor-isolated property 'registeredObservers' can not be mutated from a Sendable closure; this is an error in the Swift 6 language mode
            self.registeredObservers[observerKey] = newObserver
                 ^
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:42:17: note: mutation of this property is only permitted within the actor
    private var registeredObservers: [String: NSKeyValueObservation] = [:]
                ^
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:630:36: warning: main actor-isolated property 'registeredObservers' can not be referenced from a Sendable closure; this is an error in the Swift 6 language mode
            if let observer = self.registeredObservers[key] {
                                   ^
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:42:17: note: property declared here
    private var registeredObservers: [String: NSKeyValueObservation] = [:]
                ^
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:633:22: warning: main actor-isolated property 'registeredObservers' can not be mutated from a Sendable closure; this is an error in the Swift 6 language mode
                self.registeredObservers.removeValue(forKey: key)
                     ^
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:42:17: note: mutation of this property is only permitted within the actor
    private var registeredObservers: [String: NSKeyValueObservation] = [:]
                ^
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:645:82: warning: main actor-isolated property 'registeredObservers' can not be referenced from a Sendable closure; this is an error in the Swift 6 language mode
            self.logger.info("🧹 Removing all registered KVO observers (\(self.registeredObservers.count))")
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:42:17: note: property declared here
    private var registeredObservers: [String: NSKeyValueObservation] = [:]
                ^
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:647:41: warning: main actor-isolated property 'registeredObservers' can not be referenced from a Sendable closure; this is an error in the Swift 6 language mode
            for (key, observer) in self.registeredObservers {
                                        ^
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:42:17: note: property declared here
    private var registeredObservers: [String: NSKeyValueObservation] = [:]
                ^
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:652:18: warning: main actor-isolated property 'registeredObservers' can not be mutated from a Sendable closure; this is an error in the Swift 6 language mode
            self.registeredObservers.removeAll()
                 ^
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:42:17: note: mutation of this property is only permitted within the actor
    private var registeredObservers: [String: NSKeyValueObservation] = [:]
                ^
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:655:18: warning: call to main actor-isolated instance method 'safelyRemoveAllNotificationObservers()' in a synchronous nonisolated context; this is an error in the Swift 6 language mode
            self.safelyRemoveAllNotificationObservers()
                 ^
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:722:18: note: calls to instance method 'safelyRemoveAllNotificationObservers()' from outside of its actor context are implicitly asynchronous
    private func safelyRemoveAllNotificationObservers() {
                 ^
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:714:20: warning: passing non-sendable parameter 'handler' to function expecting a @Sendable closure
            using: handler
                   ^
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:708:9: note: parameter 'handler' is implicitly non-sendable
        handler: @escaping (Notification) -> Void
        ^
                 @Sendable 
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:825:17: warning: variable 'continuationState' was never mutated; consider changing to 'let' constant
            var continuationState = ContinuationState()
            ~~~ ^
            let
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:847:17: warning: variable 'timeoutTask' was never mutated; consider changing to 'let' constant
            var timeoutTask: Task<Void, Never>? = Task { @MainActor [weak self] in
            ~~~ ^
            let
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:860:24: warning: capture of 'continuationState' with non-sendable type 'SharedVideoPlayer.ContinuationState' in a '@Sendable' closure
                guard !continuationState.isResumed else {
                       ^
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:1022:19: note: class 'ContinuationState' does not conform to the 'Sendable' protocol
    private class ContinuationState {
                  ^
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:866:22: warning: call to main actor-isolated instance method 'logPlayerDiagnostics(continuationId:playerItem:context:)' in a synchronous nonisolated context; this is an error in the Swift 6 language mode
                self.logPlayerDiagnostics(continuationId: continuationId, playerItem: item, context: "STATUS CHANGE")
                     ^
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:940:18: note: calls to instance method 'logPlayerDiagnostics(continuationId:playerItem:context:)' from outside of its actor context are implicitly asynchronous
    private func logPlayerDiagnostics(continuationId: String, playerItem: AVPlayerItem, context: String) {
                 ^
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:871:26: warning: call to main actor-isolated instance method 'logPlayerDiagnostics(continuationId:playerItem:context:)' in a synchronous nonisolated context; this is an error in the Swift 6 language mode
                    self.logPlayerDiagnostics(continuationId: continuationId, playerItem: item, context: "READY SUCCESS")
                         ^
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:940:18: note: calls to instance method 'logPlayerDiagnostics(continuationId:playerItem:context:)' from outside of its actor context are implicitly asynchronous
    private func logPlayerDiagnostics(continuationId: String, playerItem: AVPlayerItem, context: String) {
                 ^
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:872:26: warning: call to main actor-isolated instance method 'safelyRemoveObserver(forKey:)' in a synchronous nonisolated context; this is an error in the Swift 6 language mode
                    self.safelyRemoveObserver(forKey: observerKey)
                         ^
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:626:18: note: calls to instance method 'safelyRemoveObserver(forKey:)' from outside of its actor context are implicitly asynchronous
    private func safelyRemoveObserver(forKey key: String) {
                 ^
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:879:26: warning: call to main actor-isolated instance method 'logPlayerDiagnostics(continuationId:playerItem:context:)' in a synchronous nonisolated context; this is an error in the Swift 6 language mode
                    self.logPlayerDiagnostics(continuationId: continuationId, playerItem: item, context: "PLAYER FAILED")
                         ^
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:940:18: note: calls to instance method 'logPlayerDiagnostics(continuationId:playerItem:context:)' from outside of its actor context are implicitly asynchronous
    private func logPlayerDiagnostics(continuationId: String, playerItem: AVPlayerItem, context: String) {
                 ^
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:880:26: warning: call to main actor-isolated instance method 'safelyRemoveObserver(forKey:)' in a synchronous nonisolated context; this is an error in the Swift 6 language mode
                    self.safelyRemoveObserver(forKey: observerKey)
                         ^
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:626:18: note: calls to instance method 'safelyRemoveObserver(forKey:)' from outside of its actor context are implicitly asynchronous
    private func safelyRemoveObserver(forKey key: String) {
                 ^
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:886:26: warning: call to main actor-isolated instance method 'logPlayerDiagnostics(continuationId:playerItem:context:)' in a synchronous nonisolated context; this is an error in the Swift 6 language mode
                    self.logPlayerDiagnostics(continuationId: continuationId, playerItem: item, context: "STILL UNKNOWN")
                         ^
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:940:18: note: calls to instance method 'logPlayerDiagnostics(continuationId:playerItem:context:)' from outside of its actor context are implicitly asynchronous
    private func logPlayerDiagnostics(continuationId: String, playerItem: AVPlayerItem, context: String) {
                 ^
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:987:70: warning: 'naturalSize' was deprecated in iOS 16.0: Use load(.naturalSize) instead
                logger.info("🔬 Video Track \(index): \(assetTrack.naturalSize) @ \(assetTrack.preferredTransform)")
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:987:98: warning: 'preferredTransform' was deprecated in iOS 16.0: Use load(.preferredTransform) instead
                logger.info("🔬 Video Track \(index): \(assetTrack.naturalSize) @ \(assetTrack.preferredTransform)")
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:988:77: warning: 'formatDescriptions' was deprecated in iOS 16.0: Use load(.formatDescriptions) instead
                logger.info("🔬 Video Track \(index) format: \(assetTrack.formatDescriptions)")
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:989:79: warning: 'isPlayable' was deprecated in iOS 16.0: Use load(.isPlayable) instead
                logger.info("🔬 Video Track \(index) playable: \(assetTrack.isPlayable)")
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:999:79: warning: 'isPlayable' was deprecated in iOS 16.0: Use load(.isPlayable) instead
                logger.info("🔬 Audio Track \(index): playable=\(assetTrack.isPlayable), enabled=\(track.isEnabled)")
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:1055:37: warning: main actor-isolated property 'registeredObservers' can not be referenced from a Sendable closure; this is an error in the Swift 6 language mode
            let keysToRemove = self.registeredObservers.keys.filter { $0.hasPrefix("waitForPlayerReady.") }
                                    ^
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:42:17: note: property declared here
    private var registeredObservers: [String: NSKeyValueObservation] = [:]
                ^
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:1058:40: warning: main actor-isolated property 'registeredObservers' can not be referenced from a Sendable closure; this is an error in the Swift 6 language mode
                if let observer = self.registeredObservers[key] {
                                       ^
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:42:17: note: property declared here
    private var registeredObservers: [String: NSKeyValueObservation] = [:]
                ^
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:1060:26: warning: main actor-isolated property 'registeredObservers' can not be mutated from a Sendable closure; this is an error in the Swift 6 language mode
                    self.registeredObservers.removeValue(forKey: key)
                         ^
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:42:17: note: mutation of this property is only permitted within the actor
    private var registeredObservers: [String: NSKeyValueObservation] = [:]
                ^
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:1069:19: warning: value 'player' was defined but never used; consider replacing with boolean test
        guard let player = player else {
              ~~~~^~~~~~~~~
                                  != nil
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:1474:40: warning: immutable value 'playerItem' was never used; consider replacing with '_' or removing it
        guard !timeRanges.isEmpty, let playerItem = playerItem else { return }
                                   ~~~~^~~~~~~~~~
                                   _
/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:1730:27: warning: immutable value 'progress' was never used; consider replacing with '_' or removing it
        case .loading(let progress, let message):
                      ~~~~^~~~~~~~
                      _

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:126:91: 'tracks' was deprecated in iOS 16.0: Use load(.tracks) instead

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:126:124: 'duration' was deprecated in iOS 16.0: Use load(.duration) instead

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:131:71: 'tracks' was deprecated in iOS 16.0: Use load(.tracks) instead

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:131:104: 'duration' was deprecated in iOS 16.0: Use load(.duration) instead

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:221:75: Comparing non-optional value of type 'AVPlayer' to 'nil' always returns true

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:222:83: Comparing non-optional value of type 'AVPlayerItem' to 'nil' always returns true

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:479:47: Immutable value 'currentPlayerItem' was never used; consider replacing with '_' or removing it

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:487:13: Initialization of immutable value 'currentTime' was never used; consider replacing with assignment to '_' or removing it

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:604:64: Capture of 'keyPath' with non-sendable type 'KeyPath<T, Value>' in a '@Sendable' closure

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:607:44: Main actor-isolated property 'registeredObservers' can not be referenced from a Sendable closure; this is an error in the Swift 6 language mode

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:610:22: Main actor-isolated property 'registeredObservers' can not be mutated from a Sendable closure; this is an error in the Swift 6 language mode

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:620:18: Main actor-isolated property 'registeredObservers' can not be mutated from a Sendable closure; this is an error in the Swift 6 language mode

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:630:36: Main actor-isolated property 'registeredObservers' can not be referenced from a Sendable closure; this is an error in the Swift 6 language mode

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:633:22: Main actor-isolated property 'registeredObservers' can not be mutated from a Sendable closure; this is an error in the Swift 6 language mode

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:645:82: Main actor-isolated property 'registeredObservers' can not be referenced from a Sendable closure; this is an error in the Swift 6 language mode

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:647:41: Main actor-isolated property 'registeredObservers' can not be referenced from a Sendable closure; this is an error in the Swift 6 language mode

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:652:18: Main actor-isolated property 'registeredObservers' can not be mutated from a Sendable closure; this is an error in the Swift 6 language mode

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:655:18: Call to main actor-isolated instance method 'safelyRemoveAllNotificationObservers()' in a synchronous nonisolated context; this is an error in the Swift 6 language mode

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:714:20: Passing non-sendable parameter 'handler' to function expecting a @Sendable closure

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:825:17: Variable 'continuationState' was never mutated; consider changing to 'let' constant

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:847:17: Variable 'timeoutTask' was never mutated; consider changing to 'let' constant

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:860:24: Capture of 'continuationState' with non-sendable type 'SharedVideoPlayer.ContinuationState' in a '@Sendable' closure

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:866:22: Call to main actor-isolated instance method 'logPlayerDiagnostics(continuationId:playerItem:context:)' in a synchronous nonisolated context; this is an error in the Swift 6 language mode

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:871:26: Call to main actor-isolated instance method 'logPlayerDiagnostics(continuationId:playerItem:context:)' in a synchronous nonisolated context; this is an error in the Swift 6 language mode

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:872:26: Call to main actor-isolated instance method 'safelyRemoveObserver(forKey:)' in a synchronous nonisolated context; this is an error in the Swift 6 language mode

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:879:26: Call to main actor-isolated instance method 'logPlayerDiagnostics(continuationId:playerItem:context:)' in a synchronous nonisolated context; this is an error in the Swift 6 language mode

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:880:26: Call to main actor-isolated instance method 'safelyRemoveObserver(forKey:)' in a synchronous nonisolated context; this is an error in the Swift 6 language mode

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:886:26: Call to main actor-isolated instance method 'logPlayerDiagnostics(continuationId:playerItem:context:)' in a synchronous nonisolated context; this is an error in the Swift 6 language mode

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:987:70: 'naturalSize' was deprecated in iOS 16.0: Use load(.naturalSize) instead

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:987:98: 'preferredTransform' was deprecated in iOS 16.0: Use load(.preferredTransform) instead

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:988:77: 'formatDescriptions' was deprecated in iOS 16.0: Use load(.formatDescriptions) instead

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:989:79: 'isPlayable' was deprecated in iOS 16.0: Use load(.isPlayable) instead

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:999:79: 'isPlayable' was deprecated in iOS 16.0: Use load(.isPlayable) instead

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:1055:37: Main actor-isolated property 'registeredObservers' can not be referenced from a Sendable closure; this is an error in the Swift 6 language mode

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:1058:40: Main actor-isolated property 'registeredObservers' can not be referenced from a Sendable closure; this is an error in the Swift 6 language mode

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:1060:26: Main actor-isolated property 'registeredObservers' can not be mutated from a Sendable closure; this is an error in the Swift 6 language mode

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:1069:19: Value 'player' was defined but never used; consider replacing with boolean test

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:1474:40: Immutable value 'playerItem' was never used; consider replacing with '_' or removing it

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/Shared/Video/VideoPlayer.swift:1730:27: Immutable value 'progress' was never used; consider replacing with '_' or removing it

SwiftCompile normal arm64 Compiling\ AddMoveView.swift,\ ThemeManager.swift /Users/s3nik/Desktop/creativity/programming\ scratchpads/dev\ playground/breakdex/breakdex/Features/AddMove/Views/AddMoveView.swift /Users/s3nik/Desktop/creativity/programming\ scratchpads/dev\ playground/breakdex/breakdex/Features/Shared/Services/ThemeManager.swift (in target 'breakdex' from project 'breakdex')

SwiftCompile normal arm64 /Users/s3nik/Desktop/creativity/programming\ scratchpads/dev\ playground/breakdex/breakdex/Features/AddMove/Views/AddMoveView.swift (in target 'breakdex' from project 'breakdex')
    cd /Users/s3nik/Desktop/creativity/programming\ scratchpads/dev\ playground/breakdex
    

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/AddMove/Views/AddMoveView.swift:240:69: warning: class property 'isMainThread' is unavailable from asynchronous contexts; Work intended for the main actor should be marked with @MainActor; this is an error in the Swift 6 language mode
            Logger.addMove.info("📊 AddMoveView: Thread: \(Thread.isMainThread ? "MAIN" : "BACKGROUND")", emoji: "📊")
/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS18.5.sdk/System/Library/Frameworks/Foundation.framework/Headers/NSThread.h:51:34: note: 'isMainThread' declared here
@property (class, readonly) BOOL isMainThread API_AVAILABLE(macos(10.5), ios(2.0), watchos(2.0), tvos(9.0)) NS_SWIFT_UNAVAILABLE_FROM_ASYNC("Work intended for the main actor should be marked with @MainActor"); // reports whether current thread is main
                                 ^

/Users/s3nik/Desktop/creativity/programming scratchpads/dev playground/breakdex/breakdex/Features/AddMove/Views/AddMoveView.swift:240:69: Class property 'isMainThread' is unavailable from asynchronous contexts; Work intended for the main actor should be marked with @MainActor; this is an error in the Swift 6 language mode