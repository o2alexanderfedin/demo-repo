#!/bin/bash

# configure-scrum-items.sh
# Configures items in a Scrum project with appropriate field values
# Usage: ./configure-scrum-items.sh <project-number> [--org organization]

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Check if project number is provided
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <project-number> [--org <organization>]"
    echo ""
    echo "This script configures project items with:"
    echo "  - Type field (Epic/User Story based on labels or title)"
    echo "  - Priority (based on labels or type)"
    echo "  - Sprint Status (Todo by default)"
    echo "  - Sprint (Backlog by default)"
    echo ""
    echo "Examples:"
    echo "  $0 12"
    echo "  $0 5 --org myorg"
    exit 1
fi

PROJECT_NUMBER="$1"
OWNER_TYPE="user"
OWNER=$(gh api user --jq .login)

# Check for organization flag
if [ "$#" -ge 3 ] && [ "$2" = "--org" ]; then
    OWNER="$3"
    OWNER_TYPE="organization"
fi

echo -e "${BLUE}Configuring items in project #$PROJECT_NUMBER${NC}"
echo ""

# Function to get project info
get_project_info() {
    local query
    if [ "$OWNER_TYPE" = "organization" ]; then
        query="organization(login: \"$OWNER\")"
    else
        query="user(login: \"$OWNER\")"
    fi
    
    gh api graphql -f query="
    query {
      $query {
        projectV2(number: $PROJECT_NUMBER) {
          id
          title
          fields(first: 20) {
            nodes {
              ... on ProjectV2Field {
                id
                name
              }
              ... on ProjectV2SingleSelectField {
                id
                name
                options {
                  id
                  name
                }
              }
            }
          }
        }
      }
    }"
}

echo -n "Getting project information... "
PROJECT_INFO=$(get_project_info)
PROJECT_ID=$(echo "$PROJECT_INFO" | jq -r ".data.$OWNER_TYPE.projectV2.id")
PROJECT_TITLE=$(echo "$PROJECT_INFO" | jq -r ".data.$OWNER_TYPE.projectV2.title")

if [ -z "$PROJECT_ID" ] || [ "$PROJECT_ID" = "null" ]; then
    echo -e "${RED}❌ Failed to find project${NC}"
    exit 1
fi

echo -e "${GREEN}✅${NC}"
echo "Project: $PROJECT_TITLE"

# Extract field IDs
extract_field_id() {
    echo "$PROJECT_INFO" | jq -r ".data.$OWNER_TYPE.projectV2.fields.nodes[] | select(.name == \"$1\") | .id"
}

extract_option_id() {
    local field_name=$1
    local option_name=$2
    echo "$PROJECT_INFO" | jq -r ".data.$OWNER_TYPE.projectV2.fields.nodes[] | select(.name == \"$field_name\") | .options[] | select(.name == \"$option_name\") | .id"
}

# Get field IDs
TYPE_FIELD_ID=$(extract_field_id "Type")
PRIORITY_FIELD_ID=$(extract_field_id "Priority")
SPRINT_FIELD_ID=$(extract_field_id "Sprint")
SPRINT_STATUS_FIELD_ID=$(extract_field_id "Sprint Status")
STORY_POINTS_FIELD_ID=$(extract_field_id "Story Points")

echo "Fields found:"
[ -n "$TYPE_FIELD_ID" ] && echo "  ✓ Type"
[ -n "$PRIORITY_FIELD_ID" ] && echo "  ✓ Priority"
[ -n "$SPRINT_FIELD_ID" ] && echo "  ✓ Sprint"
[ -n "$SPRINT_STATUS_FIELD_ID" ] && echo "  ✓ Sprint Status"
[ -n "$STORY_POINTS_FIELD_ID" ] && echo "  ✓ Story Points"
echo ""

# Function to get project items
get_project_items() {
    gh api graphql --paginate -f query="
    query(\$endCursor: String) {
      node(id: \"$PROJECT_ID\") {
        ... on ProjectV2 {
          items(first: 100, after: \$endCursor) {
            pageInfo {
              hasNextPage
              endCursor
            }
            nodes {
              id
              content {
                ... on Issue {
                  number
                  title
                  labels(first: 10) {
                    nodes {
                      name
                    }
                  }
                }
                ... on PullRequest {
                  number
                  title
                  labels(first: 10) {
                    nodes {
                      name
                    }
                  }
                }
              }
            }
          }
        }
      }
    }" --jq '.data.node.items.nodes[]'
}

# Function to update item field
update_item_field() {
    local item_id=$1
    local field_id=$2
    local option_id=$3
    
    if [ -z "$field_id" ] || [ -z "$option_id" ]; then
        return 1
    fi
    
    gh api graphql -f query="
    mutation {
      updateProjectV2ItemFieldValue(input: {
        projectId: \"$PROJECT_ID\"
        itemId: \"$item_id\"
        fieldId: \"$field_id\"
        value: {
          singleSelectOptionId: \"$option_id\"
        }
      }) {
        projectV2Item {
          id
        }
      }
    }" > /dev/null 2>&1
}

