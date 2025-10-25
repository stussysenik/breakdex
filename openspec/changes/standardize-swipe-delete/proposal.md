## Why
The ComboListView and MoveListView both implement swipe-to-delete functionality, but there are subtle differences in their implementation patterns (List vs ScrollView/LazyVStack) that could lead to inconsistent user experience. The goal is to ensure both views have identical swipe-to-delete behavior and feel.

## What Changes
- Standardize swipe-to-delete behavior between ComboListView and MoveListView
- Ensure consistent visual feedback, haptics, and animation patterns
- Align the underlying UI component patterns (List vs ScrollView) for consistency
- Maintain the functional behavior from ComboListView as the baseline

## Impact
- Affected specs: ui-interactions
- Affected code: Features/Arsenal/Views/ComboListView.swift, Features/Arsenal/Views/MoveListView.swift
- No breaking changes - only behavioral consistency improvements