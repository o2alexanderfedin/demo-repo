#!/usr/bin/env bash
set -euo pipefail

# Script to create user stories and link them to existing epics
# Uses the same algorithm as add_task

# Configuration
OWNER="o2alexanderfedin"
REPO="telethon-architecture-docs"
PROJECT_NUMBER=12
DOC_BASE="https://github.com/o2alexanderfedin/telethon-architecture-docs/blob/main/documentation/voice-transcription-feature"

echo "🔧 Creating User Stories for Voice Transcription Project"
echo "====================================================="
echo ""

# Get project configuration
echo "📋 Initializing project configuration..."
PROJECT_DATA=$(gh api graphql -H "GraphQL-Features: project_v2" \
  -f query='
    query($owner:String!, $projNum:Int!) {
      user(login:$owner) {
        projectV2(number:$projNum) { 
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
    }' \
  -F owner="$OWNER" \
  -F projNum="$PROJECT_NUMBER")

PROJECT_ID=$(echo "$PROJECT_DATA" | jq -r '.data.user.projectV2.id')
TYPE_FIELD_ID=$(echo "$PROJECT_DATA" | jq -r '.data.user.projectV2.field.id')
USER_STORY_OPTION_ID=$(echo "$PROJECT_DATA" | jq -r '.data.user.projectV2.field.options[] | select(.name == "User Story") | .id')

# Get repository ID
REPO_ID=$(gh api graphql -f query='
  query($owner:String!, $repo:String!) {
    repository(owner:$owner, name:$repo) { id }
  }' \
  -F owner="$OWNER" \
  -F repo="$REPO" \
  --jq '.data.repository.id')

echo "✅ Configuration loaded"
echo "   Project ID: $PROJECT_ID"
echo "   Repository ID: $REPO_ID"
echo "   Type Field ID: $TYPE_FIELD_ID"
echo "   User Story Option ID: $USER_STORY_OPTION_ID"
echo ""

# Function to create a user story (similar to add_task but for epics as parents)
add_user_story() {
    local parent_epic_number="$1"
    local title="$2"
    local body="$3"
    
    echo -n "  📝 Creating user story: $title... "
    
    # Step 1: Get parent epic's project item ID
    PARENT_DATA=$(gh api graphql -H "GraphQL-Features: project_v2" \
      -f query='
        query($owner:String!, $repo:String!, $parentNum:Int!) {
          repository(owner:$owner, name:$repo) { 
            issue(number:$parentNum) { 
              id
              title
              projectItems(last:1) { 
                nodes { 
                  id 
                } 
              } 
            }
          }
        }' \
      -F owner="$OWNER" \
      -F repo="$REPO" \
      -F parentNum="$parent_epic_number" 2>/dev/null)
    
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
    DRAFT_RESULT=$(gh api graphql -H "GraphQL-Features: project_v2" \
      -f query='
        mutation($projId:ID!, $title:String!, $body:String!) {
          addProjectV2DraftIssue(input:{
            projectId:$projId, 
            title:$title, 
            body:$body
          }) {
            projectItem { 
              id 
            }
          }
        }' \
      -F projId="$PROJECT_ID" \
      -F title="$title" \
      -F body="**Parent Epic**: #$parent_epic_number - $PARENT_TITLE

$body" 2>/dev/null)
    
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
      -f query='
        mutation($projId:ID!, $itemId:ID!, $fieldId:ID!, $optionId:String!) {
          updateProjectV2ItemFieldValue(input: {
            projectId: $projId,
            itemId: $itemId,
            fieldId: $fieldId,
            value: {
              singleSelectOptionId: $optionId
            }
          }) {
            projectV2Item {
              id
            }
          }
        }' \
      -F projId="$PROJECT_ID" \
      -F itemId="$DRAFT_ITEM_ID" \
      -F fieldId="$TYPE_FIELD_ID" \
      -F optionId="$USER_STORY_OPTION_ID" > /dev/null 2>&1
    
    # Step 4: Convert to repository issue
    CONVERT_RESULT=$(gh api graphql -H "GraphQL-Features: project_v2" \
      -f query='
        mutation($itemId:ID!, $repo:ID!) {
          convertProjectV2DraftIssueItemToIssue(input:{
            itemId: $itemId,
            repositoryId: $repo
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
        }' \
      -F itemId="$DRAFT_ITEM_ID" \
      -F repo="$REPO_ID" 2>/dev/null)
    
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
      -f query='
        mutation($parentId:ID!, $childId:ID!) {
          addSubIssue(input: {
            issueId: $parentId,
            subIssueId: $childId
          }) {
            issue {
              id
            }
          }
        }' \
      -F parentId="$PARENT_ISSUE_ID" \
      -F childId="$NEW_ISSUE_ID" > /dev/null 2>&1 || true
    
    echo "✅ #$NEW_ISSUE_NUMBER"
    sleep 0.5  # Rate limiting
}

# First, let's find the existing epics
echo "🔍 Finding existing epics in the project..."
echo ""

# Get Epic 1 issue number
EPIC1_NUM=$(gh issue list -R $OWNER/$REPO --search "Epic 1: Core Infrastructure" --limit 1 --json number --jq '.[0].number // empty')
EPIC2_NUM=$(gh issue list -R $OWNER/$REPO --search "Epic 2: User Type Management" --limit 1 --json number --jq '.[0].number // empty')
EPIC3_NUM=$(gh issue list -R $OWNER/$REPO --search "Epic 3: High-Level API" --limit 1 --json number --jq '.[0].number // empty')
EPIC4_NUM=$(gh issue list -R $OWNER/$REPO --search "Epic 4: Advanced Features" --limit 1 --json number --jq '.[0].number // empty')
EPIC5_NUM=$(gh issue list -R $OWNER/$REPO --search "Epic 5: Testing" --limit 1 --json number --jq '.[0].number // empty')

echo "Found epics:"
[ -n "$EPIC1_NUM" ] && echo "  ✓ Epic 1: #$EPIC1_NUM"
[ -n "$EPIC2_NUM" ] && echo "  ✓ Epic 2: #$EPIC2_NUM"
[ -n "$EPIC3_NUM" ] && echo "  ✓ Epic 3: #$EPIC3_NUM"
[ -n "$EPIC4_NUM" ] && echo "  ✓ Epic 4: #$EPIC4_NUM"
[ -n "$EPIC5_NUM" ] && echo "  ✓ Epic 5: #$EPIC5_NUM"
echo ""

# Read user stories from JSON
echo "📋 Creating User Stories from JSON data"
echo "======================================"
echo ""

USER_STORIES_JSON=$(cat documentation/voice-transcription-feature/user-stories.json)

# Process each user story
echo "$USER_STORIES_JSON" | jq -c '.[]' | while read -r story; do
    STORY_TITLE=$(echo "$story" | jq -r '.title')
    STORY_EPIC=$(echo "$story" | jq -r '.epic')
    STORY_DOC=$(echo "$story" | jq -r '.documentation // empty')
    
    # Determine epic number based on epic name
    EPIC_NUMBER=""
    case "$STORY_EPIC" in
        "Epic 1") EPIC_NUMBER="$EPIC1_NUM" ;;
        "Epic 2") EPIC_NUMBER="$EPIC2_NUM" ;;
        "Epic 3") EPIC_NUMBER="$EPIC3_NUM" ;;
        "Epic 4") EPIC_NUMBER="$EPIC4_NUM" ;;
        "Epic 5") EPIC_NUMBER="$EPIC5_NUM" ;;
    esac
    
    if [ -z "$EPIC_NUMBER" ]; then
        echo "⚠️  Skipping $STORY_TITLE - parent epic not found"
        continue
    fi
    
    # Build story body
    STORY_BODY="## 📋 User Story Overview

As a developer, I need to implement $STORY_TITLE to enable voice transcription functionality in Telethon.

## 📚 Documentation
"
    
    if [ -n "$STORY_DOC" ]; then
        if [[ "$STORY_DOC" == *"#"* ]]; then
            FILE_PATH="${STORY_DOC%%#*}"
            ANCHOR="${STORY_DOC#*#}"
            STORY_BODY="${STORY_BODY}- **Implementation Details**: [View in Technical Architecture](${DOC_BASE}/${FILE_PATH#./}#${ANCHOR})
"
        else
            STORY_BODY="${STORY_BODY}- **Implementation Details**: [View Documentation](${DOC_BASE}/${STORY_DOC#./})
"
        fi
    fi
    
    STORY_BODY="${STORY_BODY}
## ✅ Acceptance Criteria

- [ ] Implementation follows technical architecture
- [ ] Unit tests provide adequate coverage  
- [ ] Integration tests pass
- [ ] Documentation is updated
- [ ] Code review completed
- [ ] Performance benchmarks met

## 🎯 Definition of Done

- [ ] Code is written and follows project standards
- [ ] Tests are written and passing
- [ ] Documentation is updated
- [ ] Code review is approved
- [ ] Feature is integrated and working end-to-end"
    
    # Create the user story
    add_user_story "$EPIC_NUMBER" "$STORY_TITLE" "$STORY_BODY"
done

echo ""
echo "✅ User story creation complete!"
echo ""
echo "Summary:"
echo "- User Stories created as repository issues"
echo "- Type field set to 'User Story'"
echo "- Stories linked as sub-issues to existing epics"
echo "- All items added to the project board"