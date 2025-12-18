#!/usr/bin/env bash
set -euo pipefail

# Script to add dependency tracking fields to GitHub Project
# Adds fields for better dependency management and workflow tracking

OWNER="o2alexanderfedin"
PROJECT_NUMBER=12

echo "🔗 Adding Dependency Tracking Fields to GitHub Project..."
echo "====================================================="
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
    }' \
  -F owner="$OWNER" \
  -F projNum="$PROJECT_NUMBER")

PROJECT_ID=$(echo "$PROJECT_DATA" | jq -r '.data.user.projectV2.id')
PROJECT_TITLE=$(echo "$PROJECT_DATA" | jq -r '.data.user.projectV2.title')

echo "✅ Found project: $PROJECT_TITLE"
echo ""

# Function to create a field with options
create_field_with_options() {
    local field_name=$1
    local field_description=$2
    shift 2
    local options=("$@")
    
    echo -n "Creating field '$field_name'... "
    
    # Check if field already exists
    EXISTING_FIELD=$(echo "$PROJECT_DATA" | jq -r --arg name "$field_name" '.data.user.projectV2.fields.nodes[] | select(.name == $name) | .name // empty')
    
    if [ -n "$EXISTING_FIELD" ]; then
        echo "Already exists"
        return 0
    fi
    
    # Build options array for GraphQL
    local options_json="["
    local first=true
    for option in "${options[@]}"; do
        local opt_name=$(echo "$option" | cut -d':' -f1)
        local opt_color=$(echo "$option" | cut -d':' -f2)
        local opt_desc=$(echo "$option" | cut -d':' -f3)
        
        if [ "$first" = false ]; then
            options_json+=", "
        fi
        first=false
        
        options_json+="{name: \"$opt_name\", color: $opt_color, description: \"$opt_desc\"}"
    done
    options_json+="]"
    
    # Create the field with options
    RESPONSE=$(gh api graphql -H "GraphQL-Features: project_v2" \
      -f query="
      mutation {
        createProjectV2Field(input: {
          projectId: \"$PROJECT_ID\"
          dataType: SINGLE_SELECT
          name: \"$field_name\"
          singleSelectOptions: $options_json
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
      }" 2>&1)
    
    if [ $? -eq 0 ]; then
        echo "✅"
        return 0
    else
        if [[ "$RESPONSE" == *"already exists"* ]]; then
            echo "Already exists"
            return 0
        else
            echo "❌ Failed"
            echo "Error: $RESPONSE"
            return 1
        fi
    fi
}

# Function to create a text field
create_text_field() {
    local field_name=$1
    local field_description=$2
    
    echo -n "Creating text field '$field_name'... "
    
    # Check if field already exists
    EXISTING_FIELD=$(echo "$PROJECT_DATA" | jq -r --arg name "$field_name" '.data.user.projectV2.fields.nodes[] | select(.name == $name) | .name // empty')
    
    if [ -n "$EXISTING_FIELD" ]; then
        echo "Already exists"
        return 0
    fi
    
    # Create the text field
    RESPONSE=$(gh api graphql -H "GraphQL-Features: project_v2" \
      -f query="
      mutation {
        createProjectV2Field(input: {
          projectId: \"$PROJECT_ID\"
          dataType: TEXT
          name: \"$field_name\"
        }) {
          projectV2Field {
            ... on ProjectV2Field {
              id
              name
            }
          }
        }
      }" 2>&1)
    
    if [ $? -eq 0 ]; then
        echo "✅"
        return 0
    else
        echo "❌ Failed"
        echo "Error: $RESPONSE"
        return 1
    fi
}

echo "📝 Creating dependency tracking fields..."
echo "======================================="
echo ""

# Dependency Status - tracks if dependencies are satisfied
create_field_with_options "Dependency Status" "Status of dependencies for this item" \
    "Ready:GREEN:All dependencies satisfied, ready to start" \
    "Blocked:RED:Waiting on dependencies to complete" \
    "Partial:YELLOW:Some dependencies satisfied, can start prep work" \
    "Unknown:GRAY:Dependencies not yet analyzed"

# Implementation Phase - based on our analysis
create_field_with_options "Implementation Phase" "Development phase based on dependency analysis" \
    "Phase 1:PURPLE:Foundation - Core Infrastructure" \
    "Phase 2:BLUE:User Management - Quota System" \
    "Phase 3:GREEN:High-Level API - Client Integration" \
    "Phase 4:ORANGE:Advanced Features - Optimization" \
    "Phase 5:RED:Polish - Testing & Production"

# Can Run Parallel - indicates if this can be done alongside other work
create_field_with_options "Parallelization" "Can this work be done in parallel with other stories" \
    "Sequential:RED:Must complete before other work can start" \
    "Parallel:GREEN:Can run alongside other development" \
    "Independent:BLUE:No dependencies on or from other work" \
    "Conditional:YELLOW:Parallel possible with coordination"

# Dependency Risk Level
create_field_with_options "Dependency Risk" "Risk level if this item is delayed" \
    "Critical:RED:Blocks multiple other items" \
    "High:ORANGE:Blocks some important work" \
    "Medium:YELLOW:Minor impact on other work" \
    "Low:GREEN:Minimal or no blocking impact"

# Text field for dependency notes
create_text_field "Dependency Notes" "Free text field for dependency details and notes"

echo ""
echo "📊 Dependency Field Configuration Summary:"
echo "========================================="

# Get updated field list
UPDATED_DATA=$(gh api graphql -H "GraphQL-Features: project_v2" \
  -f query='
    query($owner:String!, $projNum:Int!) {
      user(login:$owner) {
        projectV2(number:$projNum) { 
          fields(first: 25) {
            nodes {
              ... on ProjectV2SingleSelectField {
                id
                name
                options {
                  id
                  name
                }
              }
              ... on ProjectV2Field {
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
echo "📋 Dependency-related fields:"
echo "$UPDATED_DATA" | jq -r '.data.user.projectV2.fields.nodes[] | select(.name | test("Dependency|Phase|Parallel|Risk")) | if .options then "  ✅ \(.name): \(.options | map(.name) | join(", "))" else "  ✅ \(.name): Text field" end'

echo ""
echo "💡 Usage Recommendations:"
echo "========================"
echo ""
echo "1. **Dependency Status**: Update as dependencies complete"
echo "   - Set to 'Blocked' for items waiting on others"
echo "   - Change to 'Ready' when all dependencies satisfied"
echo ""
echo "2. **Implementation Phase**: Assign based on analysis document"
echo "   - Phase 1: Foundation items (Epic 1)"
echo "   - Phase 2: User management (Epic 2)" 
echo "   - Phase 3: High-level API (Epic 3)"
echo "   - Phase 4: Advanced features (Epic 4)"
echo "   - Phase 5: Testing & polish (Epic 5)"
echo ""
echo "3. **Parallelization**: Mark parallel opportunities"
echo "   - 'Sequential' for blocking items"
echo "   - 'Parallel' for items that can run alongside others"
echo ""
echo "4. **Dependency Risk**: Identify critical path items"
echo "   - 'Critical' for foundation items that block everything"
echo "   - Lower risk for optional features"
echo ""
echo "5. **Dependency Notes**: Document specific dependencies"
echo "   - List specific issue numbers this depends on"
echo "   - Note integration points and handoff requirements"
echo ""
echo "✅ Dependency tracking fields ready!"
echo ""
echo "Next steps:"
echo "1. Populate fields for all user stories based on analysis"
echo "2. Create views filtered by Dependency Status and Phase"
echo "3. Set up automation to update Dependency Status"
echo "4. Use for sprint planning and resource allocation"