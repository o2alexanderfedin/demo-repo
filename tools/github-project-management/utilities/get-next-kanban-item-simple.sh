#!/bin/bash

# Simplified version of get-next-kanban-item.sh that actually works
# This version uses simpler queries and project item-list command

set -euo pipefail

# Configuration
PROJECT_OWNER="o2alexanderfedin"
PROJECT_NUMBER=12
MAX_WIP=3

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# First check for open PRs
echo -e "${PURPLE}🔍 Checking for open pull requests...${NC}"

# Get current user
CURRENT_USER=$(gh api user --jq '.login')

# Check for open PRs authored by current user
PR_COUNT=$(gh pr list --author "$CURRENT_USER" --state open --json number | jq 'length')

if [ "$PR_COUNT" -gt 0 ]; then
    echo -e "\n${RED}❌ You have $PR_COUNT open pull request(s) that need attention:${NC}"
    gh pr list --author "$CURRENT_USER" --state open
    echo -e "\n${YELLOW}⚠️  WORKFLOW RULE: Review and complete PRs before starting new work${NC}"
    exit 1
fi

echo -e "\n${BLUE}Fetching project items...${NC}"

# Get all items from the project
ITEMS_JSON=$(gh project item-list "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --format json --limit 100)

# Count items in progress
IN_PROGRESS_COUNT=$(echo "$ITEMS_JSON" | jq -r '.items[] | select(.status == "In Progress")' | jq -s 'length')

echo -e "Current WIP: ${YELLOW}$IN_PROGRESS_COUNT${NC} / $MAX_WIP"

if [ "$IN_PROGRESS_COUNT" -ge "$MAX_WIP" ]; then
    echo -e "${RED}❌ WIP limit reached! Complete current work before pulling new items.${NC}"
    exit 1
fi

echo -e "\n${BLUE}Finding next available work item...${NC}"

# Find User Story items that have no status or Todo status
NEXT_ITEM=$(echo "$ITEMS_JSON" | jq -r '
  .items[] | 
  select(
    .type == "User Story" and 
    (.status == null or .status == "" or .status == "Todo")
  ) | 
  {
    number: .content.number,
    title: .title,
    url: .content.url
  }' | jq -s 'if length > 0 then .[0] else null end')

if [ "$NEXT_ITEM" = "null" ] || [ -z "$NEXT_ITEM" ]; then
    echo -e "${YELLOW}No available User Story items found.${NC}"
    
    # Show some stats
    echo -e "\n${BLUE}Project Statistics:${NC}"
    echo "$ITEMS_JSON" | jq -r '.items[] | .type' | sort | uniq -c | while read count type; do
        echo -e "  $type: $count items"
    done
    
    echo -e "\n${BLUE}Status Distribution:${NC}"
    echo "$ITEMS_JSON" | jq -r '.items[] | .status // "No Status"' | sort | uniq -c | while read count status; do
        echo -e "  $status: $count items"
    done
    
    exit 0
fi

# Extract item details
ITEM_NUMBER=$(echo "$NEXT_ITEM" | jq -r '.number')
ITEM_TITLE=$(echo "$NEXT_ITEM" | jq -r '.title')
ITEM_URL=$(echo "$NEXT_ITEM" | jq -r '.url')

echo -e "\n${GREEN}✅ Found next work item:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}#$ITEM_NUMBER: $ITEM_TITLE${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "URL: $ITEM_URL"

# Show issue details
echo -e "\n${BLUE}Issue Details:${NC}"
gh issue view "$ITEM_NUMBER" --repo "$PROJECT_OWNER/telethon-architecture-docs" | head -20

# If --auto-assign flag is provided, create feature branch and update task
if [ "${1:-}" = "--auto-assign" ]; then
    echo -e "\n${YELLOW}Auto-assigning task...${NC}"
    
    # Create feature branch name from title
    FEATURE_NAME=$(echo "$ITEM_TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//')
    
    echo -e "Creating feature branch: ${GREEN}feature/$FEATURE_NAME${NC}"
    
    # Save task info
    echo "$ITEM_NUMBER" > .claude/current-task.txt
    echo "Task #$ITEM_NUMBER: $ITEM_TITLE" > ".claude/feature-task-$ITEM_NUMBER.env"
    
    # Start GitFlow feature
    git flow feature start "$FEATURE_NAME"
    
    echo -e "\n${GREEN}✅ Task assigned and feature branch created!${NC}"
    echo -e "You are now working on: ${BLUE}#$ITEM_NUMBER - $ITEM_TITLE${NC}"
else
    echo -e "\n${YELLOW}To assign this task and start working:${NC}"
    echo -e "  ${GREEN}$0 --auto-assign${NC}"
fi