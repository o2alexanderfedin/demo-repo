#!/bin/bash

# create-project-only-scrum.sh
# Creates a Scrum project with draft items (no repository issues)
# Usage: ./create-project-only-scrum.sh "Project Name" [--org organization]

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Check if project name is provided
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <project-name> [--org <organization>]"
    echo ""
    echo "This script creates a project with draft items only (no repository issues)"
    echo ""
    echo "Examples:"
    echo "  $0 'Sprint Planning'"
    echo "  $0 'Team Sprint' --org myorg"
    exit 1
fi

PROJECT_NAME="$1"
OWNER_TYPE="user"
OWNER=$(gh api user --jq .login)

# Check for organization flag
if [ "$#" -ge 3 ] && [ "$2" = "--org" ]; then
    OWNER="$3"
    OWNER_TYPE="organization"
fi

echo -e "${BLUE}Creating project-only Scrum board: $PROJECT_NAME${NC}"
echo ""

# Step 1: Create the project
echo -e "${YELLOW}Step 1: Creating project...${NC}"

if [ "$OWNER_TYPE" = "organization" ]; then
    PROJECT_RESPONSE=$(gh project create --title "$PROJECT_NAME" --org "$OWNER" 2>&1)
else
    PROJECT_RESPONSE=$(gh project create --title "$PROJECT_NAME" --owner "$OWNER" 2>&1)
fi

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to create project${NC}"
    echo "Error: $PROJECT_RESPONSE"
    exit 1
fi

echo -e "${GREEN}✅ Project created successfully${NC}"

# Get the project number
sleep 1
PROJECT_LIST=$(gh project list --owner "$OWNER" --limit 1)
PROJECT_NUMBER=$(echo "$PROJECT_LIST" | head -n1 | awk '{print $1}')

echo -e "${GREEN}✅ Found project #$PROJECT_NUMBER${NC}"

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
echo -e "${GREEN}✅${NC}"

# Step 2: Add custom fields
echo ""
echo -e "${YELLOW}Step 2: Adding custom fields...${NC}"

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
        echo -e "${GREEN}✅${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed${NC}"
        return 1
    fi
}

# Create standard Scrum fields
create_field_with_options "Type" "Item type classification" \
    "Epic:PURPLE:High-level feature or initiative" \
    "User Story:GREEN:User-facing functionality" \
    "Task:BLUE:Technical or maintenance task" \
    "Bug:RED:Defect or issue to fix" \
    "Spike:YELLOW:Research or investigation task"

create_field_with_options "Priority" "Priority level" \
    "High:RED:Critical or urgent" \
    "Medium:YELLOW:Important but not urgent" \
    "Low:GREEN:Nice to have"

create_field_with_options "Sprint" "Sprint assignment" \
    "Sprint 1:BLUE:First sprint" \
    "Sprint 2:BLUE:Second sprint" \
    "Sprint 3:BLUE:Third sprint" \
    "Backlog:GRAY:Not assigned to sprint"

create_field_with_options "Story Points" "Effort estimation" \
    "1:GREEN:Very small" \
    "2:GREEN:Small" \
    "3:YELLOW:Medium" \
    "5:YELLOW:Large" \
    "8:ORANGE:Very large" \
    "13:RED:Huge"

# Step 3: Configure views
echo ""
echo -e "${YELLOW}Step 3: Configuring project views...${NC}"

