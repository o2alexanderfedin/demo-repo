#!/bin/bash

# create-scrum-project-complete.sh
# Creates and fully configures a new GitHub Project with Scrum setup
# Usage: ./create-scrum-project-complete.sh "Project Name" [--org organization] [--add-issues]

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/project-creation-$(date +%Y%m%d-%H%M%S).log"

# Function to log messages
log() {
    echo "$1" | tee -a "$LOG_FILE"
}

# Function to log colored messages
log_color() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

# Check if project name is provided
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <project-name> [options]"
    echo ""
    echo "Options:"
    echo "  --org <organization>  Create project in organization (default: user account)"
    echo "  --add-issues         Add existing repository issues to project"
    echo "  --skip-fields        Skip custom field creation"
    echo "  --skip-views         Skip view configuration"
    echo ""
    echo "Examples:"
    echo "  $0 'Sprint Planning'"
    echo "  $0 'Team Sprint' --org myorg --add-issues"
    exit 1
fi

PROJECT_NAME="$1"
shift

# Parse options
ORG_NAME=""
OWNER_TYPE="user"
ADD_ISSUES=false
SKIP_FIELDS=false
SKIP_VIEWS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --org)
            ORG_NAME="$2"
            OWNER_TYPE="organization"
            shift 2
            ;;
        --add-issues)
            ADD_ISSUES=true
            shift
            ;;
        --skip-fields)
            SKIP_FIELDS=true
            shift
            ;;
        --skip-views)
            SKIP_VIEWS=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Determine owner
if [ "$OWNER_TYPE" = "organization" ]; then
    OWNER="$ORG_NAME"
    log_color "${BLUE}Creating project in organization: $OWNER${NC}"
else
    OWNER=$(gh api user --jq .login)
    log_color "${BLUE}Creating project in user account: $OWNER${NC}"
fi

log_color "${YELLOW}Creating new Scrum project: $PROJECT_NAME${NC}"
log ""

# Step 1: Create the project
log_color "${YELLOW}Step 1: Creating project...${NC}"

if [ "$OWNER_TYPE" = "organization" ]; then
    PROJECT_RESPONSE=$(gh project create --title "$PROJECT_NAME" --org "$OWNER" 2>&1)
else
    PROJECT_RESPONSE=$(gh project create --title "$PROJECT_NAME" --owner "$OWNER" 2>&1)
fi

if [ $? -ne 0 ]; then
    log_color "${RED}❌ Failed to create project${NC}"
    log "Error: $PROJECT_RESPONSE"
    exit 1
fi

log_color "${GREEN}✅ Project created successfully${NC}"

# Get the project number by listing recent projects
sleep 1  # Give GitHub a moment to update
PROJECT_LIST=$(gh project list --owner "$OWNER" --limit 1)
PROJECT_NUMBER=$(echo "$PROJECT_LIST" | head -n1 | awk '{print $1}')
PROJECT_TITLE=$(echo "$PROJECT_LIST" | head -n1 | cut -f2)

if [ -z "$PROJECT_NUMBER" ] || [ "$PROJECT_TITLE" != "$PROJECT_NAME" ]; then
    log_color "${RED}❌ Could not find the created project${NC}"
    exit 1
fi

log_color "${GREEN}✅ Found project #$PROJECT_NUMBER${NC}"

# Function to get project ID
get_project_id() {
    if [ "$OWNER_TYPE" = "organization" ]; then
        gh api graphql -f query="
        query {
          organization(login: \"$OWNER\") {
            projectV2(number: $PROJECT_NUMBER) {
              id
            }
          }
        }" --jq '.data.organization.projectV2.id'
    else
        gh api graphql -f query="
        query {
          user(login: \"$OWNER\") {
            projectV2(number: $PROJECT_NUMBER) {
              id
            }
          }
        }" --jq '.data.user.projectV2.id'
    fi
}

# Get project ID
echo -n "Getting project ID... "
PROJECT_ID=$(get_project_id)
if [ -z "$PROJECT_ID" ]; then
    log_color "${RED}❌ Failed to get project ID${NC}"
    exit 1
