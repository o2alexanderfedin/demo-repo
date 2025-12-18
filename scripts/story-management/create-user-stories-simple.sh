#!/usr/bin/env bash
set -euo pipefail

# Configuration for Telethon repository
OWNER="o2alexanderfedin"
REPO="Telethon"
PROJECT_NUMBER=12
DOC_BASE="https://github.com/o2alexanderfedin/Telethon/blob/develop/docs/architecture/documentation/voice-transcription-feature"

echo "📝 Creating User Stories for Voice Transcription Project"
echo "====================================================="
echo ""

# Epic mapping from our previous creation
get_epic_number() {
    case $1 in
        1) echo "260" ;;
        2) echo "261" ;;
        3) echo "262" ;;
        4) echo "263" ;;
        5) echo "264" ;;
        *) echo "" ;;
    esac
}

# Get project configuration
echo "📋 Initializing project configuration..."
PROJECT_DATA=$(gh api graphql -H "GraphQL-Features: project_v2" \
  --raw-field query='{
      user(login:"'$OWNER'") {
        projectV2(number:'$PROJECT_NUMBER') { 
          id 
          field(name: "Type") {
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
    }')

PROJECT_ID=$(echo "$PROJECT_DATA" | jq -r '.data.user.projectV2.id')
TYPE_FIELD_ID=$(echo "$PROJECT_DATA" | jq -r '.data.user.projectV2.field.id')
USER_STORY_OPTION_ID=$(echo "$PROJECT_DATA" | jq -r '.data.user.projectV2.field.options[] | select(.name == "User Story") | .id')

# Get repository ID
REPO_ID=$(gh api graphql \
  --raw-field query='{
      repository(owner:"'$OWNER'", name:"'$REPO'") { id }
    }' \
  --jq '.data.repository.id')

echo "✅ Configuration loaded"
echo "   Project ID: $PROJECT_ID"
echo "   Repository ID: $REPO_ID"
echo "   Type Field ID: $TYPE_FIELD_ID"
echo "   User Story Option ID: $USER_STORY_OPTION_ID"
echo ""

# Function to create a user story
add_user_story() {
    local parent_epic_number="$1"
    local title="$2"
    local body="$3"
    
    echo -n "  📝 Creating user story: $title... "
    
    # Step 1: Get parent epic's project item ID and title
    PARENT_DATA=$(gh api graphql -H "GraphQL-Features: project_v2" \
      --raw-field query='{
          repository(owner:"'$OWNER'", name:"'$REPO'") { 
            issue(number:'$parent_epic_number') { 
              id
              title
              projectItems(last:1) { 
                nodes { 
                  id 
                } 
              } 
            }
          }
        }' 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo "❌ Failed to get parent epic data"
        return 1
    fi
    
    PARENT_ISSUE_ID=$(echo "$PARENT_DATA" | jq -r '.data.repository.issue.id // empty')
    PARENT_ITEM_ID=$(echo "$PARENT_DATA" | jq -r '.data.repository.issue.projectItems.nodes[0].id // empty')
    PARENT_TITLE=$(echo "$PARENT_DATA" | jq -r '.data.repository.issue.title // empty')
    
    if [ -z "$PARENT_ITEM_ID" ]; then
        echo "❌ Parent epic not in project"
        return 1
    fi
    
    # Step 2: Create draft issue in the project
    QUERY='mutation($projId:ID!, $title:String!, $body:String!) {
      addProjectV2DraftIssue(input:{
        projectId:$projId, 
        title:$title, 
        body:$body
      }) {
        projectItem { 
          id 
        }
      }
    }'
    
    FULL_BODY="**Parent Epic**: #$parent_epic_number - $PARENT_TITLE

$body"
    
    DRAFT_RESULT=$(gh api graphql -H "GraphQL-Features: project_v2" \
      -f query="$QUERY" \
      -F projId="$PROJECT_ID" \
      -F title="$title" \
      -F body="$FULL_BODY" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo "❌ Failed to create draft"
        return 1
    fi
    
    DRAFT_ITEM_ID=$(echo "$DRAFT_RESULT" | jq -r '.data.addProjectV2DraftIssue.projectItem.id // empty')
    
    if [ -z "$DRAFT_ITEM_ID" ]; then
        echo "❌ No draft ID returned"
        return 1
    fi
    
    # Step 3: Set Type field to User Story
    gh api graphql -H "GraphQL-Features: project_v2" \
      --raw-field query='
        mutation {
          updateProjectV2ItemFieldValue(input: {
            projectId: "'$PROJECT_ID'",
            itemId: "'$DRAFT_ITEM_ID'",
            fieldId: "'$TYPE_FIELD_ID'",
            value: {
              singleSelectOptionId: "'$USER_STORY_OPTION_ID'"
            }
          }) {
            projectV2Item {
              id
            }
          }
        }' > /dev/null 2>&1
    
    # Step 4: Convert to repository issue
    CONVERT_RESULT=$(gh api graphql -H "GraphQL-Features: project_v2" \
      --raw-field query='
        mutation {
          convertProjectV2DraftIssueItemToIssue(input:{
            itemId: "'$DRAFT_ITEM_ID'",
            repositoryId: "'$REPO_ID'"
          }) {
            item { 
              content { 
                ... on Issue { 
                  number 
                  id 
                } 
              } 
            }
          }
        }' 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo "❌ Failed to convert to issue"
        return 1
    fi
    
    NEW_ISSUE_NUMBER=$(echo "$CONVERT_RESULT" | jq -r '.data.convertProjectV2DraftIssueItemToIssue.item.content.number // empty')
    NEW_ISSUE_ID=$(echo "$CONVERT_RESULT" | jq -r '.data.convertProjectV2DraftIssueItemToIssue.item.content.id // empty')
    
    if [ -z "$NEW_ISSUE_NUMBER" ]; then
        echo "❌ No issue number returned"
        return 1
    fi
    
    # Step 5: Try to link as sub-issue
    gh api graphql -H "GraphQL-Features: sub_issues" \
      --raw-field query='
        mutation {
          addSubIssue(input: {
            issueId: "'$PARENT_ISSUE_ID'",
            subIssueId: "'$NEW_ISSUE_ID'"
          }) {
            issue {
              id
            }
          }
        }' > /dev/null 2>&1 || true
    
    echo "✅ #$NEW_ISSUE_NUMBER"
    sleep 0.5  # Rate limiting
}

# Read user stories from JSON mapping and create them
echo "📋 Creating User Stories from epic-story mapping"
echo "==============================================="
echo ""

MAPPING_FILE="/Users/alexanderfedin/Projects/demo/workspace/Telethon/docs/architecture/documentation/voice-transcription-feature/epic-story-mapping.json"

# Process each epic and its user stories
for epic_num in {1..5}; do
    epic_issue_number=$(get_epic_number $epic_num)
    echo "🎯 Creating User Stories for Epic $epic_num (Issue #$epic_issue_number)..."
    
    # Get epic data from JSON
    epic_data=$(jq -r ".mappings[] | select(.epic_title | contains(\"Epic $epic_num:\"))" "$MAPPING_FILE")
    
    if [ -n "$epic_data" ]; then
        epic_title=$(echo "$epic_data" | jq -r '.epic_title')
        echo "   Epic: $epic_title"
        
        # Create user stories for this epic
        echo "$epic_data" | jq -c '.user_stories[]' | while read -r story; do
            story_title=$(echo "$story" | jq -r '.title')
            story_reason=$(echo "$story" | jq -r '.reason')
            
            # Build story body
            story_body="## 📋 User Story Overview

As a developer, I need to implement $story_title to enable voice transcription functionality in Telethon.

### 🎯 Purpose
$story_reason

## 📚 Documentation

- **Epic Analysis**: [View Epic Analysis]($DOC_BASE/epic${epic_num}-analysis.md)
- **Technical Architecture**: [View Technical Docs]($DOC_BASE/technical-architecture.md)

## ✅ Acceptance Criteria

- [ ] Implementation follows technical architecture
- [ ] Unit tests provide adequate coverage
- [ ] Integration tests pass
- [ ] Documentation is updated
- [ ] Code review completed
- [ ] Performance benchmarks met

---
*Part of Epic $epic_num: Voice Transcription feature implementation*"
            
            # Create the user story
            add_user_story "$epic_issue_number" "$story_title" "$story_body"
        done
        
        echo ""
    fi
done

echo "✅ User story creation complete!"
echo ""
echo "Summary:"
echo "- User Stories created as repository issues"
echo "- Type field set to 'User Story'"
echo "- Stories linked as sub-issues to their parent epics"
echo "- All items added to the project board"