# Get the default view ID and rename to Board
DEFAULT_VIEW=$(gh api graphql -f query="
query {
  node(id: \"$PROJECT_ID\") {
    ... on ProjectV2 {
      views(first: 1) {
        nodes {
          id
        }
      }
    }
  }
}" --jq '.data.node.views.nodes[0].id')

echo -n "Configuring Board view... "
gh api graphql -f query="
mutation {
  updateProjectV2View(input: {
    viewId: \"$DEFAULT_VIEW\"
    name: \"Board\"
  }) {
    projectV2View {
      id
    }
  }
}" > /dev/null 2>&1
echo -e "${GREEN}✅${NC}"

# Create additional views
create_view() {
    local view_name=$1
    local layout=$2
    echo -n "Creating '$view_name' view... "
    gh api graphql -f query="
    mutation {
      createProjectV2View(input: {
        projectId: \"$PROJECT_ID\"
        name: \"$view_name\"
        layout: $layout
      }) {
        projectV2View {
          id
        }
      }
    }" > /dev/null 2>&1
    echo -e "${GREEN}✅${NC}"
}

create_view "Backlog" "TABLE"
create_view "Sprint Planning" "TABLE"
create_view "Current Sprint" "BOARD"

# Step 4: Create sample draft items
echo ""
echo -e "${YELLOW}Step 4: Creating sample draft items...${NC}"

# Function to create a draft item
create_draft_item() {
    local title=$1
    local body=$2
    
    echo -n "Creating: $title... "
    
    ITEM_ID=$(gh api graphql -f query="
    mutation {
      addProjectV2DraftIssue(input: {
        projectId: \"$PROJECT_ID\"
        title: \"$title\"
        body: \"$body\"
      }) {
        projectV2Item {
          id
        }
      }
    }" --jq '.data.addProjectV2DraftIssue.projectV2Item.id' 2>&1)
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅${NC}"
        echo "$ITEM_ID"
    else
        echo -e "${RED}❌${NC}"
        echo ""
    fi
}

# Create sample Epics
echo "Creating sample Epics..."
EPIC1=$(create_draft_item "Epic: User Authentication System" \
"As a product owner, I want a complete user authentication system so that users can securely access the application.

## Acceptance Criteria
- Users can register with email
- Users can login/logout
- Password reset functionality
- Session management")

EPIC2=$(create_draft_item "Epic: Dashboard Analytics" \
"As a product owner, I want comprehensive dashboard analytics so that users can track their key metrics.

## Acceptance Criteria
- Real-time data visualization
- Customizable widgets
- Export functionality
- Mobile responsive")

# Create sample User Stories
echo ""
echo "Creating sample User Stories..."
create_draft_item "User Registration Form" \
"As a new user, I want to register for an account so that I can access the application.

## Acceptance Criteria
- [ ] Email validation
- [ ] Password strength requirements
- [ ] Terms acceptance
- [ ] Confirmation email sent

**Epic**: User Authentication System"

create_draft_item "Login Page Implementation" \
"As a returning user, I want to login to my account so that I can access my data.

## Acceptance Criteria
- [ ] Email/password fields
- [ ] Remember me option
- [ ] Error handling
- [ ] Redirect after login

**Epic**: User Authentication System"

create_draft_item "Analytics Widget Framework" \
"As a developer, I want to create a reusable widget framework so that we can build dashboard components efficiently.

## Acceptance Criteria
- [ ] Base widget component
- [ ] Data binding interface
- [ ] Refresh mechanism
- [ ] Error states

**Epic**: Dashboard Analytics"

# Create sample Tasks
echo ""
echo "Creating sample Tasks..."
create_draft_item "Set up authentication database schema" \
"Create the necessary database tables for user authentication.

## Tasks
- [ ] Users table
- [ ] Sessions table
- [ ] Password reset tokens table
- [ ] Database migrations"

create_draft_item "Implement JWT token service" \
"Create a service for generating and validating JWT tokens.

## Tasks
- [ ] Token generation
- [ ] Token validation
- [ ] Refresh token logic
- [ ] Token expiration handling"

# Summary
echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${GREEN}✅ PROJECT CREATED SUCCESSFULLY!${NC}"
echo -e "${BLUE}=========================================${NC}"
echo -e "Project Name: ${GREEN}$PROJECT_NAME${NC}"
echo -e "Project Number: ${GREEN}#$PROJECT_NUMBER${NC}"
echo -e "Owner: ${GREEN}$OWNER${NC}"
echo ""
echo -e "${YELLOW}Project URL:${NC}"
if [ "$OWNER_TYPE" = "organization" ]; then
    PROJECT_URL="https://github.com/orgs/$OWNER/projects/$PROJECT_NUMBER"
else
    PROJECT_URL="https://github.com/users/$OWNER/projects/$PROJECT_NUMBER"
fi
echo "$PROJECT_URL"
echo ""
echo -e "${PURPLE}What's been created:${NC}"
echo "✓ 4 Custom fields (Type, Priority, Sprint, Story Points)"
echo "✓ 4 Views (Board, Backlog, Sprint Planning, Current Sprint)"
echo "✓ 7 Sample draft items (2 Epics, 3 User Stories, 2 Tasks)"
echo ""
echo -e "${PURPLE}Next steps:${NC}"
echo "1. Visit the project to see your draft items"
echo "2. Configure field values for each item"
echo "3. Organize items into sprints"
echo "4. Add more draft items as needed"
echo "5. Invite team members to collaborate"
echo -e "${BLUE}=========================================${NC}"

# Open project in browser (optional)
echo ""
read -p "Open project in browser? (y/N) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open "$PROJECT_URL" 2>/dev/null || xdg-open "$PROJECT_URL" 2>/dev/null || echo "Please open: $PROJECT_URL"
fi