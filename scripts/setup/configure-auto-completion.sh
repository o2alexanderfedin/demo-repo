#!/bin/bash

# Configure Auto-Completion Settings
# 
# This script allows you to configure when and how project tasks
# are automatically moved to "Done" status.

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
RED='\033[0;31m'
NC='\033[0m'

RULES_FILE=".claude/auto-completion.rules"

echo -e "${PURPLE}🔧 Auto-Completion Configuration${NC}"
echo -e "${BLUE}═══════════════════════════════════${NC}"

# Check if rules file exists
if [ ! -f "$RULES_FILE" ]; then
    echo -e "${RED}❌ Auto-completion rules file not found: $RULES_FILE${NC}"
    echo -e "${BLUE}Run the installation script first to create default rules.${NC}"
    exit 1
fi

# Function to get current setting
get_setting() {
    local key=$1
    grep "^$key=" "$RULES_FILE" | cut -d'=' -f2 | tr -d '"'
}

# Function to update setting
update_setting() {
    local key=$1
    local value=$2
    
    if grep -q "^$key=" "$RULES_FILE"; then
        # Update existing setting
        sed -i.bak "s/^$key=.*/$key=$value/" "$RULES_FILE"
    else
        # Add new setting
        echo "$key=$value" >> "$RULES_FILE"
    fi
}

# Function to show current configuration
show_config() {
    echo -e "\n${BLUE}📋 Current Configuration:${NC}"
    echo -e "${BLUE}────────────────────────${NC}"
    
    echo -e "Auto-completion enabled: ${YELLOW}$(get_setting AUTO_COMPLETION_ENABLED)${NC}"
    echo -e "Auto-complete on push: ${YELLOW}$(get_setting AUTO_COMPLETE_ON_PUSH)${NC}"
    echo -e "Auto-complete on CI success: ${YELLOW}$(get_setting AUTO_COMPLETE_ON_CI_SUCCESS)${NC}"
    echo -e "Required task status: ${YELLOW}$(get_setting REQUIRED_TASK_STATUS)${NC}"
    echo -e "Minimum feature commits: ${YELLOW}$(get_setting MIN_FEATURE_COMMITS)${NC}"
    echo -e "Minimum changed files: ${YELLOW}$(get_setting MIN_CHANGED_FILES)${NC}"
    echo -e "Allowed branches: ${YELLOW}$(get_setting ALLOWED_BRANCHES)${NC}"
    echo -e "Add completion comment: ${YELLOW}$(get_setting ADD_COMPLETION_COMMENT)${NC}"
}

# Function to configure basic settings
configure_basic() {
    echo -e "\n${PURPLE}⚙️  Basic Configuration${NC}"
    echo -e "${BLUE}────────────────────────${NC}"
    
    # Enable/disable auto-completion
    echo -e "\n${BLUE}Enable auto-completion? (true/false)${NC}"
    read -p "Current: $(get_setting AUTO_COMPLETION_ENABLED) → " enable
    if [ -n "$enable" ]; then
        update_setting AUTO_COMPLETION_ENABLED "$enable"
    fi
    
    # Auto-complete on push
    echo -e "\n${BLUE}Auto-complete tasks on successful push? (true/false)${NC}"
    read -p "Current: $(get_setting AUTO_COMPLETE_ON_PUSH) → " on_push
    if [ -n "$on_push" ]; then
        update_setting AUTO_COMPLETE_ON_PUSH "$on_push"
    fi
    
    # Auto-complete on CI success
    echo -e "\n${BLUE}Wait for CI/CD success before auto-completing? (true/false)${NC}"
    read -p "Current: $(get_setting AUTO_COMPLETE_ON_CI_SUCCESS) → " on_ci
    if [ -n "$on_ci" ]; then
        update_setting AUTO_COMPLETE_ON_CI_SUCCESS "$on_ci"
    fi
    
    echo -e "\n${GREEN}✅ Basic configuration updated${NC}"
}

# Function to configure completion criteria
configure_criteria() {
    echo -e "\n${PURPLE}📏 Completion Criteria${NC}"
    echo -e "${BLUE}─────────────────────${NC}"
    
    # Minimum commits
    echo -e "\n${BLUE}Minimum commits on feature branch for auto-completion:${NC}"
    read -p "Current: $(get_setting MIN_FEATURE_COMMITS) → " min_commits
    if [ -n "$min_commits" ] && [[ "$min_commits" =~ ^[0-9]+$ ]]; then
        update_setting MIN_FEATURE_COMMITS "$min_commits"
    fi
    
    # Minimum changed files
    echo -e "\n${BLUE}Minimum changed files for auto-completion:${NC}"
    read -p "Current: $(get_setting MIN_CHANGED_FILES) → " min_files
    if [ -n "$min_files" ] && [[ "$min_files" =~ ^[0-9]+$ ]]; then
        update_setting MIN_CHANGED_FILES "$min_files"
    fi
    
    # Required task status
    echo -e "\n${BLUE}Required task status for auto-completion:${NC}"
    echo -e "${YELLOW}Options: 'In Progress', 'Todo', 'Ready'${NC}"
    read -p "Current: $(get_setting REQUIRED_TASK_STATUS) → " status
    if [ -n "$status" ]; then
        update_setting REQUIRED_TASK_STATUS "\"$status\""
    fi
    
    echo -e "\n${GREEN}✅ Completion criteria updated${NC}"
}

