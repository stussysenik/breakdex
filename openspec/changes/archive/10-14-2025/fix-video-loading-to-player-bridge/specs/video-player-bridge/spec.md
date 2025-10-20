# Video Player Bridge Specification

## MODIFIED Requirements

### Requirement: TrimmerView SHALL immediately load video asset into SharedVideoPlayer when UnifiedState.selectedVideo becomes available

TrimmerView SHALL immediately load video asset into SharedVideoPlayer when UnifiedState.selectedVideo becomes available by calling SharedVideoPlayer.loadVideoWithRecovery() and ensuring the player transitions from idle to ready state within 2 seconds.

#### Scenario:
- **GIVEN** video loading completes successfully and UnifiedState.selectedVideo is set
- **WHEN** TrimmerView detects the asset change via onChange observer
- **THEN** SharedVideoPlayer.loadVideoWithRecovery(asset) SHALL be called
- **AND** loading progress SHALL be tracked until player becomes ready
- **AND** video content SHALL appear in the 16:9 preview container
- **AND** trimming controls SHALL become active and interactive

### Requirement: TrimmerView SHALL provide reactive asset detection to catch timing gaps between loading completion and player initialization

TrimmerView SHALL provide reactive asset detection using onReceive observer to catch timing gaps when UnifiedState.selectedVideo is available but SharedVideoPlayer remains in idle state, and trigger immediate asset loading to bridge the gap.

#### Scenario:
- **GIVEN** UnifiedState.selectedVideo contains a valid AVAsset
- **AND** SharedVideoPlayer.state == .idle and isReady == false
- **WHEN** the onReceive(unifiedState.$selectedVideo) observer fires
- **THEN** log "🔧 CRITICAL FIX: Detected idle video player with available asset - loading now"
- **AND** call SharedVideoPlayer.loadVideoWithRecovery() immediately
- **AND** initialize trim values after loading completes

### Requirement: TrimmerView SHALL implement fallback state synchronization to handle edge cases in video loading timing

TrimmerView SHALL implement fallback state synchronization mechanisms that perform force state synchronization checks when TrimmerView appears with available video asset but idle player state, ensuring asset loading is triggered and video displays within 3 seconds.

#### Scenario:
- **GIVEN** TrimmerView.onAppear executes with unifiedState.selectedVideo != nil
- **WHEN** initial state check reveals videoPlayer.state == .idle
- **THEN** schedule immediate asset loading via Task
- **AND** set up delayed check after 100ms to verify player state
- **AND** if still idle, force asset loading again with enhanced logging
- **AND** ensure video content displays before user interaction

### Requirement: The video loading to player bridge SHALL provide comprehensive diagnostic logging for debugging timing issues

The video loading to player bridge SHALL provide comprehensive diagnostic logging with correlation IDs and timing measurements for each state transition, gap detection events, and recovery actions to enable effective debugging of timing issues.

#### Scenario:
- **GIVEN** video loading completes with correlation ID "LOAD-12345678"
- **WHEN** asset becomes available in UnifiedState
- **THEN** log "🔄 BRIDGE DETECTED: Asset available, player state: idle, isReady: false"
- **AND** log "🔧 BRIDGE ACTION: Triggering asset loading for correlation ID: LOAD-12345678"
- **AND** measure and log time from bridge detection to player ready state
- **AND** log "✅ BRIDGE COMPLETE: Video displayed in TrimmerView after X.XXXs"

### Requirement: SharedVideoPlayer SHALL handle asset loading requests from TrimmerView with enhanced recovery mechanisms

SharedVideoPlayer SHALL handle asset loading requests from TrimmerView with enhanced recovery mechanisms by transitioning through loading states to ready state, providing automatic recovery for initialization failures, and ensuring consistent isReady flag setting.

#### Scenario:
- **GIVEN** SharedVideoPlayer receives loadVideoWithRecovery(asset) call
- **WHEN** asset loading begins
- **THEN** log "🎬 PLAYER LOADING: Starting asset load from bridge"
- **AND** proceed through validation, player creation, and observer setup
- **AND** ensure isReady flag becomes true when AVPlayerItem.readyToPlay
- **AND** schedule fallback checks to catch state inconsistencies
- **AND** log "✅ PLAYER READY: Bridge successfully completed video loading"