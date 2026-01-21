# Proposal: Clean iOS Project Structure

## Summary

Remove duplicate folders, development scripts, and build artifacts from the repository to establish a clean, standard iOS project structure. The current structure has source code duplicated at both root level AND inside `breakdex/` subfolder, plus Ruby scripts and log files that shouldn't be in the repo.

## Problem Statement

The repository has a messy structure with several issues:

### 1. Duplicate Source Folders
The following folders exist BOTH at root AND inside `breakdex/`:
- `App/` (2 copies)
- `Assets.xcassets/` (2 copies)
- `breakdex.xcdatamodeld/` (2 copies)
- `CoreData/` (2 copies)
- `Features/` (2 copies)
- `Fonts/` (2 copies)

The actual working code (92 Swift files) is in `breakdex/`. The root-level copies appear to be from git history divergence.

### 2. Non-iOS Files in Repository
- `add_missing_files.rb` - Ruby script for Xcode project manipulation
- `add_test_files.rb` - Ruby script for adding test files
- `research-01-20-26.md` - Research notes (29KB)
- `test_output.log` - Test output (37KB)

### 3. Build Artifacts
- `TestResults.xcresult/` - Xcode test results (should be gitignored)

### 4. Extra/Archive Folder
- `Extra/` folder at root contains old/archived content

## Proposed Solution

Establish the standard iOS project structure:

```
breakdex/                       # Repository root
├── breakdex.xcodeproj/         # Xcode project
├── breakdex/                   # Main app target (source code)
│   ├── App/
│   ├── Features/
│   ├── CoreData/
│   ├── Assets.xcassets/
│   ├── Fonts/
│   ├── Info.plist
│   └── breakdex.xcdatamodeld/
├── breakdexUITests/            # UI test target
├── Docs/                       # Documentation
├── openspec/                   # Spec system
├── .gitignore                  # Updated to exclude artifacts
├── CLAUDE.md                   # AI assistant config
└── AGENTS.md                   # AI assistant config
```

## Changes Required

### Remove from Git (Delete)
1. Root-level duplicate folders:
   - `App/`
   - `Assets.xcassets/`
   - `breakdex.xcdatamodeld/`
   - `CoreData/`
   - `Features/`
   - `Fonts/`
   - `Extra/`
   - `Info.plist`

2. Development scripts and artifacts:
   - `add_missing_files.rb`
   - `add_test_files.rb`
   - `research-01-20-26.md`
   - `test_output.log`
   - `TestResults.xcresult/`

3. Consolidate test targets:
   - Keep `breakdexUITests/` (primary)
   - Remove or merge `breakdexUITests-01-20-26/` (dated duplicate)

### Update .gitignore
Add patterns to prevent future artifacts:
```
# Build artifacts
*.xcresult
TestResults.xcresult/

# Development scripts
*.rb

# Logs
*.log

# Research/scratch files
research-*.md
```

### Keep (No Changes)
- `breakdex/` - All actual source code
- `breakdex.xcodeproj/` - Xcode project
- `breakdexUITests/` - UI tests
- `Docs/` - Documentation
- `openspec/` - Spec system
- `CLAUDE.md`, `AGENTS.md` - AI config

## Impact

- **Git History**: Preserved (removing duplicates, not rewriting history)
- **Build**: No impact (source code in `breakdex/` unchanged)
- **Tests**: May need to verify `breakdexUITests-01-20-26` tests are in main target
- **Documentation**: Preserved in `Docs/`

## Risks

1. **Test Coverage**: Need to verify no unique tests exist only in `breakdexUITests-01-20-26`
2. **Xcode References**: May need to update project file if it references root-level folders

## Success Criteria

1. `git status` shows clean working tree after commit
2. `ls` at root shows only: `breakdex/`, `breakdex.xcodeproj/`, `breakdexUITests/`, `Docs/`, `openspec/`, config files
3. Xcode project builds successfully
4. All tests pass
