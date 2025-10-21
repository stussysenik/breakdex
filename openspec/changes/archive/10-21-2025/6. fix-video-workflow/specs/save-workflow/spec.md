## MODIFIED Requirements
### Requirement: Save Completion State
The AddMove workflow SHALL return to ready state after successful save instead of navigating away.

#### Scenario: Save completes successfully
- **WHEN** a move is successfully saved with video export
- **THEN** AddMoveView state changes from .complete to .ready
- **AND** resetForNextMove() is called on AddMoveViewModel
- **AND** SelectClip button remains visible for creating additional moves
- **AND** no automatic tab navigation occurs

#### Scenario: Reset for next move
- **WHEN** resetForNextMove() is called
- **THEN** form fields are cleared
- **AND** video selection state is reset
- **AND** trim boundaries are cleared
- **AND** UI returns to initial state ready for new input
