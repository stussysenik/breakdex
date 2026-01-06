# Video Trimmer - Highlight Alignment Fix

## ADDED Requirements

### Requirement: Precise Highlight-to-Handle Alignment
The video trimmer SHALL align the blue selected range highlight perfectly with the centers of the trim handles to eliminate visual discrepancy and improve user experience.

#### Scenario: Handle-Highlight Visual Alignment
**Given** the video trimmer is displayed with trim handles positioned
**When** the user views the selected range
**Then** the blue highlight must start exactly at the center of the left handle and end exactly at the center of the right handle
**And** there must be no visible gaps or overlaps between the highlight edges and handle centers

#### Scenario: Extreme Position Alignment
**Given** the left handle is positioned at 0 seconds
**When** the user views the timeline
**Then** the blue highlight must start at the center of the left handle (handle radius offset from timeline start)
**And** when the right handle is at video duration, the highlight must end at the center of the right handle (handle radius offset from timeline end)

#### Scenario: Dynamic Drag Alignment
**Given** the user is dragging a trim handle
**When** the handle position changes
**Then** the blue highlight must update in real-time to maintain perfect alignment with the new handle center position
**And** the highlight width must equal the distance between handle centers

### Requirement: Coordinate Calculation Consistency
The trimmer SHALL use consistent coordinate calculations for both handle positioning and highlight positioning.

#### Scenario: Handle Center Coordinate Calculation
**Given** a time value needs to be converted to a handle center position
**When** calculating the position
**Then** the coordinate must be calculated as: `timeToCoordinate(time, totalWidth) + (handleWidth / 2.0)`
**And** this calculation must be used for both handle positioning and highlight boundaries

#### Scenario: Highlight Width Calculation
**Given** start and end handle center coordinates are calculated
**When** determining the highlight width
**Then** the width must be calculated as: `max(0, endHandleCenterCoord - startHandleCenterCoord)`
**And** the highlight must be positioned with an offset of `startHandleCenterCoord`

### Requirement: Visual Edge Precision
The highlight SHALL use precise rectangular edges rather than capsule shapes to ensure exact alignment with handle centers.

#### Scenario: Precise Highlight Edges
**Given** the selected range highlight is rendered
**When** displaying the highlight
**Then** a Rectangle must be used instead of a Capsule
**And** the Rectangle must have sharp, defined edges that align exactly with handle centers
**And** the Rectangle must have the same height as the timeline track (40px)