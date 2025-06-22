#!/bin/bash

# Simplified update-task-status.sh that works with gh project commands
# Usage: ./update-task-status-simple.sh <issue-number> <status>

set -euo pipefail

# Arguments
ISSUE_NUMBER=$1
NEW_STATUS=$2

# Configuration
PROJECT_OWNER="o2alexanderfedin"
PROJECT_NUMBER=12
REPO="telethon-architecture-docs"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Updating task #$ISSUE_NUMBER to status: $NEW_STATUS${NC}"

# Get the project item ID for this issue
echo -e "${BLUE}Finding project item...${NC}"
ITEM_ID=$(gh project item-list "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --format json | \
  jq -r --arg num "$ISSUE_NUMBER" '.items[] | select(.content.number == ($num | tonumber)) | .id')

if [ -z "$ITEM_ID" ] || [ "$ITEM_ID" = "null" ]; then
    echo -e "${RED}Error: Could not find project item for issue #$ISSUE_NUMBER${NC}"
    exit 1
fi

echo -e "${BLUE}Found project item: $ITEM_ID${NC}"

# Update the status using gh project item-edit
echo -e "${BLUE}Updating status...${NC}"
gh project item-edit --project-id "$PROJECT_NUMBER" --id "$ITEM_ID" --field-id "Status" --single-select-option-id "$NEW_STATUS" --owner "$PROJECT_OWNER" || {
    # If that fails, try with the status name directly
    echo -e "${YELLOW}Trying alternative method...${NC}"
    
    # Get project ID using simple query
    PROJECT_ID=$(gh api graphql -f query="{
      user(login: \"$PROJECT_OWNER\") {
        projectV2(number: $PROJECT_NUMBER) {
          id
        }
      }
    }" --jq '.data.user.projectV2.id')
    
    # Get field ID and option ID
    FIELD_DATA=$(gh api graphql -f query="{
      node(id: \"$PROJECT_ID\") {
        ... on ProjectV2 {
          field(name: \"Status\") {
            ... on ProjectV2SingleSelectField {
              id
              options {
                id
                name
              }
            }
          }
        }
      }
    }" --jq '.data.node.field')
    
    FIELD_ID=$(echo "$FIELD_DATA" | jq -r '.id')
    OPTION_ID=$(echo "$FIELD_DATA" | jq -r --arg status "$NEW_STATUS" '.options[] | select(.name == $status) | .id')
    
    if [ -z "$OPTION_ID" ] || [ "$OPTION_ID" = "null" ]; then
        echo -e "${RED}Error: Status '$NEW_STATUS' not found in project${NC}"
        exit 1
    fi
    
    # Update using GraphQL
    gh api graphql -f query="
      mutation {
        updateProjectV2ItemFieldValue(input: {
          projectId: \"$PROJECT_ID\"
          itemId: \"$ITEM_ID\"
          fieldId: \"$FIELD_ID\"
          value: {
            singleSelectOptionId: \"$OPTION_ID\"
          }
        }) {
          projectV2Item {
            id
          }
        }
      }"
}

echo -e "${GREEN}✅ Task #$ISSUE_NUMBER status updated to: $NEW_STATUS${NC}"

# If updating to "In Progress", show relevant architecture docs
if [ "$NEW_STATUS" = "In Progress" ]; then
    echo -e "\n${BLUE}📚 Starting work on task #$ISSUE_NUMBER${NC}"
    
    # Try to show architecture guidance if the script exists
    if [ -f "./tools/github-project-management/utilities/show-architecture-guidance.sh" ]; then
        ./tools/github-project-management/utilities/show-architecture-guidance.sh "$ISSUE_NUMBER" || true
    fi
fi

# If updating to "Done", add completion comment
if [ "$NEW_STATUS" = "Done" ]; then
    echo -e "\n${BLUE}📝 Adding completion report...${NC}"
    
    # Get feature branch info if available
    FEATURE_BRANCH=$(git branch --show-current)
    if [[ "$FEATURE_BRANCH" =~ ^feature/ ]]; then
        FEATURE_NAME=${FEATURE_BRANCH#feature/}
        
        # Add completion comment
        COMPLETION_REPORT="## 🎉 Task Completed

### Summary
Feature branch: \`$FEATURE_BRANCH\`
Status: **Done**

This task has been completed and the feature implementation is ready for review.

---
*Updated by automated workflow*"
        
        gh issue comment "$ISSUE_NUMBER" --repo "$PROJECT_OWNER/$REPO" --body "$COMPLETION_REPORT" || true
    fi
fi