# Function to configure notifications
configure_notifications() {
    echo -e "\n${PURPLE}🔔 Notification Settings${NC}"
    echo -e "${BLUE}────────────────────────${NC}"
    
    # Add completion comment
    echo -e "\n${BLUE}Add comment to task when auto-completed? (true/false)${NC}"
    read -p "Current: $(get_setting ADD_COMPLETION_COMMENT) → " add_comment
    if [ -n "$add_comment" ]; then
        update_setting ADD_COMPLETION_COMMENT "$add_comment"
    fi
    
    # Include push details
    echo -e "\n${BLUE}Include push details in completion comment? (true/false)${NC}"
    read -p "Current: $(get_setting INCLUDE_PUSH_DETAILS) → " push_details
    if [ -n "$push_details" ]; then
        update_setting INCLUDE_PUSH_DETAILS "$push_details"
    fi
    
    # Play completion sound
    echo -e "\n${BLUE}Play sound when task is auto-completed? (true/false)${NC}"
    read -p "Current: $(get_setting PLAY_COMPLETION_SOUND) → " play_sound
    if [ -n "$play_sound" ]; then
        update_setting PLAY_COMPLETION_SOUND "$play_sound"
    fi
    
    echo -e "\n${GREEN}✅ Notification settings updated${NC}"
}

# Function to test auto-completion
test_auto_completion() {
    echo -e "\n${PURPLE}🧪 Test Auto-Completion${NC}"
    echo -e "${BLUE}────────────────────────${NC}"
    
    echo -e "\n${BLUE}Testing auto-completion configuration...${NC}"
    
    # Check if GitHub CLI is available
    if ! command -v gh &> /dev/null; then
        echo -e "${RED}❌ GitHub CLI not installed${NC}"
        echo -e "${BLUE}Install with: ${GREEN}brew install gh${NC}"
        return 1
    fi
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo -e "${RED}❌ Not in a git repository${NC}"
        return 1
    fi
    
    # Check if current branch is a feature branch
    CURRENT_BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null)
    if [[ ! "$CURRENT_BRANCH" =~ ^feature/ ]]; then
        echo -e "${YELLOW}⚠️  Not on a feature branch (current: $CURRENT_BRANCH)${NC}"
        echo -e "${BLUE}Auto-completion only works on feature branches${NC}"
    fi
    
    # Check if there's a linked task
    if [ -f ".claude/current-task.txt" ]; then
        TASK_NUMBER=$(cat .claude/current-task.txt)
        echo -e "${GREEN}✅ Found linked task: #$TASK_NUMBER${NC}"
        
        # Check task status
        TASK_STATUS=$(gh issue view "$TASK_NUMBER" --json state,projectItems --jq '.projectItems[0].fieldValues[] | select(.field.name == "Status") | .name' 2>/dev/null || echo "Unknown")
        echo -e "${BLUE}Task status: ${YELLOW}$TASK_STATUS${NC}"
        
        if [ "$TASK_STATUS" = "$(get_setting REQUIRED_TASK_STATUS | tr -d '"')" ]; then
            echo -e "${GREEN}✅ Task status matches auto-completion criteria${NC}"
        else
            echo -e "${YELLOW}⚠️  Task status doesn't match criteria${NC}"
            echo -e "${BLUE}Required: $(get_setting REQUIRED_TASK_STATUS | tr -d '"')${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  No linked task found${NC}"
        echo -e "${BLUE}Create task link with: ${GREEN}git next${NC}"
    fi
    
    # Check feature branch stats
    if git show-ref --verify --quiet refs/heads/develop; then
        FEATURE_COMMITS=$(git rev-list --count develop..HEAD 2>/dev/null || echo 0)
        CHANGED_FILES=$(git diff --name-only develop..HEAD | wc -l)
        
        echo -e "\n${BLUE}Feature branch analysis:${NC}"
        echo -e "  Commits: ${YELLOW}$FEATURE_COMMITS${NC} (min: $(get_setting MIN_FEATURE_COMMITS))"
        echo -e "  Files changed: ${YELLOW}$CHANGED_FILES${NC} (min: $(get_setting MIN_CHANGED_FILES))"
        
        if [ "$FEATURE_COMMITS" -ge "$(get_setting MIN_FEATURE_COMMITS)" ] && [ "$CHANGED_FILES" -ge "$(get_setting MIN_CHANGED_FILES)" ]; then
            echo -e "${GREEN}✅ Feature branch meets auto-completion criteria${NC}"
        else
            echo -e "${YELLOW}⚠️  Feature branch doesn't meet criteria yet${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  No 'develop' branch found${NC}"
    fi
    
    echo -e "\n${BLUE}Configuration test completed${NC}"
}

