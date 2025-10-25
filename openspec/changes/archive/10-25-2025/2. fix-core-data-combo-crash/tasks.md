## 1. Core Data Crash Fix (CRITICAL)
- [ ] 1.1 Remove illegal hash override from Combo+CoreDataClass.swift:14-21
- [ ] 1.2 Remove illegal hash override from ComboMove+CoreDataClass.swift:14-21
- [ ] 1.3 Remove illegal hash override from Review+CoreDataClass.swift:14-21
- [ ] 1.4 Test combo creation no longer crashes in simulator
- [ ] 1.5 Verify Core Data relationships work correctly after hash removal

## 2. NavigationStack Modernization
- [ ] 2.1 Replace placeholder NavigationLink in ComboListView.swift:174-186
- [ ] 2.2 Add NavigationStack with NavigationLink(value: combo) pattern
- [ ] 2.3 Implement navigationDestination(for: NSManagedObjectID.self) modifier
- [ ] 2.4 Test type-safe navigation from list to detail view
- [ ] 2.5 Verify navigation back button works correctly

## 3. ComboDetailView Implementation
- [ ] 3.1 Create new ComboDetailView.swift file with proper structure
- [ ] 3.2 Implement combo header with name, learning state, move count
- [ ] 3.3 Integrate existing ComboTimelineView component
- [ ] 3.4 Add navigationDestination for Move entities from timeline
- [ ] 3.5 Test combo detail view displays correctly with real data

## 4. Timeline Interaction Enhancement
- [ ] 4.1 Enhance ComboTimelineView to support navigationDestination
- [ ] 4.2 Implement clickable timeline node selection with visual feedback
- [ ] 4.3 Connect timeline selection to video playback in ComboViewModel
- [ ] 4.4 Test timeline node tapping triggers correct video loading
- [ ] 4.5 Verify timeline selection state persists during navigation

## 5. Integration and Validation
- [ ] 5.1 Test complete user flow: create combo → see in list → view details → interact with timeline
- [ ] 5.2 Verify Core Data relationships fetch correctly (combo moves, learning states)
- [ ] 5.3 Test with multiple combos and varying numbers of moves
- [ ] 5.4 Run app on iOS Simulator to verify no crashes or navigation issues
- [ ] 5.5 Validate all timeline interactions work with real video assets

## 6. Code Quality and Documentation
- [ ] 6.1 Add comprehensive logging for navigation and timeline interactions
- [ ] 6.2 Update inline comments explaining Core Data identity management
- [ ] 6.3 Verify all new code follows project's clean architecture patterns
- [ ] 6.4 Run syntax validation on all modified files
- [ ] 6.5 Build project successfully with no compilation errors