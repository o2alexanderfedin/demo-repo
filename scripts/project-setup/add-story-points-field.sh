#!/usr/bin/env bash
set -euo pipefail

# Script to add Story Points field to GitHub Project
# This creates a single-select field with Fibonacci sequence options

OWNER="o2alexanderfedin"
PROJECT_NUMBER=12

echo "🎯 Adding Story Points Field to GitHub Project..."
echo "=============================================="
echo ""

# Get project ID
echo "📋 Getting project information..."
PROJECT_DATA=$(gh api graphql -H "GraphQL-Features: project_v2" \
  -f query='
    query($owner:String!, $projNum:Int!) {
      user(login:$owner) {
        projectV2(number:$projNum) { 
          id 
          title
        }
      }
    }' \
  -F owner="$OWNER" \
  -F projNum="$PROJECT_NUMBER")

PROJECT_ID=$(echo "$PROJECT_DATA" | jq -r '.data.user.projectV2.id')
PROJECT_TITLE=$(echo "$PROJECT_DATA" | jq -r '.data.user.projectV2.title')

echo "✅ Found project: $PROJECT_TITLE"
echo ""

# Create Story Points field with options
echo "📝 Creating Story Points field..."
FIELD_RESULT=$(gh api graphql -H "GraphQL-Features: project_v2" \
  -f query='
    mutation($projectId:ID!, $fieldName:String!, $options:[ProjectV2SingleSelectFieldOptionInput!]!) {
      createProjectV2Field(input: {
        projectId: $projectId,
        dataType: SINGLE_SELECT,
        name: $fieldName,
        singleSelectOptions: $options
      }) {
        projectV2Field {
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
    }' \
  -F projectId="$PROJECT_ID" \
  -F fieldName="Story Points" \
  -f options='[
    {"name": "1", "color": "GREEN", "description": "Very small task"},
    {"name": "2", "color": "GREEN", "description": "Small task"},
    {"name": "3", "color": "YELLOW", "description": "Medium-small task"},
    {"name": "5", "color": "YELLOW", "description": "Medium task"},
    {"name": "8", "color": "ORANGE", "description": "Large task"},
    {"name": "13", "color": "RED", "description": "Very large task"}
  ]' 2>&1)

# Check if field was created or if it already exists
if echo "$FIELD_RESULT" | grep -q "error"; then
    ERROR_MSG=$(echo "$FIELD_RESULT" | jq -r '.errors[0].message // empty')
    if echo "$ERROR_MSG" | grep -qi "already exists"; then
        echo "ℹ️  Story Points field already exists"
        
        # Get existing field info
        EXISTING_FIELD=$(gh api graphql -H "GraphQL-Features: project_v2" \
          -f query='
            query($owner:String!, $projNum:Int!) {
              user(login:$owner) {
                projectV2(number:$projNum) { 
                  field(name: "Story Points") {
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
            }' \
          -F owner="$OWNER" \
          -F projNum="$PROJECT_NUMBER")
        
        echo ""
        echo "📊 Existing Story Points options:"
        echo "$EXISTING_FIELD" | jq -r '.data.user.projectV2.field.options[] | "  - \(.name)"'
    else
        echo "❌ Error creating field: $ERROR_MSG"
        exit 1
    fi
else
    FIELD_ID=$(echo "$FIELD_RESULT" | jq -r '.data.createProjectV2Field.projectV2Field.id')
    FIELD_NAME=$(echo "$FIELD_RESULT" | jq -r '.data.createProjectV2Field.projectV2Field.name')
    
    echo "✅ Created field: $FIELD_NAME"
    echo ""
    echo "📊 Story Points options:"
    echo "$FIELD_RESULT" | jq -r '.data.createProjectV2Field.projectV2Field.options[] | "  - \(.name): \(.description // "")"'
fi

echo ""
echo "✅ Story Points field is ready!"
echo ""
echo "Next steps:"
echo "1. Run assign-story-points.sh to assign points to all tasks"
echo "2. The ML task (#144) will be set to Low priority automatically"