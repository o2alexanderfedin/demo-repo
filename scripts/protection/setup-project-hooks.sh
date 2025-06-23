#!/bin/bash

# setup-project-hooks.sh
# Sets up git hooks to prevent gh issue commands in a specific project
# Usage: ./setup-project-hooks.sh

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}❌ Not in a git repository${NC}"
    echo "Run this script from the root of your project"
    exit 1
fi

GIT_DIR=$(git rev-parse --git-dir)
HOOKS_DIR="$GIT_DIR/hooks"

echo -e "${BLUE}Setting up project hooks to block 'gh issue' commands${NC}"

# Create hooks directory if it doesn't exist
mkdir -p "$HOOKS_DIR"

# Create a pre-commit hook
cat > "$HOOKS_DIR/pre-commit" << 'EOF'
#!/bin/bash
# Pre-commit hook to check for gh issue commands in scripts

# Check if any staged files contain "gh issue" commands
if git diff --cached --name-only | xargs grep -l "gh issue" 2>/dev/null; then
    echo "❌ ERROR: Found 'gh issue' commands in staged files!"
    echo ""
    echo "This project uses GitHub Projects with draft items only."
    echo "Repository issues are not allowed."
    echo ""
    echo "Files containing 'gh issue':"
    git diff --cached --name-only | xargs grep -l "gh issue" 2>/dev/null | sed 's/^/  - /'
    echo ""
    echo "Please replace with project-only alternatives:"
    echo "  • Use 'gh project item-create' for draft items"
    echo "  • Use GraphQL API for project operations"
    echo ""
    echo "To bypass this check (not recommended):"
    echo "  git commit --no-verify"
    exit 1
fi

exit 0
EOF

chmod +x "$HOOKS_DIR/pre-commit"

# Create a wrapper script in the project
cat > ".git-hooks-no-issues" << 'EOF'
#!/bin/bash
# This file indicates that this project uses draft items only
# Repository issues (gh issue) are not allowed

# Function to check commands before execution
check_gh_issue() {
    if [[ "$*" == *"gh issue"* ]]; then
        echo "❌ ERROR: 'gh issue' commands are not allowed in this project!"
        echo "Use GitHub Projects with draft items instead."
        return 1
    fi
    return 0
}

# Export for use in scripts
export -f check_gh_issue
EOF

# Create a .gitmessage template
cat > "$GIT_DIR/no-issues-commit-template" << 'EOF'
# Remember: This project uses draft items only (no repository issues)
# 
# Good: "Add draft item creation for user stories"
# Bad:  "Create GitHub issue for bug tracking"
#
# Project-only commands:
# - gh project item-create
# - gh api graphql (with addProjectV2DraftIssue)
EOF

# Configure git to use the commit template
git config --local commit.template "$GIT_DIR/no-issues-commit-template"

echo -e "${GREEN}✅ Project hooks installed successfully!${NC}"
echo ""
echo "Protection enabled:"
echo "  • Pre-commit hook blocks commits containing 'gh issue'"
echo "  • Commit template reminds about draft-items-only policy"
echo ""
echo "To remove these protections:"
echo "  rm $HOOKS_DIR/pre-commit"
echo "  git config --local --unset commit.template"