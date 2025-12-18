#!/bin/bash

# install-no-issues-mode.sh
# Installs permanent protection against gh issue commands
# Usage: ./install-no-issues-mode.sh

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Detect shell configuration file
SHELL_CONFIG=""
if [ -n "$BASH_VERSION" ]; then
    if [ -f "$HOME/.bashrc" ]; then
        SHELL_CONFIG="$HOME/.bashrc"
    elif [ -f "$HOME/.bash_profile" ]; then
        SHELL_CONFIG="$HOME/.bash_profile"
    fi
elif [ -n "$ZSH_VERSION" ]; then
    SHELL_CONFIG="$HOME/.zshrc"
fi

if [ -z "$SHELL_CONFIG" ]; then
    echo -e "${RED}❌ Could not detect shell configuration file${NC}"
    echo "Please add the protection manually to your shell config"
    exit 1
fi

echo -e "${BLUE}Installing No-Issues Mode to $SHELL_CONFIG${NC}"

# Check if already installed
if grep -q "NO_GITHUB_ISSUES_MODE" "$SHELL_CONFIG" 2>/dev/null; then
    echo -e "${YELLOW}⚠️  No-Issues Mode is already installed${NC}"
    echo "To remove it, delete the NO_GITHUB_ISSUES_MODE section from $SHELL_CONFIG"
    exit 0
fi

# Create the protection code
cat >> "$SHELL_CONFIG" << 'EOF'

# NO_GITHUB_ISSUES_MODE - Prevent usage of gh issue commands
# To disable temporarily: unset -f gh
# To disable permanently: Remove this section
if command -v gh &> /dev/null; then
    gh() {
        if [ "$1" = "issue" ]; then
            echo -e "\033[0;31m❌ ERROR: Repository issues are disabled!\033[0m" >&2
            echo -e "\033[1;33mThis environment uses project draft items only.\033[0m" >&2
            echo "" >&2
            echo "Alternatives:" >&2
            echo "  • Use GitHub Projects with draft items" >&2
            echo "  • gh project item-create" >&2
            echo "  • Create draft items via the web interface" >&2
            return 1
        else
            command gh "$@"
        fi
    }
fi
EOF

echo -e "${GREEN}✅ No-Issues Mode installed successfully!${NC}"
echo ""
echo "The protection will be active in new shell sessions."
echo "To activate in current session, run:"
echo -e "${YELLOW}source $SHELL_CONFIG${NC}"
echo ""
echo "To disable temporarily: unset -f gh"
echo "To disable permanently: Remove the NO_GITHUB_ISSUES_MODE section from $SHELL_CONFIG"