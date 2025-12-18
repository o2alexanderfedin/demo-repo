#!/usr/bin/env bash
set -euo pipefail

# Configuration for Telethon repository  
OWNER="o2alexanderfedin"
REPO="Telethon"
PROJECT_NUMBER=12
EPICS_FILE="/Users/alexanderfedin/Projects/demo/workspace/Telethon/docs/architecture/documentation/voice-transcription-feature/epics.json"
DOC_BASE="https://github.com/o2alexanderfedin/Telethon/blob/develop/docs/architecture/documentation/voice-transcription-feature"

echo "🚀 Creating Epics for Voice Transcription in Telethon Repository"
echo "================================================================"
echo "Repository: $OWNER/$REPO"
echo "Project: #$PROJECT_NUMBER"
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
EPIC_OPTION_ID=$(echo "$PROJECT_DATA" | jq -r '.data.user.projectV2.field.options[] | select(.name == "Epic") | .id')

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
echo "   Epic Option ID: $EPIC_OPTION_ID"
echo ""

# Array to store created epic numbers (using regular array for compatibility)
EPIC_NUMBERS=()

# Function to create an epic using the project API
create_epic() {
    local epic_num="$1"
    local title="$2"
    local analysis_doc="epic${epic_num}-analysis.md"
    
    echo "📊 Creating Epic $epic_num: $title"
    
    # Create the body content
    local body="## 📊 Epic Overview

This epic is part of the Voice Transcription feature implementation for Telethon.

### 📚 Documentation

- **Epic Analysis**: [View Analysis]($DOC_BASE/$analysis_doc)
- **Technical Architecture**: [View Technical Docs]($DOC_BASE/technical-architecture.md)

### 🎯 Objective

Implement comprehensive voice message transcription capabilities in Telethon.

### 📋 Epic Details

- **Epic Number**: $epic_num
- **Status**: Planning
- **Feature**: Voice Transcription

### 🔗 User Stories

User stories will be linked to this epic after creation.

---
*Created as part of Voice Transcription feature migration*"
    
    # Step 1: Create draft issue in the project
    echo -n "  1️⃣ Creating draft... "
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
      -F title="[Epic $epic_num] $title" \
      -F body="$body" 2>&1)
    
    if [ $? -ne 0 ]; then
        echo "❌ Failed"
        echo "Error: $DRAFT_RESULT"
        return 1
    fi
    
    DRAFT_ITEM_ID=$(echo "$DRAFT_RESULT" | jq -r '.data.addProjectV2DraftIssue.projectItem.id // empty')
    
    if [ -z "$DRAFT_ITEM_ID" ]; then
        echo "❌ No draft ID returned"
        return 1
    fi
    echo "✅ Draft created"
    
    # Step 2: Set Type field to Epic
    echo -n "  2️⃣ Setting type to Epic... "
    TYPE_RESULT=$(gh api graphql -H "GraphQL-Features: project_v2" \
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
      -F optionId="$EPIC_OPTION_ID" 2>&1)
    
    if [ $? -ne 0 ]; then
        echo "❌ Failed"
        echo "Error: $TYPE_RESULT"
        return 1
    fi
    echo "✅ Type set"
    
    # Step 3: Convert to issue
    echo -n "  3️⃣ Converting to issue... "
    CONVERT_RESULT=$(gh api graphql -H "GraphQL-Features: project_v2" \
      -f query='
        mutation($projId:ID!, $itemId:ID!, $repoId:ID!) {
          convertProjectV2DraftIssueToIssue(input: {
            projectId: $projId,
            itemId: $itemId,
            repositoryId: $repoId
          }) {
            item {
              id
              content {
                ... on Issue {
                  id
                  number
                  title
                }
              }
            }
          }
        }' \
      -F projId="$PROJECT_ID" \
      -F itemId="$DRAFT_ITEM_ID" \
      -F repoId="$REPO_ID" 2>&1)
    
    if [ $? -ne 0 ]; then
        echo "❌ Failed"
        echo "Error: $CONVERT_RESULT"
        return 1
    fi
    
    ISSUE_NUMBER=$(echo "$CONVERT_RESULT" | jq -r '.data.convertProjectV2DraftIssueToIssue.item.content.number // empty')
    
    if [ -z "$ISSUE_NUMBER" ]; then
        echo "❌ No issue number returned"
        return 1
    fi
    
    echo "✅ Converted to Issue #$ISSUE_NUMBER"
    
    # Store the issue number
    EPIC_NUMBERS[$epic_num]=$ISSUE_NUMBER
    
    # Add labels
    echo -n "  4️⃣ Adding labels... "
    gh issue edit "$ISSUE_NUMBER" \
        --repo "$OWNER/$REPO" \
        --add-label "epic,voice-transcription,enhancement" 2>/dev/null && echo "✅ Labels added" || echo "⚠️  Some labels might not exist"
    
    echo "  ✅ Epic $epic_num created as Issue #$ISSUE_NUMBER"
    echo ""
    
    sleep 1  # Rate limiting
}

# Create all 5 epics
create_epic 1 "Core Infrastructure & Raw API Support"
create_epic 2 "User Type Management & Quota System"
create_epic 3 "High-Level API & Client Integration"
create_epic 4 "Advanced Features & Optimization"
create_epic 5 "Testing, Documentation & Polish"

echo "✅ All epics created successfully!"
echo ""
echo "📊 Created Epics:"
for i in {1..5}; do
    if [ -n "${EPIC_NUMBERS[$i]:-}" ]; then
        echo "  - Epic $i: Issue #${EPIC_NUMBERS[$i]}"
    fi
done

# Save epic mapping for user story creation
echo ""
echo "📝 Saving epic mapping..."
cat > /tmp/epic-issue-mapping.sh << EOF
#!/bin/bash
# Epic number to issue number mapping
declare -A EPIC_ISSUES=(
$(for i in {1..5}; do
    if [ -n "${EPIC_NUMBERS[$i]:-}" ]; then
        echo "  [$i]=\"${EPIC_NUMBERS[$i]}\""
    fi
done)
)
EOF

echo "✅ Epic mapping saved to /tmp/epic-issue-mapping.sh"
echo ""
echo "Next steps:"
echo "1. Run the user story creation script"
echo "2. The stories will be linked to these epics"