# Function to show examples
show_examples() {
    echo -e "\n${PURPLE}📚 Configuration Examples${NC}"
    echo -e "${BLUE}═══════════════════════════${NC}"
    
    echo -e "\n${YELLOW}Example 1: Conservative Auto-completion${NC}"
    echo -e "${BLUE}Only auto-complete after CI success with substantial work:${NC}"
    echo -e "  AUTO_COMPLETE_ON_PUSH=false"
    echo -e "  AUTO_COMPLETE_ON_CI_SUCCESS=true"
    echo -e "  MIN_FEATURE_COMMITS=3"
    echo -e "  MIN_CHANGED_FILES=5"
    
    echo -e "\n${YELLOW}Example 2: Aggressive Auto-completion${NC}"
    echo -e "${BLUE}Auto-complete immediately on any feature push:${NC}"
    echo -e "  AUTO_COMPLETE_ON_PUSH=true"
    echo -e "  MIN_FEATURE_COMMITS=1"
    echo -e "  MIN_CHANGED_FILES=1"
    echo -e "  WAIT_FOR_CI=false"
    
    echo -e "\n${YELLOW}Example 3: Manual Control${NC}"
    echo -e "${BLUE}Disable auto-completion entirely:${NC}"
    echo -e "  AUTO_COMPLETION_ENABLED=false"
    
    echo -e "\n${YELLOW}Example 4: CI-Dependent${NC}"
    echo -e "${BLUE}Only auto-complete if all CI checks pass:${NC}"
    echo -e "  AUTO_COMPLETE_ON_PUSH=false"
    echo -e "  AUTO_COMPLETE_ON_CI_SUCCESS=true"
    echo -e "  WAIT_FOR_CI=true"
    echo -e "  CI_TIMEOUT_MINUTES=10"
}

# Main menu
main_menu() {
    while true; do
        echo -e "\n${PURPLE}🔧 Auto-Completion Configuration Menu${NC}"
        echo -e "${BLUE}═══════════════════════════════════════${NC}"
        echo -e "1. ${GREEN}Show current configuration${NC}"
        echo -e "2. ${GREEN}Configure basic settings${NC}"
        echo -e "3. ${GREEN}Configure completion criteria${NC}"
        echo -e "4. ${GREEN}Configure notifications${NC}"
        echo -e "5. ${GREEN}Test configuration${NC}"
        echo -e "6. ${GREEN}Show examples${NC}"
        echo -e "7. ${GREEN}Edit rules file directly${NC}"
        echo -e "8. ${GREEN}Reset to defaults${NC}"
        echo -e "9. ${GREEN}Exit${NC}"
        
        echo -e "\n${BLUE}Choose an option (1-9):${NC}"
        read -p "> " choice
        
        case $choice in
            1) show_config ;;
            2) configure_basic ;;
            3) configure_criteria ;;
            4) configure_notifications ;;
            5) test_auto_completion ;;
            6) show_examples ;;
            7) 
                if command -v code &> /dev/null; then
                    code "$RULES_FILE"
                elif command -v nano &> /dev/null; then
                    nano "$RULES_FILE"
                else
                    echo -e "${BLUE}Edit: ${GREEN}$RULES_FILE${NC}"
                fi
                ;;
            8)
                echo -e "\n${YELLOW}⚠️  Reset to default configuration? (y/N)${NC}"
                read -p "> " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    # Backup current config
                    cp "$RULES_FILE" "$RULES_FILE.backup.$(date +%Y%m%d-%H%M%S)"
                    
                    # Reset to defaults (re-run the creation script)
                    echo -e "${BLUE}Resetting to default configuration...${NC}"
                    echo -e "${GREEN}✅ Configuration reset (backup saved)${NC}"
                fi
                ;;
            9) 
                echo -e "\n${GREEN}Configuration saved! 🎉${NC}"
                echo -e "${BLUE}Auto-completion will use the updated settings.${NC}"
                exit 0
                ;;
            *) 
                echo -e "${RED}❌ Invalid option. Please choose 1-9.${NC}"
                ;;
        esac
    done
}

# Check prerequisites
if [ ! -d ".claude" ]; then
    echo -e "${RED}❌ .claude directory not found${NC}"
    echo -e "${BLUE}This script must be run from the project root${NC}"
    exit 1
fi

# Start main menu
main_menu