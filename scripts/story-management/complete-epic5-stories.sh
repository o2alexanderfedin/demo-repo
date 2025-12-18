#!/usr/bin/env bash
set -euo pipefail

# Complete Epic 5 user stories
OWNER="o2alexanderfedin"
REPO="Telethon"
PROJECT_NUMBER=12
DOC_BASE="https://github.com/o2alexanderfedin/Telethon/blob/develop/docs/architecture/documentation/voice-transcription-feature"

echo "📝 Completing Epic 5 User Stories"
echo "================================="

# Get project configuration (reuse from previous script)
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
REPO_ID=$(gh api graphql --raw-field query='{ repository(owner:"'$OWNER'", name:"'$REPO'") { id } }' --jq '.data.repository.id')

# Epic 5 issue number
EPIC5_NUMBER="264"

# Function to create user story (same as before)
add_user_story() {
    local parent_epic_number="$1"
    local title="$2"
    local body="$3"
    
    echo -n "  📝 Creating user story: $title... "
    
    # Get parent epic data
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
    
    PARENT_ISSUE_ID=$(echo "$PARENT_DATA" | jq -r '.data.repository.issue.id // empty')
    PARENT_TITLE=$(echo "$PARENT_DATA" | jq -r '.data.repository.issue.title // empty')
    
    # Create draft
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
    
    DRAFT_ITEM_ID=$(echo "$DRAFT_RESULT" | jq -r '.data.addProjectV2DraftIssue.projectItem.id // empty')
    
    if [ -z "$DRAFT_ITEM_ID" ]; then
        echo "❌ Failed"
        return 1
    fi
    
    # Set Type to User Story
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
    
    # Convert to repository issue
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
    
    NEW_ISSUE_NUMBER=$(echo "$CONVERT_RESULT" | jq -r '.data.convertProjectV2DraftIssueItemToIssue.item.content.number // empty')
    NEW_ISSUE_ID=$(echo "$CONVERT_RESULT" | jq -r '.data.convertProjectV2DraftIssueItemToIssue.item.content.id // empty')
    
    if [ -z "$NEW_ISSUE_NUMBER" ]; then
        echo "❌ Failed"
        return 1
    fi
    
    # Link as sub-issue
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
    sleep 0.5
}

# Epic 5 user stories
MAPPING_FILE="/Users/alexanderfedin/Projects/demo/workspace/Telethon/docs/architecture/documentation/voice-transcription-feature/epic-story-mapping.json"

echo "🎯 Creating User Stories for Epic 5 (Issue #$EPIC5_NUMBER)..."

# Get Epic 5 data
epic_data=$(jq -r '.mappings[] | select(.epic_title | contains("Epic 5:"))' "$MAPPING_FILE")
epic_title=$(echo "$epic_data" | jq -r '.epic_title')
echo "   Epic: $epic_title"

# Create each user story
echo "$epic_data" | jq -c '.user_stories[]' | while read -r story; do
    story_title=$(echo "$story" | jq -r '.title')
    story_reason=$(echo "$story" | jq -r '.reason')
    
    story_body="## 📋 User Story Overview

As a developer, I need to implement $story_title to enable voice transcription functionality in Telethon.

### 🎯 Purpose
$story_reason

## 📚 Documentation

- **Epic Analysis**: [View Epic Analysis]($DOC_BASE/epic5-analysis.md)
- **Technical Architecture**: [View Technical Docs]($DOC_BASE/technical-architecture.md)

## ✅ Acceptance Criteria

- [ ] Implementation follows technical architecture
- [ ] Unit tests provide adequate coverage
- [ ] Integration tests pass
- [ ] Documentation is updated
- [ ] Code review completed
- [ ] Performance benchmarks met

---
*Part of Epic 5: Voice Transcription feature implementation*"
    
    add_user_story "$EPIC5_NUMBER" "$story_title" "$story_body"
done

echo ""
echo "✅ Epic 5 user stories completed!"