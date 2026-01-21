# Tasks: Clean iOS Project Structure

## Pre-flight Checks

- [x] **1. Verify test coverage**
  - Compare tests in `breakdexUITests/` vs `breakdexUITests-01-20-26/`
  - Ensure no unique tests will be lost
  - Document any tests to merge
  - **Result:** Merged 10 unique tests from dated target into main target

- [x] **2. Backup current state**
  - Ensure all changes are committed or stashed
  - Note current HEAD commit hash

## Cleanup Tasks

- [x] **3. Update .gitignore**
  - Add `*.xcresult`, `*.rb`, `*.log`, `research-*.md` patterns
  - Also added: `DerivedData/`, `build/`, `*.xcuserstate`, `*.dSYM`
  - Commit .gitignore changes first

- [x] **4. Remove duplicate source folders from root**
  - `rm -rf App/`
  - `rm -rf Assets.xcassets/`
  - `rm -rf breakdex.xcdatamodeld/`
  - `rm -rf CoreData/`
  - `rm -rf Features/`
  - `rm -rf Fonts/`
  - `rm -rf Extra/`
  - `rm Info.plist`

- [x] **5. Remove development scripts and artifacts**
  - `rm add_missing_files.rb`
  - `rm add_test_files.rb`
  - `rm research-01-20-26.md`
  - `rm -rf TestResults.xcresult/`

- [x] **6. Handle test target duplication**
  - Reviewed `breakdexUITests-01-20-26/` contents (14 files)
  - Merged unique tests into `breakdexUITests/` (now 14 files)
  - Removed `breakdexUITests-01-20-26/`

## Added: Pre-commit Hook

- [x] **6.5. Create pre-commit hook for structure validation**
  - Created `.scripts/validate-structure.sh` validation script
  - Created `.githooks/pre-commit` hook
  - Enable with: `git config core.hooksPath .githooks`

## Verification

- [x] **7. Verify structure**
  - Ran `.scripts/validate-structure.sh` - PASSED
  - Structure validated successfully

- [ ] **8. Verify Xcode project**
  - Open `breakdex.xcodeproj` in Xcode
  - Confirm no broken file references (red files)
  - Confirm build succeeds

- [ ] **9. Run tests**
  - Execute all UI tests
  - Verify test suite passes

- [x] **10. Final git status check**
  - Root contains: `breakdex/`, `breakdex.xcodeproj/`, `breakdexUITests/`, `Docs/`, `openspec/`, `.gitignore`, `CLAUDE.md`, `AGENTS.md`, `.scripts/`, `.githooks/`

## Commit

- [ ] **11. Create cleanup commit**
  - Stage all changes
  - Commit with message: `chore: clean project structure - remove duplicates and artifacts`
  - Push to remote

## Dependencies

- Tasks 1-2 must complete before 3-6
- Tasks 3-6 can run in parallel
- Task 7-10 must follow 4-6
- Task 11 follows all verification
