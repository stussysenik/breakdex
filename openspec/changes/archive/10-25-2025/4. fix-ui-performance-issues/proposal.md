## Why
The breakdex app has two critical UI performance issues that significantly impact user experience: 1) TextField input lag in the combo creation alert causing 2.7+ second delays, and 2) NavigationStack conflicts preventing ComboDetailView from displaying when users tap on combos in the list.

## What Changes
- Remove nested NavigationStack from ComboDetailView to fix navigation failures
- Replace SwiftUI alert TextField with custom sheet implementation using @FocusState for instant responsiveness
- Optimize keyboard session management and eliminate AutoLayout conflicts
- Add proper focus management and haptic feedback for improved UX

## Impact
- Affected specs: ui-navigation, combo-creation
- Affected code: Features/Combo/Views/ComboDetailView.swift, Features/Combo/Views/CreateComboView.swift
- **BREAKING**: None - fixes existing broken functionality only