#!/usr/bin/env bash
set -euo pipefail

# Quick script to create the remaining 6 user stories

OWNER="o2alexanderfedin"
REPO="telethon-architecture-docs"
PROJECT_NUMBER=12
DOC_BASE="https://github.com/o2alexanderfedin/telethon-architecture-docs/blob/main/documentation/voice-transcription-feature"

# Get project configuration
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
USER_STORY_OPTION_ID=$(echo "$PROJECT_DATA" | jq -r '.data.user.projectV2.field.options[] | select(.name == "User Story") | .id')
REPO_ID=$(gh api graphql -f query='query($owner:String!, $repo:String!) { repository(owner:$owner, name:$repo) { id } }' -F owner="$OWNER" -F repo="$REPO" --jq '.data.repository.id')

# Function to create user story
add_user_story() {
    local parent_epic_number="$1"
    local title="$2"
    local body="$3"
    
    echo -n "Creating: $title... "
    
    # Get parent data
    PARENT_DATA=$(gh api graphql -H "GraphQL-Features: project_v2" \
      -f query='query($owner:String!, $repo:String!, $parentNum:Int!) { repository(owner:$owner, name:$repo) { issue(number:$parentNum) { id title projectItems(last:1) { nodes { id } } } } }' \
      -F owner="$OWNER" -F repo="$REPO" -F parentNum="$parent_epic_number" 2>/dev/null)
    
    PARENT_ISSUE_ID=$(echo "$PARENT_DATA" | jq -r '.data.repository.issue.id')
    PARENT_ITEM_ID=$(echo "$PARENT_DATA" | jq -r '.data.repository.issue.projectItems.nodes[0].id')
    PARENT_TITLE=$(echo "$PARENT_DATA" | jq -r '.data.repository.issue.title')
    
    # Create draft
    DRAFT_RESULT=$(gh api graphql -H "GraphQL-Features: project_v2" \
      -f query='mutation($projId:ID!, $title:String!, $body:String!) { addProjectV2DraftIssue(input:{projectId:$projId, title:$title, body:$body}) { projectItem { id } } }' \
      -F projId="$PROJECT_ID" -F title="$title" -F body="**Parent Epic**: #$parent_epic_number - $PARENT_TITLE

$body" 2>/dev/null)
    
    DRAFT_ITEM_ID=$(echo "$DRAFT_RESULT" | jq -r '.data.addProjectV2DraftIssue.projectItem.id')
    
    # Set Type
    gh api graphql -H "GraphQL-Features: project_v2" \
      -f query='mutation($projId:ID!, $itemId:ID!, $fieldId:ID!, $optionId:String!) { updateProjectV2ItemFieldValue(input: {projectId: $projId, itemId: $itemId, fieldId: $fieldId, value: {singleSelectOptionId: $optionId}}) { projectV2Item { id } } }' \
      -F projId="$PROJECT_ID" -F itemId="$DRAFT_ITEM_ID" -F fieldId="$TYPE_FIELD_ID" -F optionId="$USER_STORY_OPTION_ID" > /dev/null 2>&1
    
    # Convert to issue
    CONVERT_RESULT=$(gh api graphql -H "GraphQL-Features: project_v2" \
      -f query='mutation($itemId:ID!, $repo:ID!) { convertProjectV2DraftIssueItemToIssue(input:{itemId: $itemId, repositoryId: $repo}) { item { content { ... on Issue { number id } } } } }' \
      -F itemId="$DRAFT_ITEM_ID" -F repo="$REPO_ID" 2>/dev/null)
    
    NEW_ISSUE_NUMBER=$(echo "$CONVERT_RESULT" | jq -r '.data.convertProjectV2DraftIssueItemToIssue.item.content.number')
    NEW_ISSUE_ID=$(echo "$CONVERT_RESULT" | jq -r '.data.convertProjectV2DraftIssueItemToIssue.item.content.id')
    
    # Link as sub-issue
    gh api graphql -H "GraphQL-Features: sub_issues" \
      -f query='mutation($parentId:ID!, $childId:ID!) { addSubIssue(input: {issueId: $parentId, subIssueId: $childId}) { issue { id } } }' \
      -F parentId="$PARENT_ISSUE_ID" -F childId="$NEW_ISSUE_ID" > /dev/null 2>&1 || true
    
    echo "✅ #$NEW_ISSUE_NUMBER"
    sleep 0.5
}

echo "Creating remaining user stories..."
echo ""

# Epic 5 stories
add_user_story 5 "Comprehensive Test Coverage" \
"## 📋 User Story Overview

As a developer, I need to implement comprehensive test coverage to ensure voice transcription functionality is reliable and maintainable.

## 📚 Documentation
- **Implementation Details**: [View in Technical Architecture](${DOC_BASE}/technical-architecture.md#testing-strategy)

## ✅ Acceptance Criteria

- [ ] Unit test coverage exceeds 90%
- [ ] Integration tests cover all major flows
- [ ] Performance tests establish baselines
- [ ] Security tests pass
- [ ] Documentation includes test guide
- [ ] CI/CD integration complete"

add_user_story 5 "Complete API Documentation" \
"## 📋 User Story Overview

As a developer, I need to create complete API documentation so other developers can easily integrate voice transcription features.

## 📚 Documentation
- **Implementation Details**: [View Documentation](${DOC_BASE}/README.md)

## ✅ Acceptance Criteria

- [ ] API reference is complete
- [ ] Code examples provided
- [ ] Getting started guide written
- [ ] Best practices documented
- [ ] Migration guide included
- [ ] Documentation is searchable"

add_user_story 5 "User Experience Polish" \
"## 📋 User Story Overview

As a developer, I need to polish the user experience to ensure voice transcription is intuitive and responsive.

## 📚 Documentation
- **Implementation Details**: [View in Architecture](${DOC_BASE}/user-type-architecture.md#4-user-experience-handlers)

## ✅ Acceptance Criteria

- [ ] Response times optimized
- [ ] Error messages are helpful
- [ ] Progress indicators work smoothly
- [ ] Accessibility requirements met
- [ ] User feedback incorporated
- [ ] Performance feels snappy"

add_user_story 5 "Performance Benchmarking" \
"## 📋 User Story Overview

As a developer, I need to establish performance benchmarks to ensure voice transcription meets performance requirements.

## 📚 Documentation
- **Implementation Details**: [View in Architecture](${DOC_BASE}/technical-architecture.md#3-performance-tests)

## ✅ Acceptance Criteria

- [ ] Benchmark suite created
- [ ] Baselines established
- [ ] Performance targets defined
- [ ] Regression detection works
- [ ] Reports generated automatically
- [ ] Optimization opportunities identified"

add_user_story 5 "Security Audit and Hardening" \
"## 📋 User Story Overview

As a developer, I need to conduct security audit and implement hardening measures to ensure voice transcription is secure.

## 📚 Documentation
- **Implementation Details**: [View in Architecture](${DOC_BASE}/technical-architecture.md#security-considerations)

## ✅ Acceptance Criteria

- [ ] Security audit completed
- [ ] Vulnerabilities addressed
- [ ] Input validation implemented
- [ ] Authentication secure
- [ ] Data encryption working
- [ ] Compliance requirements met"

add_user_story 5 "Production Deployment Readiness" \
"## 📋 User Story Overview

As a developer, I need to ensure production deployment readiness so voice transcription can be reliably deployed.

## 📚 Documentation
- **Implementation Details**: [View Report](${DOC_BASE}/feasibility-report.md)

## ✅ Acceptance Criteria

- [ ] Deployment automation ready
- [ ] Monitoring configured
- [ ] Runbooks written
- [ ] Rollback procedures tested
- [ ] Performance validated
- [ ] Documentation complete"

echo ""
echo "✅ All user stories created successfully!"