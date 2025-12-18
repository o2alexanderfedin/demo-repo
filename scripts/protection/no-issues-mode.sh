#!/bin/bash

# no-issues-mode.sh
# Source this file to block all `gh issue` commands
# Usage: source ./no-issues-mode.sh

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Override the gh command
gh() {
    # Check if the first argument is "issue"
    if [ "$1" = "issue" ]; then
        echo -e "${RED}❌ ERROR: Repository issues are disabled!${NC}" >&2
        echo -e "${YELLOW}This project uses draft items only (no repository issues).${NC}" >&2
        echo "" >&2
        echo -e "${BLUE}Use these commands instead:${NC}" >&2
        echo "  • ./scrum-project create-only <name>    - Create project with draft items" >&2
        echo "  • ./scrum-project add-items <num> <file> - Add draft items from JSON" >&2
        echo "  • gh project item-add                    - Add draft items manually" >&2
        echo "" >&2
        echo -e "${YELLOW}To disable this protection, run: unset -f gh${NC}" >&2
        return 1
    else
        # Call the real gh command for non-issue commands
        command gh "$@"
    fi
}

# Also create an alias for extra protection
alias "gh issue"='echo -e "${RED}❌ ERROR: Repository issues are disabled!${NC}\nUse project draft items instead." && false'

# Export the function so it works in subshells
export -f gh

echo -e "${BLUE}🛡️  No-Issues Mode Activated${NC}"
echo "Repository issues (gh issue) commands are now blocked."
echo "To deactivate, run: unset -f gh && unalias 'gh issue'"