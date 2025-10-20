# Improve Trimmer View UI and Video Loading Experience

## Why
The current TrimmerView has a dark background that reduces legibility, and users experience loading issues where videos don't display properly after loading completes. The loading mechanism needs to be more fault-tolerant with better progress indication and file size information to manage user expectations.

## What Changes
- **UI Improvements:** Change TrimmerView background from dark theme to white for better contrast and readability
- **Video Display:** Fix video preview not showing in trimmer view after loading completes
- **Loading Enhancement:** Add file size information to loading UI to set user expectations about loading times
- **Button Updates:** Replace "Preview" button with "Cancel" button to return to video selection
- **Progress Indication:** Ensure loading bar always progresses and never gets stuck to provide reliable feedback
- **Network Resilience:** Improve video loading to work reliably under both mobile network and WiFi conditions

## Impact
- **Affected specs:** video-loading, video-trimming, ui-components
- **Affected code:** Features/Shared/Video/TrimmerView.swift, Features/Shared/Video/VideoLoadingService.swift
- **User experience:** Improved video loading reliability, better UI contrast, more intuitive navigation