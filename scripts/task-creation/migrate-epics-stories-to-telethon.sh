#!/usr/bin/env bash
set -euo pipefail

# Configuration for Telethon repository
OWNER="o2alexanderfedin"
REPO="Telethon"
PROJECT_NUMBER=12
PROJECT_NAME="Voice Transcription Scrum"
MAPPING_FILE="/Users/alexanderfedin/Projects/demo/workspace/Telethon/docs/architecture/documentation/voice-transcription-feature/epic-story-mapping.json"
DOC_BASE="https://github.com/o2alexanderfedin/Telethon/blob/develop/docs/architecture/documentation/voice-transcription-feature"

echo "🚀 Migrating Voice Transcription Epics and User Stories to Telethon"
echo "=================================================================="
echo "Repository: $OWNER/$REPO"
echo "Project: $PROJECT_NAME (#$PROJECT_NUMBER)"
echo ""

# Arrays to store created items
declare -A EPIC_ISSUE_MAP
declare -A STORY_ISSUE_MAP

# Function to create an epic
create_epic() {
    local epic_title="$1"
    local epic_number="$2"
    
    echo "📊 Creating $epic_title"
    
    # Determine documentation based on epic number
    local analysis_doc="epic${epic_number}-analysis.md"
    local technical_doc="technical-architecture.md"
    
    local body="## 📊 Epic Overview

This epic is part of the Voice Transcription feature implementation for Telethon.

### 📚 Documentation

- **Epic Analysis**: [View Analysis]($DOC_BASE/$analysis_doc)
- **Technical Architecture**: [View Technical Docs]($DOC_BASE/$technical_doc)

### 🎯 Objective

Implement comprehensive voice message transcription capabilities in Telethon.

### 📋 User Stories

User stories will be linked to this epic after creation.

---
*Migrated from telethon-architecture-docs to Telethon repository*"

    # Create the issue
    local issue_url=$(gh issue create \
        --repo "$OWNER/$REPO" \
        --title "$epic_title" \
        --body "$body" \
        --label "enhancement,voice-transcription,epic" \
        --project "$PROJECT_NAME" 2>&1)
    
    # Extract issue number
    local issue_number=$(echo "$issue_url" | grep -o '[0-9]*$')
    
    if [ -n "$issue_number" ]; then
        echo "  ✅ Created Epic: Issue #$issue_number"
        EPIC_ISSUE_MAP["Epic $epic_number"]="$issue_number"
    else
        echo "  ❌ Failed to create epic"
        echo "  Output: $issue_url"
    fi
    
    sleep 1  # Rate limiting
}

# Function to create a user story
create_user_story() {
    local story_title="$1"
    local epic_ref="$2"
    local story_number="$3"
    
    echo "  📝 Creating Story: $story_title"
    
    # Get the epic issue number
    local epic_issue="${EPIC_ISSUE_MAP[$epic_ref]}"
    
    local body="## 📋 User Story Overview

This user story is part of **$epic_ref** (Issue #$epic_issue).

### 📚 Documentation

- **Technical Details**: [View Documentation]($DOC_BASE/technical-architecture.md)
- **Epic Analysis**: [View Epic Analysis]($DOC_BASE/${epic_ref##* }-analysis.md)

### 🎯 Acceptance Criteria

See the linked documentation for detailed acceptance criteria and implementation requirements.

### 🔗 Parent Epic

- #$epic_issue - $epic_ref

### 📋 Story Number: $story_number

---
*Migrated from telethon-architecture-docs to Telethon repository*"

    # Create the issue
    local issue_url=$(gh issue create \
        --repo "$OWNER/$REPO" \
        --title "$story_title" \
        --body "$body" \
        --label "enhancement,voice-transcription,user-story" \
        --project "$PROJECT_NAME" 2>&1)
    
    # Extract issue number
    local issue_number=$(echo "$issue_url" | grep -o '[0-9]*$')
    
    if [ -n "$issue_number" ]; then
        echo "    ✅ Created Story: Issue #$issue_number"
        STORY_ISSUE_MAP["$story_title"]="$issue_number"
        
        # Link to epic by mentioning it
        gh issue comment "$epic_issue" \
            --repo "$OWNER/$REPO" \
            --body "📋 Linked User Story: #$issue_number - $story_title" 2>/dev/null || true
    else
        echo "    ❌ Failed to create story"
    fi
    
    sleep 1  # Rate limiting
}

# Parse the JSON and create epics and stories
echo "📖 Reading epic-story mapping..."
echo ""

# Process each epic
for epic_num in 1 2 3 4 5; do
    # Get epic data from JSON
    epic_data=$(jq -r ".mappings[] | select(.epic_title | contains(\"Epic $epic_num:\"))" "$MAPPING_FILE")
    
    if [ -n "$epic_data" ]; then
        epic_title=$(echo "$epic_data" | jq -r '.epic_title')
        
        # Create the epic
        create_epic "$epic_title" "$epic_num"
        
        # Create user stories for this epic
        echo "  📋 Creating User Stories for Epic $epic_num..."
        
        story_count=1
        echo "$epic_data" | jq -c '.user_stories[]' | while read -r story; do
            story_title=$(echo "$story" | jq -r '.title')
            create_user_story "$story_title" "Epic $epic_num" "$story_count"
            ((story_count++))
        done
        
        echo ""
    fi
done

echo "✅ Migration completed!"
echo ""
echo "📊 Summary:"
echo "  - Created ${#EPIC_ISSUE_MAP[@]} Epics"
echo "  - Created ${#STORY_ISSUE_MAP[@]} User Stories"
echo ""
echo "📋 Created Epics:"
for epic in "${!EPIC_ISSUE_MAP[@]}"; do
    echo "  - $epic: Issue #${EPIC_ISSUE_MAP[$epic]}"
done
echo ""
echo "💡 Next Steps:"
echo "  1. Create Tasks under each User Story"
echo "  2. Set up dependencies and priorities"
echo "  3. Configure project board columns and automation"
echo ""
echo "📝 Issue mapping has been saved for future reference"

# Save mapping for task creation
cat > /tmp/epic-story-mapping.sh << EOF
#!/bin/bash
# Epic to Issue mapping
declare -A EPIC_ISSUES=(
$(for epic in "${!EPIC_ISSUE_MAP[@]}"; do
    echo "  [\"$epic\"]=\"${EPIC_ISSUE_MAP[$epic]}\""
done)
)

# Story to Issue mapping  
declare -A STORY_ISSUES=(
$(for story in "${!STORY_ISSUE_MAP[@]}"; do
    echo "  [\"$story\"]=\"${STORY_ISSUE_MAP[$story]}\""
done)
)
EOF

echo "✅ Mapping saved to /tmp/epic-story-mapping.sh"