#!/usr/bin/env bash
set -euo pipefail

# Configuration for Telethon repository
OWNER="o2alexanderfedin"
REPO="Telethon"
PROJECT_NUMBER=12
EPICS_JSON="/Users/alexanderfedin/Projects/demo/workspace/Telethon/docs/architecture/documentation/voice-transcription-feature/epics.json"
DOC_BASE="https://github.com/o2alexanderfedin/Telethon/blob/develop/docs/architecture/documentation/voice-transcription-feature"

echo "🚀 Creating Epics for Voice Transcription in Telethon Repository"
echo "================================================================"
echo "Repository: $OWNER/$REPO"
echo "Project: #$PROJECT_NUMBER"
echo ""

# Get project and field IDs
echo "📋 Getting project configuration..."
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

echo "Project ID: $PROJECT_ID"
echo "Epic Type ID: $EPIC_OPTION_ID"
echo ""

# Function to create an epic
create_epic() {
    local title="$1"
    local analysis_doc="$2"
    local technical_doc="$3"
    local additional_docs="$4"
    
    echo "📝 Creating Epic: $title"
    
    # Create issue body with documentation links
    local body="## 📊 Epic Overview

This epic is part of the Voice Transcription feature implementation for Telethon.

### 📚 Documentation

- **Epic Analysis**: [View Analysis]($DOC_BASE/$analysis_doc)
- **Technical Architecture**: [View Technical Docs]($DOC_BASE/$technical_doc)
$additional_docs

### 🎯 Objective

Implement comprehensive voice message transcription capabilities in Telethon, providing users with the ability to convert voice messages to text using Telegram's native transcription API.

### 🔄 Status

This epic contains multiple user stories and tasks that need to be implemented.

---
*Created as part of Voice Transcription feature migration to Telethon repository*"

    # Create the issue
    local issue_url=$(gh issue create \
        --repo "$OWNER/$REPO" \
        --title "$title" \
        --body "$body" \
        --label "Epic,Voice Transcription,Feature" \
        --project "$PROJECT_NUMBER")
    
    local issue_number=$(echo "$issue_url" | grep -o '[0-9]*$')
    
    echo "✅ Created Epic #$issue_number: $title"
    echo ""
    
    # Add to project and set type to Epic
    if [ -n "$issue_number" ]; then
        # Get the item ID from the project
        local item_id=$(gh api graphql -H "GraphQL-Features: project_v2" \
            -f query='
                query($projectId:ID!, $contentId:ID!) {
                    node(id:$projectId) {
                        ... on ProjectV2 {
                            items(first:100) {
                                nodes {
                                    id
                                    content {
                                        ... on Issue {
                                            id
                                        }
                                    }
                                }
                            }
                        }
                    }
                }' \
            -F projectId="$PROJECT_ID" \
            -F contentId="$(gh api repos/$OWNER/$REPO/issues/$issue_number --jq '.node_id')" \
            --jq '.data.node.items.nodes[] | select(.content.id == "'$(gh api repos/$OWNER/$REPO/issues/$issue_number --jq '.node_id')'") | .id' 2>/dev/null || echo "")
        
        if [ -n "$item_id" ]; then
            # Set type to Epic
            gh api graphql -H "GraphQL-Features: project_v2" \
                -f query='
                    mutation($projectId:ID!, $itemId:ID!, $fieldId:ID!, $value:String!) {
                        updateProjectV2ItemFieldValue(input:{
                            projectId:$projectId
                            itemId:$itemId
                            fieldId:$fieldId
                            value:{singleSelectOptionId:$value}
                        }) {
                            projectV2Item { id }
                        }
                    }' \
                -F projectId="$PROJECT_ID" \
                -F itemId="$item_id" \
                -F fieldId="$TYPE_FIELD_ID" \
                -F value="$EPIC_OPTION_ID" >/dev/null 2>&1 || true
        fi
    fi
    
    return 0
}

# Read epics from JSON and create them
echo "📖 Reading epics from JSON file..."
echo ""

# Epic 1
create_epic \
    "Epic 1: Core Infrastructure & Raw API Support" \
    "epic1-analysis.md" \
    "technical-architecture.md#core-infrastructure" \
    "- **Sprint Plan**: [View Sprint 1 Plan]($DOC_BASE/sprint-1-plan.md)"

# Epic 2  
create_epic \
    "Epic 2: User Type Management & Quota System" \
    "epic2-analysis.md" \
    "user-type-architecture.md" \
    "- **Rate Limiting**: [View Rate Limiting Docs]($DOC_BASE/technical-architecture.md#rate-limiting-and-quotas)"

# Epic 3
create_epic \
    "Epic 3: High-Level API & Client Integration" \
    "epic3-analysis.md" \
    "technical-architecture.md#component-design" \
    "- **API Design**: [View API Design]($DOC_BASE/technical-architecture.md#integration-points)"

# Epic 4
create_epic \
    "Epic 4: Advanced Features & Optimization" \
    "epic4-analysis.md" \
    "technical-architecture.md#performance-considerations" \
    "- **Caching Strategy**: [View Caching Docs]($DOC_BASE/technical-architecture.md#3-caching-strategy)"

# Epic 5
create_epic \
    "Epic 5: Testing, Documentation & Polish" \
    "epic5-analysis.md" \
    "technical-architecture.md#testing-strategy" \
    "- **Feature Overview**: [View README]($DOC_BASE/README.md)"

echo ""
echo "✅ All epics have been created successfully!"
echo ""
echo "📊 Summary:"
echo "- Repository: $OWNER/$REPO"
echo "- Project: #$PROJECT_NUMBER"
echo "- Created: 5 Epics"
echo ""
echo "Next steps:"
echo "1. Create User Stories under each Epic"
echo "2. Create Tasks under each User Story"
echo "3. Set up dependencies and priorities"