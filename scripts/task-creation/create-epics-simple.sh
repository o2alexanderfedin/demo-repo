#!/usr/bin/env bash
set -euo pipefail

# Configuration for Telethon repository  
OWNER="o2alexanderfedin"
REPO="Telethon"
PROJECT_NUMBER=12
DOC_BASE="https://github.com/o2alexanderfedin/Telethon/blob/develop/docs/architecture/documentation/voice-transcription-feature"

echo "🚀 Creating Epics for Voice Transcription in Telethon Repository"
echo "================================================================"
echo "Repository: $OWNER/$REPO"
echo "Project: #$PROJECT_NUMBER"
echo ""

# Get project configuration
echo "📋 Getting project information..."
PROJECT_INFO=$(gh api graphql -f query="
query {
  user(login: \"$OWNER\") {
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
}")

PROJECT_ID=$(echo "$PROJECT_INFO" | jq -r ".data.user.projectV2.id")
PROJECT_TITLE=$(echo "$PROJECT_INFO" | jq -r ".data.user.projectV2.title")

if [ -z "$PROJECT_ID" ] || [ "$PROJECT_ID" = "null" ]; then
    echo "❌ Failed to find project"
    exit 1
fi

echo "✅ Project: $PROJECT_TITLE"

# Get repository ID
echo "📋 Getting repository information..."
REPO_ID=$(gh api graphql -f query='
  query($owner:String!, $repo:String!) {
    repository(owner:$owner, name:$repo) { id }
  }' \
  -F owner="$OWNER" \
  -F repo="$REPO" \
  --jq '.data.repository.id')

# Get field IDs
TYPE_FIELD_ID=$(echo "$PROJECT_INFO" | jq -r '.data.user.projectV2.fields.nodes[] | select(.name == "Type") | .id')
EPIC_OPTION_ID=$(echo "$PROJECT_INFO" | jq -r '.data.user.projectV2.fields.nodes[] | select(.name == "Type") | .options[] | select(.name == "Epic") | .id')
STATUS_FIELD_ID=$(echo "$PROJECT_INFO" | jq -r '.data.user.projectV2.fields.nodes[] | select(.name == "Status") | .id')
TODO_OPTION_ID=$(echo "$PROJECT_INFO" | jq -r '.data.user.projectV2.fields.nodes[] | select(.name == "Status") | .options[] | select(.name == "Todo") | .id')

echo "   Project ID: $PROJECT_ID"
echo "   Repository ID: $REPO_ID"
echo "   Type Field ID: $TYPE_FIELD_ID"
echo "   Epic Option ID: $EPIC_OPTION_ID"
echo ""

# Variables to store created epic numbers
EPIC_NUMBERS=()

# Function to create an epic
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
    
    # Create draft item
    echo -n "  1️⃣ Creating draft item... "
    QUERY='mutation($projId:ID!, $title:String!, $body:String!) {
      addProjectV2DraftIssue(input: {
        projectId: $projId
        title: $title
        body: $body
      }) {
        projectItem {
          id
        }
      }
    }'
    ITEM_ID=$(gh api graphql -f query="$QUERY" -F projId="$PROJECT_ID" -F title="[Epic $epic_num] $title" -F body="$body" --jq '.data.addProjectV2DraftIssue.projectItem.id' 2>&1)
    
    if [ -z "$ITEM_ID" ]; then
        echo "❌ Failed"
        return 1
    fi
    echo "✅ Created"
    
    # Set Type to Epic
    echo -n "  2️⃣ Setting type to Epic... "
    gh api graphql -f query="
    mutation {
      updateProjectV2ItemFieldValue(input: {
        projectId: \"$PROJECT_ID\"
        itemId: \"$ITEM_ID\"
        fieldId: \"$TYPE_FIELD_ID\"
        value: {
          singleSelectOptionId: \"$EPIC_OPTION_ID\"
        }
      }) {
        projectV2Item {
          id
        }
      }
    }" > /dev/null 2>&1 && echo "✅ Type set" || echo "⚠️  Type failed"
    
    # Set Status to Todo
    echo -n "  3️⃣ Setting status to Todo... "
    gh api graphql -f query="
    mutation {
      updateProjectV2ItemFieldValue(input: {
        projectId: \"$PROJECT_ID\"
        itemId: \"$ITEM_ID\"
        fieldId: \"$STATUS_FIELD_ID\"
        value: {
          singleSelectOptionId: \"$TODO_OPTION_ID\"
        }
      }) {
        projectV2Item {
          id
        }
      }
    }" > /dev/null 2>&1 && echo "✅ Status set" || echo "⚠️  Status failed"
    
    # Convert draft to repository issue
    echo -n "  4️⃣ Converting to repository issue... "
    CONVERT_RESULT=$(gh api graphql -H "GraphQL-Features: project_v2" \
      -f query='
        mutation($itemId:ID!, $repoId:ID!) {
          convertProjectV2DraftIssueItemToIssue(input:{
            itemId: $itemId,
            repositoryId: $repoId
          }) {
            item { 
              content { 
                ... on Issue { 
                  number 
                  id 
                  title
                } 
              } 
            }
          }
        }' \
      -F itemId="$ITEM_ID" \
      -F repoId="$REPO_ID" 2>&1)
    
    if [ $? -eq 0 ]; then
        ISSUE_NUMBER=$(echo "$CONVERT_RESULT" | jq -r '.data.convertProjectV2DraftIssueItemToIssue.item.content.number // empty')
        if [ -n "$ISSUE_NUMBER" ]; then
            echo "✅ Issue #$ISSUE_NUMBER"
            EPIC_NUMBERS[$epic_num]=$ISSUE_NUMBER
        else
            echo "⚠️  No issue number returned"
            EPIC_NUMBERS[$epic_num]=$ITEM_ID
        fi
    else
        echo "⚠️  Conversion failed, keeping as draft"
        EPIC_NUMBERS[$epic_num]=$ITEM_ID
    fi
    
    echo "  ✅ Epic $epic_num created successfully"
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
        if [[ "${EPIC_NUMBERS[$i]}" =~ ^[0-9]+$ ]]; then
            echo "  - Epic $i: Issue #${EPIC_NUMBERS[$i]}"
        else
            echo "  - Epic $i: Draft Item ${EPIC_NUMBERS[$i]}"
        fi
    fi
done

echo ""
echo "✅ Epic creation completed! Check your project board at:"
echo "https://github.com/users/$OWNER/projects/$PROJECT_NUMBER"