fi
log_color "${GREEN}✅${NC}"

# Step 2: Add custom fields
if [ "$SKIP_FIELDS" = false ]; then
    log ""
    log_color "${YELLOW}Step 2: Adding custom fields...${NC}"
    
    # Function to create a field with options
    create_field_with_options() {
        local field_name=$1
        local field_description=$2
        shift 2
        local options=("$@")
        
        echo -n "Creating field '$field_name'... "
        
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
        RESPONSE=$(gh api graphql -f query="
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
              }
            }
          }
        }" 2>&1)
        
        if [ $? -eq 0 ]; then
            log_color "${GREEN}✅${NC}"
            return 0
        else
            if [[ "$RESPONSE" == *"already exists"* ]]; then
                log_color "${YELLOW}Already exists${NC}"
                return 0
            else
                log_color "${RED}❌ Failed${NC}"
                log "Error: $RESPONSE"
                return 1
            fi
        fi
    }
    
    # Create standard Scrum fields
    create_field_with_options "Type" "Issue type classification" \
        "Epic:PURPLE:High-level feature or initiative" \
        "User Story:GREEN:User-facing functionality" \
        "Spike:YELLOW:Research or investigation task" \
        "Bug:RED:Defect or issue to fix" \
        "Task:BLUE:Technical or maintenance task"
    
    create_field_with_options "Priority" "Issue priority level" \
        "High:RED:Critical or urgent" \
        "Medium:YELLOW:Important but not urgent" \
        "Low:GREEN:Nice to have"
    
    create_field_with_options "Sprint" "Sprint assignment" \
        "Sprint 1:BLUE:First sprint" \
        "Sprint 2:BLUE:Second sprint" \
        "Sprint 3:BLUE:Third sprint" \
        "Backlog:GRAY:Not assigned to sprint"
    
    create_field_with_options "Story Points" "Effort estimation" \
        "1:GREEN:Very small task" \
        "2:GREEN:Small task" \
        "3:YELLOW:Medium task" \
        "5:YELLOW:Large task" \
        "8:ORANGE:Very large task" \
        "13:RED:Huge task"
    
    create_field_with_options "Dependency Status" "Status of dependencies for this item" \
        "Ready:GREEN:All dependencies satisfied, ready to start" \
        "Blocked:RED:Waiting on dependencies to complete" \
        "Partial:YELLOW:Some dependencies satisfied, can start prep work" \
        "Unknown:GRAY:Dependencies not yet analyzed"
    
    create_field_with_options "Implementation Phase" "Development phase based on dependency analysis" \
        "Phase 1:PURPLE:Foundation - Core Infrastructure" \
        "Phase 2:BLUE:User Management - Quota System" \
        "Phase 3:GREEN:High-Level API - Client Integration" \
        "Phase 4:ORANGE:Advanced Features - Optimization" \
        "Phase 5:RED:Polish - Testing & Production"
    
    create_field_with_options "Parallelization" "Can this work be done in parallel with other stories" \
        "Sequential:RED:Must complete before other work can start" \
        "Parallel:GREEN:Can run alongside other development" \
        "Independent:BLUE:No dependencies on or from other work" \
        "Conditional:YELLOW:Parallel possible with coordination"
    
    create_field_with_options "Dependency Risk" "Risk level if this item is delayed" \
        "Critical:RED:Blocks multiple other items" \
        "High:ORANGE:Blocks some important work" \
        "Medium:YELLOW:Minor impact on other work" \
        "Low:GREEN:Minimal or no blocking impact"
else
    log_color "${YELLOW}Step 2: Skipping field creation (--skip-fields)${NC}"
fi

