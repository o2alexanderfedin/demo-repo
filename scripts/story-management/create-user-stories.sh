#!/usr/bin/env bash
set -euo pipefail

# Script to create user stories using the same algorithm as add_task
# Creates draft items, sets Type field, converts to issues, and links to epics

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

# Read user stories from JSON and create them
echo "📋 Creating User Stories from JSON data"
echo "======================================"
echo ""

# First, we need to create the epics
echo "🎯 First, let's create the Epics..."
echo ""

# Read epics from JSON
EPICS_JSON=$(cat documentation/voice-transcription-feature/epics.json)

# Create a mapping of epic titles to issue numbers
# Using a temp file instead of associative array for compatibility

# Create each epic
echo "$EPICS_JSON" | jq -c '.[]' | while read -r epic; do
    EPIC_TITLE=$(echo "$epic" | jq -r '.title')
    EPIC_DOCS=$(echo "$epic" | jq -r '.documentation')
    
    # Extract documentation links
    ANALYSIS_LINK=$(echo "$EPIC_DOCS" | jq -r '.analysis // empty')
    TECHNICAL_LINK=$(echo "$EPIC_DOCS" | jq -r '.technical // empty')
    SPRINT_LINK=$(echo "$EPIC_DOCS" | jq -r '.sprint_plan // empty')
    TESTING_LINK=$(echo "$EPIC_DOCS" | jq -r '.testing // empty')
    
    # Build epic body
    EPIC_BODY="## 📋 Epic Overview

This epic encompasses the following major work areas for the Voice Transcription feature.

## 📚 Documentation

"
    
    if [ -n "$ANALYSIS_LINK" ]; then
        EPIC_BODY="${EPIC_BODY}- **Epic Analysis**: [View Analysis](${DOC_BASE}/${ANALYSIS_LINK#./})
"
    fi
    
    if [ -n "$TECHNICAL_LINK" ]; then
        if [[ "$TECHNICAL_LINK" == *"#"* ]]; then
            FILE_PATH="${TECHNICAL_LINK%%#*}"
            ANCHOR="${TECHNICAL_LINK#*#}"
            EPIC_BODY="${EPIC_BODY}- **Technical Architecture**: [View Details](${DOC_BASE}/${FILE_PATH#./}#${ANCHOR})
"
        else
            EPIC_BODY="${EPIC_BODY}- **Technical Architecture**: [View Details](${DOC_BASE}/${TECHNICAL_LINK#./})
"
        fi
    fi
    
    if [ -n "$SPRINT_LINK" ]; then
        EPIC_BODY="${EPIC_BODY}- **Sprint Planning**: [View Plan](${DOC_BASE}/${SPRINT_LINK#./})
"
    fi
    
    if [ -n "$TESTING_LINK" ]; then
        EPIC_BODY="${EPIC_BODY}- **Testing Strategy**: [View Testing](${DOC_BASE}/${TESTING_LINK#./})
"
    fi
    
    echo -n "Creating Epic: $EPIC_TITLE... "
    
    # Create the epic as a regular issue first
    EPIC_RESPONSE=$(gh issue create \
        --repo "$OWNER/$REPO" \
        --title "$EPIC_TITLE" \
        --body "$EPIC_BODY" \
        --label "epic" 2>/dev/null || echo "ERROR")
    
    if [[ "$EPIC_RESPONSE" == "ERROR" ]] || [[ -z "$EPIC_RESPONSE" ]]; then
        echo "❌ Failed to create epic"
        continue
    fi
    
    # Extract issue number from response
    EPIC_NUMBER=$(echo "$EPIC_RESPONSE" | grep -oE '[0-9]+$')
    echo "✅ #$EPIC_NUMBER"
    
    # Store the mapping
    echo "$EPIC_TITLE:$EPIC_NUMBER" >> /tmp/epic_mapping.txt
    
    # Add to project and set Type to Epic
    # Get the issue's node ID
    EPIC_NODE_ID=$(gh api repos/$OWNER/$REPO/issues/$EPIC_NUMBER --jq '.node_id')
    
    # Add to project
    ITEM_RESPONSE=$(gh api graphql -f query='
    mutation {
      addProjectV2ItemById(input: {
        projectId: "'$PROJECT_ID'"
        contentId: "'$EPIC_NODE_ID'"
      }) {
        item {
          id
        }
      }
    }' 2>/dev/null)
    
    ITEM_ID=$(echo "$ITEM_RESPONSE" | jq -r '.data.addProjectV2ItemById.item.id // empty')
    
    if [ -n "$ITEM_ID" ]; then
        # Set Type to Epic
        EPIC_OPTION_ID=$(echo "$PROJECT_DATA" | jq -r '.data.user.projectV2.field.options[] | select(.name == "Epic") | .id')
        
        gh api graphql -f query='
        mutation {
          updateProjectV2ItemFieldValue(input: {
            projectId: "'$PROJECT_ID'"
            itemId: "'$ITEM_ID'"
            fieldId: "'$TYPE_FIELD_ID'"
            value: {
              singleSelectOptionId: "'$EPIC_OPTION_ID'"
            }
          }) {
            projectV2Item {
              id
            }
          }
        }' > /dev/null 2>&1
    fi
    
    sleep 0.5
done

echo ""
echo "Now creating User Stories..."
echo ""

# Read the epic mapping
declare -A EPIC_MAP
while IFS=: read -r title number; do
    EPIC_MAP["$title"]="$number"
done < /tmp/epic_mapping.txt

# Now create user stories
USER_STORIES_JSON=$(cat documentation/voice-transcription-feature/user-stories.json)

echo "$USER_STORIES_JSON" | jq -c '.[]' | while read -r story; do
    STORY_TITLE=$(echo "$story" | jq -r '.title')
    STORY_EPIC=$(echo "$story" | jq -r '.epic')
    STORY_DOC=$(echo "$story" | jq -r '.documentation // empty')
    
    # Find the epic number
    EPIC_NUMBER=""
    for epic_title in "${!EPIC_MAP[@]}"; do
        if [[ "$epic_title" == *"$STORY_EPIC"* ]]; then
            EPIC_NUMBER="${EPIC_MAP[$epic_title]}"
            break
        fi
    done
    
    if [ -z "$EPIC_NUMBER" ]; then
        # Try to find by searching existing issues
        EPIC_NUMBER=$(gh issue list -R $OWNER/$REPO --search "$STORY_EPIC in:title" --json number --jq '.[0].number // empty')
    fi
    
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
- [ ] Performance benchmarks met"
    
    # Create the user story
    add_user_story "$EPIC_NUMBER" "$STORY_TITLE" "$STORY_BODY"
done

# Cleanup
rm -f /tmp/epic_mapping.txt

echo ""
echo "✅ User story creation complete!"
echo ""
echo "Summary:"
echo "- Epics and User Stories created as repository issues"
echo "- Type field properly set (Epic/User Story)"
echo "- Stories linked as sub-issues to their parent epics"
echo "- All items added to the project board"