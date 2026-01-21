#!/bin/bash
# validate-structure.sh - Validates iOS project structure for breakdex
# Run this script to ensure project follows standard iOS structure

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_ROOT"

echo "Validating breakdex project structure..."

ERRORS=0

# Check required directories exist
REQUIRED_DIRS=("breakdex" "breakdex.xcodeproj" "breakdexUITests" "Docs" "openspec")
for dir in "${REQUIRED_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        echo "ERROR: Missing required directory: $dir"
        ERRORS=$((ERRORS + 1))
    fi
done

# Check that source code is ONLY in breakdex/ subfolder (not at root)
DUPLICATE_DIRS=("App" "Assets.xcassets" "CoreData" "Features" "Fonts" "Extra")
for dir in "${DUPLICATE_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo "ERROR: Duplicate source folder at root: $dir/ (should only be in breakdex/)"
        ERRORS=$((ERRORS + 1))
    fi
done

# Check for development scripts at root (should be in .scripts/)
if ls *.rb 1> /dev/null 2>&1; then
    echo "ERROR: Ruby scripts found at root (move to .scripts/ or remove)"
    ERRORS=$((ERRORS + 1))
fi

# Check for research files at root
if ls research-*.md 1> /dev/null 2>&1; then
    echo "ERROR: Research markdown files found at root"
    ERRORS=$((ERRORS + 1))
fi

# Check for build artifacts
if [ -d "TestResults.xcresult" ]; then
    echo "ERROR: Test results artifact found at root (add to .gitignore)"
    ERRORS=$((ERRORS + 1))
fi

# Check for dated test targets (indicates incomplete merge)
if ls -d breakdexUITests-* 1> /dev/null 2>&1; then
    echo "ERROR: Dated test target folder found (merge tests and remove)"
    ERRORS=$((ERRORS + 1))
fi

# Check Info.plist is only in breakdex/, not at root
if [ -f "Info.plist" ]; then
    echo "ERROR: Info.plist found at root (should only be in breakdex/)"
    ERRORS=$((ERRORS + 1))
fi

# Check for nested .git directories
if [ -d "breakdex/.git" ]; then
    echo "ERROR: Nested .git directory in breakdex/"
    ERRORS=$((ERRORS + 1))
fi

# Summary
echo ""
if [ $ERRORS -eq 0 ]; then
    echo "Project structure is valid."
    exit 0
else
    echo "Found $ERRORS structure issue(s). Please fix before committing."
    exit 1
fi
