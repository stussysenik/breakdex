## Why
The TrimmerView.swift file has critical compilation errors preventing the app from building, including syntax errors, undefined references, and string interpolation issues.

## What Changes
- Fix string literal interpolation syntax error on line 1766
- Restore missing property and method references (logger, unifiedState, videoPlayer, etc.)
- Fix missing parentheses and function call syntax
- Remove extraneous closing braces causing "at top level" errors
- Ensure all required dependencies are properly declared

## Impact
- Affected specs: video-trimming (to be created)
- Affected code: Features/Shared/Video/TrimmerView.swift (lines 1766-1853)
- Build system: Critical fixes needed for successful compilation