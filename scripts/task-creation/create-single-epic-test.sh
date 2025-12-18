#!/usr/bin/env bash
set -euo pipefail

# Configuration
OWNER="o2alexanderfedin"
REPO="Telethon"
PROJECT_NUMBER=12

echo "🧪 Testing Epic Creation"
echo "========================"
echo ""

# First, let's test if we can create a simple issue
echo "📝 Creating test epic issue..."

gh issue create \
    --repo "$OWNER/$REPO" \
    --title "Epic 1: Core Infrastructure & Raw API Support" \
    --body "Test epic for voice transcription feature" \
    --label "enhancement"

echo "✅ Issue creation completed"