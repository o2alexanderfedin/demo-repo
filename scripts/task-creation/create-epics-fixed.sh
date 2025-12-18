#!/usr/bin/env bash
set -euo pipefail

# Configuration for Telethon repository
OWNER="o2alexanderfedin"
REPO="Telethon"
PROJECT_NUMBER=12
PROJECT_NAME="Voice Transcription Scrum"
DOC_BASE="https://github.com/o2alexanderfedin/Telethon/blob/develop/docs/architecture/documentation/voice-transcription-feature"

echo "🚀 Creating Epics for Voice Transcription in Telethon Repository"
echo "================================================================"
echo "Repository: $OWNER/$REPO"
echo "Project: $PROJECT_NAME (#$PROJECT_NUMBER)"
echo ""

# Keep track of created epics
declare -a EPIC_NUMBERS

# Function to create an epic
create_epic() {
    local epic_num="$1"
    local title="$2"
    local analysis_doc="$3"
    local technical_doc="$4"
    local additional_docs="$5"
    
    echo "📝 Creating Epic $epic_num: $title"
    
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

### 📋 Epic Number: $epic_num

---
*Created as part of Voice Transcription feature migration to Telethon repository*"

    # Create the issue and capture the URL
    local issue_url=$(gh issue create \
        --repo "$OWNER/$REPO" \
        --title "$title" \
        --body "$body" \
        --label "enhancement,voice-transcription" \
        --project "$PROJECT_NAME" 2>&1)
    
    # Extract issue number from URL
    local issue_number=$(echo "$issue_url" | grep -o '[0-9]*$')
    
    if [ -n "$issue_number" ]; then
        echo "✅ Created Issue #$issue_number"
        EPIC_NUMBERS[$epic_num]=$issue_number
        
        # Update issue title to include epic number for easy reference
        gh issue edit "$issue_number" \
            --repo "$OWNER/$REPO" \
            --title "[Epic $epic_num] $title" 2>/dev/null || true
    else
        echo "❌ Failed to create epic"
        echo "Output: $issue_url"
    fi
    
    echo ""
    sleep 1  # Rate limiting
}

# Create all 5 epics
create_epic 1 \
    "Core Infrastructure & Raw API Support" \
    "epic1-analysis.md" \
    "technical-architecture.md#core-infrastructure" \
    "- **Sprint Plan**: [View Sprint 1 Plan]($DOC_BASE/sprint-1-plan.md)"

create_epic 2 \
    "User Type Management & Quota System" \
    "epic2-analysis.md" \
    "user-type-architecture.md" \
    "- **Rate Limiting**: [View Rate Limiting Docs]($DOC_BASE/technical-architecture.md#rate-limiting-and-quotas)"

create_epic 3 \
    "High-Level API & Client Integration" \
    "epic3-analysis.md" \
    "technical-architecture.md#component-design" \
    "- **API Design**: [View API Design]($DOC_BASE/technical-architecture.md#integration-points)"

create_epic 4 \
    "Advanced Features & Optimization" \
    "epic4-analysis.md" \
    "technical-architecture.md#performance-considerations" \
    "- **Caching Strategy**: [View Caching Docs]($DOC_BASE/technical-architecture.md#3-caching-strategy)"

create_epic 5 \
    "Testing, Documentation & Polish" \
    "epic5-analysis.md" \
    "technical-architecture.md#testing-strategy" \
    "- **Feature Overview**: [View README]($DOC_BASE/README.md)"

echo "✅ Epic creation completed!"
echo ""
echo "📊 Created Epics:"
for i in {1..5}; do
    if [ -n "${EPIC_NUMBERS[$i]:-}" ]; then
        echo "  - Epic $i: Issue #${EPIC_NUMBERS[$i]}"
    fi
done

echo ""
echo "📝 Saving epic mapping for user story creation..."
# Save epic numbers for use in user story creation
cat > /tmp/epic-mapping.sh << EOF
# Epic number to issue number mapping
declare -A EPIC_ISSUES=(
$(for i in {1..5}; do
    if [ -n "${EPIC_NUMBERS[$i]:-}" ]; then
        echo "  [$i]=\"${EPIC_NUMBERS[$i]}\""
    fi
done)
)
EOF

echo "✅ Epic mapping saved to /tmp/epic-mapping.sh"
echo ""
echo "Next steps:"
echo "1. Run the user story creation script"
echo "2. The script will link stories to these epics"