# Function to determine item type from title and labels
determine_item_type() {
    local title="$1"
    local labels="$2"
    
    # Check labels first
    if echo "$labels" | grep -qi "epic"; then
        echo "Epic"
    elif echo "$labels" | grep -qi "user.story\|story"; then
        echo "User Story"
    elif echo "$labels" | grep -qi "bug"; then
        echo "Bug"
    elif echo "$labels" | grep -qi "spike"; then
        echo "Spike"
    elif echo "$labels" | grep -qi "task"; then
        echo "Task"
    # Check title patterns
    elif echo "$title" | grep -qi "^epic"; then
        echo "Epic"
    elif echo "$title" | grep -qi "^story\|^user story"; then
        echo "User Story"
    elif echo "$title" | grep -qi "^bug\|^fix"; then
        echo "Bug"
    elif echo "$title" | grep -qi "^spike\|^research"; then
        echo "Spike"
    else
        echo "Task"  # Default
    fi
}

# Function to determine priority
determine_priority() {
    local type="$1"
    local labels="$2"
    
    # Check labels first
    if echo "$labels" | grep -qi "priority.high\|p0\|critical\|urgent"; then
        echo "High"
    elif echo "$labels" | grep -qi "priority.low\|p2"; then
        echo "Low"
    elif echo "$labels" | grep -qi "priority.medium\|p1"; then
        echo "Medium"
    # Set by type
    elif [ "$type" = "Epic" ]; then
        echo "High"
    elif [ "$type" = "Bug" ]; then
        echo "High"
    else
        echo "Medium"
    fi
}

echo -e "${YELLOW}Configuring project items...${NC}"

# Process all items
CONFIGURED=0
FAILED=0

while IFS= read -r item; do
    ITEM_ID=$(echo "$item" | jq -r '.id')
    ISSUE_NUMBER=$(echo "$item" | jq -r '.content.number // empty')
    ISSUE_TITLE=$(echo "$item" | jq -r '.content.title // empty')
    LABELS=$(echo "$item" | jq -r '.content.labels.nodes[].name' 2>/dev/null | tr '\n' ' ')
    
    if [ -z "$ISSUE_NUMBER" ]; then
        continue
    fi
    
    # Determine values
    ITEM_TYPE=$(determine_item_type "$ISSUE_TITLE" "$LABELS")
    ITEM_PRIORITY=$(determine_priority "$ITEM_TYPE" "$LABELS")
    
    echo -n "Configuring #$ISSUE_NUMBER: $ITEM_TYPE/$ITEM_PRIORITY - "
    
    # Update Type field
    if [ -n "$TYPE_FIELD_ID" ]; then
        TYPE_OPTION_ID=$(extract_option_id "Type" "$ITEM_TYPE")
        update_item_field "$ITEM_ID" "$TYPE_FIELD_ID" "$TYPE_OPTION_ID"
        echo -n "Type "
    fi
    
    # Update Priority field
    if [ -n "$PRIORITY_FIELD_ID" ]; then
        PRIORITY_OPTION_ID=$(extract_option_id "Priority" "$ITEM_PRIORITY")
        update_item_field "$ITEM_ID" "$PRIORITY_FIELD_ID" "$PRIORITY_OPTION_ID"
        echo -n "Priority "
    fi
    
    # Update Sprint field (default to Backlog)
    if [ -n "$SPRINT_FIELD_ID" ]; then
        BACKLOG_ID=$(extract_option_id "Sprint" "Backlog")
        update_item_field "$ITEM_ID" "$SPRINT_FIELD_ID" "$BACKLOG_ID"
        echo -n "Sprint "
    fi
    
    # Update Sprint Status field (default to Todo)
    if [ -n "$SPRINT_STATUS_FIELD_ID" ]; then
        TODO_ID=$(extract_option_id "Sprint Status" "Todo")
        update_item_field "$ITEM_ID" "$SPRINT_STATUS_FIELD_ID" "$TODO_ID"
        echo -n "Status "
    fi
    
    # Set default story points based on type
    if [ -n "$STORY_POINTS_FIELD_ID" ]; then
        case "$ITEM_TYPE" in
            "Epic") POINTS="8" ;;
            "User Story") POINTS="3" ;;
            "Bug") POINTS="2" ;;
            "Spike") POINTS="3" ;;
            *) POINTS="1" ;;
        esac
        POINTS_ID=$(extract_option_id "Story Points" "$POINTS")
        if [ -n "$POINTS_ID" ]; then
            update_item_field "$ITEM_ID" "$STORY_POINTS_FIELD_ID" "$POINTS_ID"
            echo -n "Points($POINTS) "
        fi
    fi
    
    echo -e "${GREEN}✅${NC}"
    CONFIGURED=$((CONFIGURED + 1))
done < <(get_project_items)

# Summary
echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${GREEN}✅ CONFIGURATION COMPLETE!${NC}"
echo -e "${BLUE}=========================================${NC}"
echo -e "Items configured: ${GREEN}$CONFIGURED${NC}"
if [ $FAILED -gt 0 ]; then
    echo -e "Failed: ${RED}$FAILED${NC}"
fi
echo ""
echo "Default values applied:"
echo "  • Sprint: Backlog"
echo "  • Sprint Status: Todo"
echo "  • Type: Based on labels/title"
echo "  • Priority: Based on type/labels"
echo "  • Story Points: Based on type"
echo ""
echo -e "${PURPLE}Next steps:${NC}"
echo "1. Review and adjust field values as needed"
echo "2. Move items from Backlog to sprints"
echo "3. Refine story point estimates"
echo "4. Start your sprint planning!"
echo -e "${BLUE}=========================================${NC}"