#!/usr/bin/env bash
set -euo pipefail

# Configuration for Voice Transcription project - Updated for Telethon repository
OWNER="o2alexanderfedin"
REPO="Telethon"
PROJECT_NUMBER=12
DOC_BASE="https://github.com/o2alexanderfedin/Telethon/blob/develop/docs/architecture/documentation/voice-transcription-feature"

echo "🔧 Creating Engineering Tasks for Voice Transcription Project (Part 1)..."
echo "========================================================"
echo "This script creates detailed engineering tasks for Epic 1 and Epic 2 user stories"
echo ""

# Get project and field IDs once
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
TASK_OPTION_ID=$(echo "$PROJECT_DATA" | jq -r '.data.user.projectV2.field.options[] | select(.name == "Task") | .id')

# Get repository ID
REPO_ID=$(gh api graphql \
  --raw-field query='{
      repository(owner:"'$OWNER'", name:"'$REPO'") { id }
    }' \
  --jq '.data.repository.id')

echo "✅ Configuration loaded successfully"
echo "   Project ID: $PROJECT_ID"
echo "   Repository ID: $REPO_ID"
echo ""

# Function to get user story issue number by title
get_user_story_number() {
    local title="$1"
    
    # Search for the user story in our known range (295-339)
    for issue_num in {295..339}; do
        ISSUE_TITLE=$(gh api repos/$OWNER/$REPO/issues/$issue_num --jq '.title' 2>/dev/null || echo "")
        if [ "$ISSUE_TITLE" = "$title" ]; then
            echo "$issue_num"
            return
        fi
    done
    echo ""
}

# Function to create a task as a sub-issue
add_task() {
    local parent_issue_number="$1"
    local title="$2"
    local body="$3"
    
    echo -n "  📝 Creating task: $title... "
    
    # Get parent issue data
    PARENT_DATA=$(gh api graphql -H "GraphQL-Features: project_v2" \
      --raw-field query='{
          repository(owner:"'$OWNER'", name:"'$REPO'") { 
            issue(number:'$parent_issue_number') { 
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
    
    if [ -z "$PARENT_ISSUE_ID" ]; then
        echo "❌ Parent issue not found"
        return 1
    fi
    
    # Create draft issue
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
    
    FULL_BODY="**Parent Story**: #$parent_issue_number - $PARENT_TITLE

$body"
    
    DRAFT_RESULT=$(gh api graphql -H "GraphQL-Features: project_v2" \
      -f query="$QUERY" \
      -F projId="$PROJECT_ID" \
      -F title="$title" \
      -F body="$FULL_BODY" 2>/dev/null)
    
    DRAFT_ITEM_ID=$(echo "$DRAFT_RESULT" | jq -r '.data.addProjectV2DraftIssue.projectItem.id // empty')
    
    if [ -z "$DRAFT_ITEM_ID" ]; then
        echo "❌ Failed to create draft"
        return 1
    fi
    
    # Set Type to Task
    gh api graphql -H "GraphQL-Features: project_v2" \
      --raw-field query='
        mutation {
          updateProjectV2ItemFieldValue(input: {
            projectId: "'$PROJECT_ID'",
            itemId: "'$DRAFT_ITEM_ID'",
            fieldId: "'$TYPE_FIELD_ID'",
            value: {
              singleSelectOptionId: "'$TASK_OPTION_ID'"
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
        echo "❌ Failed to convert"
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

# Function to create tasks for a user story
create_tasks_for_story() {
    local story_title="$1"
    shift
    local tasks=("$@")
    
    echo -e "\n▶ User Story: $story_title"
    
    # Get the issue number for this story
    STORY_NUM=$(get_user_story_number "$story_title")
    
    if [ -z "$STORY_NUM" ]; then
        echo "  ⚠️ Could not find issue number for '$story_title', skipping..."
        return
    fi
    
    echo "  📌 Found issue #$STORY_NUM"
    
    # Create each task
    local i=0
    while [ $i -lt ${#tasks[@]} ]; do
        local task_title="${tasks[$i]}"
        local task_body="${tasks[$((i+1))]}"
        add_task "$STORY_NUM" "$task_title" "$task_body"
        i=$((i+2))
    done
}

echo "📋 Creating Engineering Tasks for Epic 1 & Epic 2 User Stories"
echo "================================================================"
echo ""

# Epic 1: Core Infrastructure & Raw API Support
echo "🎯 Epic 1: Core Infrastructure & Raw API Support"
echo "----------------------------------------------"

# TL Schema Definitions
create_tasks_for_story "TL Schema Definitions" \
"Define voice message TL schema structures" \
"## 📋 Task Overview
This task involves creating the foundational TL (Type Language) schema definitions that will enable voice transcription functionality in Telethon.

## 🎯 Objective
Design and implement comprehensive TL schema structures that support all aspects of voice transcription.

## 🔧 Technical Requirements
- **VoiceTranscriptionRequest**: Define request structure
- **VoiceTranscriptionResult**: Define response structure  
- **VoiceTranscriptionUpdate**: Define update events

## 📚 Documentation References
- [TL Schema Definitions Guide](${DOC_BASE}/technical-architecture.md#tl-schema-definitions)

## ✅ Acceptance Criteria
- [ ] All core schemas defined and documented
- [ ] Schema compilation passes without errors
- [ ] Unit tests validate schema structure" \
\
"Implement schema serialization/deserialization methods" \
"## 📋 Task Overview
Implement robust serialization and deserialization methods for the voice transcription TL schemas.

## 🎯 Objective
Create high-performance, error-resistant serialization/deserialization implementations.

## 🔧 Technical Requirements
- Efficient binary encoding with optimal field ordering
- Robust parsing with validation and error handling
- Thread-safe implementation with performance optimization

## 📚 Documentation References
- [Serialization Patterns](${DOC_BASE}/technical-architecture.md#serialization)

## ✅ Acceptance Criteria
- [ ] Round-trip serialization tests pass
- [ ] Performance meets <1ms target for typical payloads
- [ ] Thread safety ensured" \
\
"Create comprehensive schema validation and testing suite" \
"## 📋 Task Overview
Develop a comprehensive testing suite specifically for voice transcription schemas.

## 🎯 Objective
Build a robust test suite that provides high confidence in schema correctness.

## 🔧 Technical Requirements
- Unit tests for all schema structures and validation
- Integration tests for API compatibility
- Performance benchmarks and load testing

## 📚 Documentation References
- [Testing Strategy](${DOC_BASE}/technical-architecture.md#testing-strategy)

## ✅ Acceptance Criteria
- [ ] 100% code coverage for schema modules
- [ ] Performance benchmarks established
- [ ] Integration with CI/CD pipeline"

echo "✅ Part 1 completed! Continue with Part 2 for remaining user stories."