# Step 3: Configure views
if [ "$SKIP_VIEWS" = false ]; then
    log ""
    log_color "${YELLOW}Step 3: Configuring project views...${NC}"
    
    # Get the default view ID
    echo -n "Getting default view... "
    DEFAULT_VIEW=$(gh api graphql -f query="
    query {
      node(id: \"$PROJECT_ID\") {
        ... on ProjectV2 {
          views(first: 1) {
            nodes {
              id
              name
            }
          }
        }
      }
    }" --jq '.data.node.views.nodes[0].id')
    log_color "${GREEN}✅${NC}"
    
    # Update the default view name to "Board"
    echo -n "Renaming default view to 'Board'... "
    gh api graphql -f query="
    mutation {
      updateProjectV2View(input: {
        viewId: \"$DEFAULT_VIEW\"
        name: \"Board\"
      }) {
        projectV2View {
          id
          name
        }
      }
    }" > /dev/null 2>&1
    log_color "${GREEN}✅${NC}"
    
    # Create additional views
    create_view() {
        local view_name=$1
        local layout=$2
        echo -n "Creating '$view_name' view... "
        RESPONSE=$(gh api graphql -f query="
        mutation {
          createProjectV2View(input: {
            projectId: \"$PROJECT_ID\"
            name: \"$view_name\"
            layout: $layout
          }) {
            projectV2View {
              id
              name
            }
          }
        }" 2>&1)
        
        if [ $? -eq 0 ]; then
            log_color "${GREEN}✅${NC}"
        else
            log_color "${RED}❌ Failed${NC}"
        fi
    }
    
    create_view "Backlog" "TABLE"
    create_view "Sprint Planning" "TABLE"
    create_view "Current Sprint" "BOARD"
    create_view "Roadmap" "ROADMAP"
else
    log_color "${YELLOW}Step 3: Skipping view configuration (--skip-views)${NC}"
fi

# Step 4: Add existing issues to project (optional)
if [ "$ADD_ISSUES" = true ]; then
    log ""
    log_color "${YELLOW}Step 4: Adding repository issues to project...${NC}"
    
    REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)
    if [ -z "$REPO" ]; then
        log_color "${YELLOW}⚠️  Not in a repository directory, skipping issue addition${NC}"
    else
        REPO_OWNER=$(echo $REPO | cut -d'/' -f1)
        REPO_NAME=$(echo $REPO | cut -d'/' -f2)
        
        # Function to add issue to project
        add_issue_to_project() {
            local issue_number=$1
            
            # Get issue ID
            ISSUE_ID=$(gh api graphql -f query="
            query {
              repository(owner: \"$REPO_OWNER\", name: \"$REPO_NAME\") {
                issue(number: $issue_number) {
                  id
                }
              }
            }" --jq '.data.repository.issue.id' 2>/dev/null)
            
            if [ -z "$ISSUE_ID" ]; then
                return 1
            fi
            
            # Add to project
            gh api graphql -f query="
            mutation {
              addProjectV2ItemById(input: {
                projectId: \"$PROJECT_ID\"
                contentId: \"$ISSUE_ID\"
              }) {
                item {
                  id
                }
              }
            }" > /dev/null 2>&1
            
            return $?
        }
        
        # Get all open issues
        echo -n "Fetching open issues... "
        ISSUE_NUMBERS=$(gh issue list --state open --limit 100 --json number --jq '.[].number')
        ISSUE_COUNT=$(echo "$ISSUE_NUMBERS" | wc -l | tr -d ' ')
        log_color "${GREEN}Found $ISSUE_COUNT issues${NC}"
        
        # Add each issue
        ADDED=0
        FAILED=0
        for issue_num in $ISSUE_NUMBERS; do
            echo -n "Adding issue #$issue_num... "
            if add_issue_to_project $issue_num; then
                log_color "${GREEN}✅${NC}"
                ADDED=$((ADDED + 1))
            else
                log_color "${RED}❌${NC}"
                FAILED=$((FAILED + 1))
            fi
        done
        
        log_color "${GREEN}Added $ADDED issues to project${NC}"
        if [ $FAILED -gt 0 ]; then
            log_color "${YELLOW}Failed to add $FAILED issues${NC}"
        fi
    fi
else
    log_color "${YELLOW}Step 4: Skipping issue addition (use --add-issues to enable)${NC}"
fi

# Step 5: Configure automation suggestions
log ""
log_color "${YELLOW}Step 5: Automation setup...${NC}"
log_color "${YELLOW}⚠️  GitHub Project automation must be configured manually${NC}"
log ""
log "Recommended automations:"
log "1. Auto-add items with 'Epic' or 'User Story' labels"
log "2. Auto-move items to 'Done' when issues are closed"
log "3. Auto-move items to 'In Progress' when a PR is opened"
log "4. Auto-archive items after 2 weeks in 'Done'"
log "5. Update 'Dependency Status' to 'Ready' when blocking issues are closed"

# Save project configuration
CONFIG_FILE="$SCRIPT_DIR/project-$PROJECT_NUMBER-config.json"
cat > "$CONFIG_FILE" << EOF
{
  "project_name": "$PROJECT_NAME",
  "project_number": $PROJECT_NUMBER,
  "project_id": "$PROJECT_ID",
  "owner": "$OWNER",
  "owner_type": "$OWNER_TYPE",
  "created_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "repository": "${REPO:-"N/A"}",
  "configuration": {
    "fields": [
      {"name": "Type", "type": "single_select", "options": ["Epic", "User Story", "Spike", "Bug", "Task"]},
      {"name": "Priority", "type": "single_select", "options": ["High", "Medium", "Low"]},
      {"name": "Sprint", "type": "single_select", "options": ["Sprint 1", "Sprint 2", "Sprint 3", "Backlog"]},
      {"name": "Story Points", "type": "single_select", "options": ["1", "2", "3", "5", "8", "13"]},
      {"name": "Dependency Status", "type": "single_select", "options": ["Ready", "Blocked", "Partial", "Unknown"]},
      {"name": "Implementation Phase", "type": "single_select", "options": ["Phase 1", "Phase 2", "Phase 3", "Phase 4", "Phase 5"]},
      {"name": "Parallelization", "type": "single_select", "options": ["Sequential", "Parallel", "Independent", "Conditional"]},
      {"name": "Dependency Risk", "type": "single_select", "options": ["Critical", "High", "Medium", "Low"]}
    ],
    "views": ["Board", "Backlog", "Sprint Planning", "Current Sprint", "Roadmap"]
  }
}
EOF

# Final summary
log ""
log_color "${BLUE}=========================================${NC}"
log_color "${GREEN}✅ PROJECT CREATED SUCCESSFULLY!${NC}"
log_color "${BLUE}=========================================${NC}"
log_color "Project Name: ${GREEN}$PROJECT_NAME${NC}"
log_color "Project Number: ${GREEN}#$PROJECT_NUMBER${NC}"
log_color "Owner: ${GREEN}$OWNER${NC}"
log ""
log_color "${YELLOW}Project URL:${NC}"
if [ "$OWNER_TYPE" = "organization" ]; then
    PROJECT_URL="https://github.com/orgs/$OWNER/projects/$PROJECT_NUMBER"
else
    PROJECT_URL="https://github.com/users/$OWNER/projects/$PROJECT_NUMBER"
fi
log "$PROJECT_URL"
log ""
log_color "${YELLOW}Configuration saved to:${NC}"
log "$CONFIG_FILE"
log ""
log_color "${YELLOW}Log file saved to:${NC}"
log "$LOG_FILE"
log ""
log_color "${PURPLE}Next steps:${NC}"
log "1. Visit the project URL to customize the layout"
log "2. Set up automation rules for issue management"
log "3. Configure field visibility and ordering"
log "4. Add team members if needed"
log "5. Start planning your first sprint!"
log_color "${BLUE}=========================================${NC}"

# Open project in browser (optional)
echo ""
read -p "Open project in browser? (y/N) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open "$PROJECT_URL" 2>/dev/null || xdg-open "$PROJECT_URL" 2>/dev/null || echo "Please open: $PROJECT_URL"
fi