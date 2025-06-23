#!/usr/bin/env bash
set -euo pipefail

# Configuration for Voice Transcription project
OWNER="o2alexanderfedin"
REPO="telethon-architecture-docs"
PROJECT_NUMBER=12
DOC_BASE="https://github.com/o2alexanderfedin/telethon-architecture-docs/blob/main/documentation/voice-transcription-feature"

echo "🔧 Creating Engineering Tasks for Remaining User Stories (Part 1)..."
echo "=================================================================="
echo "This script creates tasks for user stories that were not covered"
echo "in the initial enhanced scripts."
echo ""

# Get project and field IDs once
echo "📋 Initializing project configuration..."
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
TASK_OPTION_ID=$(echo "$PROJECT_DATA" | jq -r '.data.user.projectV2.field.options[] | select(.name == "Task") | .id')

# Get repository ID
REPO_ID=$(gh api graphql -f query='
  query($owner:String!, $repo:String!) {
    repository(owner:$owner, name:$repo) { id }
  }' \
  -F owner="$OWNER" \
  -F repo="$REPO" \
  --jq '.data.repository.id')

echo "✅ Configuration loaded successfully"
echo ""

# Function to get issue number by title
get_issue_number_by_title() {
    local title="$1"
    local issue_num=$(gh api graphql -H "GraphQL-Features: project_v2" \
      -f query='
        query($owner:String!, $projNum:Int!) {
          user(login:$owner) {
            projectV2(number:$projNum) {
              items(first:100) {
                nodes {
                  content {
                    ... on Issue {
                      number
                      title
                    }
                  }
                  fieldValues(first:10) {
                    nodes {
                      ... on ProjectV2ItemFieldSingleSelectValue {
                        name
                        field {
                          ... on ProjectV2SingleSelectField {
                            name
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }' \
      -F owner="$OWNER" \
      -F projNum="$PROJECT_NUMBER" | \
      jq -r --arg title "$title" '.data.user.projectV2.items.nodes[] | 
        select(.content.title == $title and 
               (.fieldValues.nodes[]? | select(.field.name == "Type" and .name == "User Story"))) | 
        .content.number // empty' | head -n1)
    
    echo "$issue_num"
}

# Function to create a task as a sub-issue
add_task() {
    local parent_issue_number="$1"
    local title="$2"
    local body="$3"
    
    echo -n "  📝 Creating task: $title... "
    
    # Step 1: Get parent issue's project item ID
    PARENT_DATA=$(gh api graphql -H "GraphQL-Features: project_v2" \
      -f query='
        query($owner:String!, $repo:String!, $parentNum:Int!) {
          repository(owner:$owner, name:$repo) { 
            issue(number:$parentNum) { 
              id
              title
              projectItems(last:1) { 
                nodes { 
                  id 
                } 
              } 
            }
          }
        }' \
      -F owner="$OWNER" \
      -F repo="$REPO" \
      -F parentNum="$parent_issue_number" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo "❌ Failed to get parent issue data"
        return 1
    fi
    
    PARENT_ISSUE_ID=$(echo "$PARENT_DATA" | jq -r '.data.repository.issue.id // empty')
    PARENT_ITEM_ID=$(echo "$PARENT_DATA" | jq -r '.data.repository.issue.projectItems.nodes[0].id // empty')
    
    if [ -z "$PARENT_ITEM_ID" ]; then
        echo "❌ Parent issue not in project"
        return 1
    fi
    
    # Step 2: Create draft issue in the project
    DRAFT_RESULT=$(gh api graphql -H "GraphQL-Features: project_v2" \
      -f query='
        mutation($projId:ID!, $title:String!, $body:String!) {
          addProjectV2DraftIssue(input:{
            projectId:$projId, 
            title:$title, 
            body:$body
          }) {
            projectItem { 
              id 
            }
          }
        }' \
      -F projId="$PROJECT_ID" \
      -F title="$title" \
      -F body="**Parent Story**: #$parent_issue_number

$body" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo "❌ Failed to create draft"
        return 1
    fi
    
    DRAFT_ITEM_ID=$(echo "$DRAFT_RESULT" | jq -r '.data.addProjectV2DraftIssue.projectItem.id // empty')
    
    # Step 3: Set Type field to Task
    gh api graphql -H "GraphQL-Features: project_v2" \
      -f query='
        mutation($projId:ID!, $itemId:ID!, $fieldId:ID!, $optionId:String!) {
          updateProjectV2ItemFieldValue(input: {
            projectId: $projId,
            itemId: $itemId,
            fieldId: $fieldId,
            value: {
              singleSelectOptionId: $optionId
            }
          }) {
            projectV2Item {
              id
            }
          }
        }' \
      -F projId="$PROJECT_ID" \
      -F itemId="$DRAFT_ITEM_ID" \
      -F fieldId="$TYPE_FIELD_ID" \
      -F optionId="$TASK_OPTION_ID" > /dev/null 2>&1
    
    # Step 4: Convert to repository issue
    CONVERT_RESULT=$(gh api graphql -H "GraphQL-Features: project_v2" \
      -f query='
        mutation($itemId:ID!, $repo:ID!) {
          convertProjectV2DraftIssueItemToIssue(input:{
            itemId: $itemId,
            repositoryId: $repo
          }) {
            item { 
              content { 
                ... on Issue { 
                  number 
                  id 
                } 
              } 
            }
          }
        }' \
      -F itemId="$DRAFT_ITEM_ID" \
      -F repo="$REPO_ID" 2>/dev/null)
    
    NEW_ISSUE_NUMBER=$(echo "$CONVERT_RESULT" | jq -r '.data.convertProjectV2DraftIssueItemToIssue.item.content.number // empty')
    NEW_ISSUE_ID=$(echo "$CONVERT_RESULT" | jq -r '.data.convertProjectV2DraftIssueItemToIssue.item.content.id // empty')
    
    # Step 5: Try to link as sub-issue
    gh api graphql -H "GraphQL-Features: sub_issues" \
      -f query='
        mutation($parentId:ID!, $childId:ID!) {
          addSubIssue(input: {
            issueId: $parentId,
            subIssueId: $childId
          }) {
            issue {
              id
            }
          }
        }' \
      -F parentId="$PARENT_ISSUE_ID" \
      -F childId="$NEW_ISSUE_ID" > /dev/null 2>&1 || true
    
    echo "✅ Created #$NEW_ISSUE_NUMBER"
    sleep 0.5  # Rate limiting
}

# Function to create tasks for a user story
create_tasks_for_story() {
    local story_title="$1"
    shift
    local tasks=("$@")
    
    echo -e "\n▶ User Story: $story_title"
    
    # Get the issue number for this story
    STORY_NUM=$(get_issue_number_by_title "$story_title")
    
    if [ -z "$STORY_NUM" ]; then
        echo "  ⚠️ Could not find issue number for '$story_title', skipping..."
        return
    fi
    
    echo "  📌 Found issue #$STORY_NUM"
    
    # Create each task
    local i=0
    while [ $i -lt ${#tasks[@]} ]; do
        local task_title="${tasks[$i]}"
        local task_body="${tasks[$((i+1))]}"
        add_task "$STORY_NUM" "$task_title" "$task_body"
        i=$((i+2))
    done
}

# Create tasks for user stories
echo "📋 Creating Engineering Tasks for Remaining User Stories"
echo "======================================================="
echo ""

# Epic 1: Core Infrastructure (continued)
# =======================================

echo "🎯 Epic 1: Core Infrastructure & Raw API Support (continued)"
echo "-----------------------------------------------------------"

# Update Handling System
create_tasks_for_story "Update Handling System" \
"Build retry mechanism for failed requests" \
"## 📋 Task Overview
Implement a robust retry mechanism specifically for voice transcription update handling that gracefully recovers from transient failures.

## 🎯 Objective
Create a retry system that handles temporary failures while avoiding unnecessary retries for permanent errors.

## 🔧 Technical Requirements
- Exponential backoff implementation
- Error classification (retryable vs non-retryable)
- Maximum retry limits
- Dead letter queue for failed updates
- Metrics for retry success rates

## 📚 Documentation References
- [Error Handling](${DOC_BASE}/technical-architecture.md#error-handling)
- [Update System](${DOC_BASE}/technical-architecture.md#update-processing-flow)

## ✅ Acceptance Criteria
- [ ] Retry logic implemented with exponential backoff
- [ ] Transient errors properly identified
- [ ] Maximum retry limits enforced
- [ ] Failed updates logged appropriately
- [ ] Performance impact minimal
- [ ] Unit tests cover all retry scenarios"

# Transcription State Management
create_tasks_for_story "Transcription State Management" \
"Design state machine for transcription lifecycle" \
"## 📋 Task Overview
Create a comprehensive state machine that manages the entire lifecycle of voice transcriptions from initiation to completion.

## 🎯 Objective
Build a reliable state management system that tracks transcription progress and handles all possible state transitions.

## 🔧 Technical Requirements
- Define all transcription states
- Implement state transition rules
- Add state validation logic
- Create state persistence layer
- Handle concurrent state updates

## 📚 Documentation References
- [State Management](${DOC_BASE}/technical-architecture.md#state-management)
- [Data Flow](${DOC_BASE}/technical-architecture.md#data-flow)

## ✅ Acceptance Criteria
- [ ] All states clearly defined
- [ ] State transitions validated
- [ ] Concurrent updates handled safely
- [ ] State history tracked
- [ ] Recovery from invalid states
- [ ] Performance optimized" \
\
"Implement state persistence and recovery" \
"## 📋 Task Overview
Build a persistence layer for transcription states that ensures reliability across system restarts and failures.

## 🎯 Objective
Create a robust persistence mechanism that maintains transcription state integrity and enables quick recovery.

## 🔧 Technical Requirements
- Database schema for state storage
- Atomic state updates
- Point-in-time recovery
- State snapshot capabilities
- Cleanup of old states

## 📚 Documentation References
- [Database Design](${DOC_BASE}/technical-architecture.md#database-design)
- [State Persistence](${DOC_BASE}/technical-architecture.md#state-management)

## ✅ Acceptance Criteria
- [ ] State persistence implemented
- [ ] Atomic updates guaranteed
- [ ] Recovery procedures tested
- [ ] Performance targets met
- [ ] Data retention policies enforced
- [ ] Monitoring in place"

# Basic Transcription Manager
create_tasks_for_story "Basic Transcription Manager" \
"Create transcription job queue system" \
"## 📋 Task Overview
Implement a job queue system to manage voice transcription requests efficiently and ensure reliable processing.

## 🎯 Objective
Build a scalable queue system that handles transcription jobs with proper prioritization and error handling.

## 🔧 Technical Requirements
- Queue implementation (Redis/RabbitMQ)
- Priority queue support
- Job retry mechanisms
- Dead letter queue handling
- Queue monitoring and metrics

## 📚 Documentation References
- [Queue Architecture](${DOC_BASE}/technical-architecture.md#queue-system)
- [Job Processing](${DOC_BASE}/technical-architecture.md#job-processing)

## ✅ Acceptance Criteria
- [ ] Queue system operational
- [ ] Priority handling works correctly
- [ ] Failed jobs retry appropriately
- [ ] Monitoring dashboards created
- [ ] Performance meets SLA
- [ ] Documentation complete" \
\
"Implement job scheduling and prioritization" \
"## 📋 Task Overview
Create an intelligent job scheduling system that prioritizes transcription requests based on multiple factors.

## 🎯 Objective
Build a scheduler that optimizes resource usage while ensuring fair processing and meeting user expectations.

## 🔧 Technical Requirements
- Priority algorithm implementation
- User tier consideration
- Resource availability checking
- Dynamic priority adjustment
- Starvation prevention

## 📚 Documentation References
- [Scheduling Logic](${DOC_BASE}/technical-architecture.md#scheduling)
- [Priority System](${DOC_BASE}/technical-architecture.md#prioritization)

## ✅ Acceptance Criteria
- [ ] Scheduler implements all priority rules
- [ ] No job starvation occurs
- [ ] Resource usage optimized
- [ ] User tiers respected
- [ ] Performance metrics collected
- [ ] Testing covers edge cases"

# Automatic Cleanup System
create_tasks_for_story "Automatic Cleanup System" \
"Design cleanup policies and retention rules" \
"## 📋 Task Overview
Design comprehensive cleanup policies for transcription data that balance storage costs with user needs.

## 🎯 Objective
Create flexible retention policies that automatically manage transcription data lifecycle while respecting user preferences.

## 🔧 Technical Requirements
- Configurable retention periods
- User tier-based policies
- Soft delete implementation
- Archive before deletion
- Compliance considerations

## 📚 Documentation References
- [Data Retention](${DOC_BASE}/technical-architecture.md#data-retention)
- [Cleanup Policies](${DOC_BASE}/technical-architecture.md#cleanup)

## ✅ Acceptance Criteria
- [ ] Retention policies defined
- [ ] Configuration system built
- [ ] User preferences respected
- [ ] Compliance requirements met
- [ ] Archive system functional
- [ ] Documentation complete" \
\
"Implement automated cleanup jobs" \
"## 📋 Task Overview
Build automated cleanup jobs that efficiently remove expired transcription data according to defined policies.

## 🎯 Objective
Create reliable cleanup automation that runs without manual intervention while preventing accidental data loss.

## 🔧 Technical Requirements
- Scheduled job implementation
- Batch processing for efficiency
- Dry-run mode support
- Cleanup verification
- Performance optimization

## 📚 Documentation References
- [Cleanup Implementation](${DOC_BASE}/technical-architecture.md#cleanup-jobs)
- [Job Scheduling](${DOC_BASE}/technical-architecture.md#scheduling)

## ✅ Acceptance Criteria
- [ ] Cleanup jobs run on schedule
- [ ] Batch processing efficient
- [ ] No accidental deletions
- [ ] Audit trail maintained
- [ ] Performance impact minimal
- [ ] Monitoring alerts configured"

# Error Handling Framework
create_tasks_for_story "Error Handling Framework" \
"Create comprehensive error taxonomy" \
"## 📋 Task Overview
Develop a detailed error classification system for all possible voice transcription errors.

## 🎯 Objective
Create a structured error taxonomy that enables proper error handling and user communication.

## 🔧 Technical Requirements
- Error code definitions
- Error categorization (user/system/network)
- Severity levels
- Recovery action mapping
- Localization support

## 📚 Documentation References
- [Error Handling](${DOC_BASE}/technical-architecture.md#error-handling)
- [Error Types](${DOC_BASE}/technical-architecture.md#error-taxonomy)

## ✅ Acceptance Criteria
- [ ] All error types catalogued
- [ ] Error codes standardized
- [ ] Recovery actions defined
- [ ] User messages clear
- [ ] Localization ready
- [ ] Documentation complete" \
\
"Implement error recovery strategies" \
"## 📋 Task Overview
Build automated error recovery mechanisms for common transcription failures.

## 🎯 Objective
Create intelligent recovery strategies that minimize user impact and maximize transcription success rates.

## 🔧 Technical Requirements
- Automatic retry logic
- Fallback mechanisms
- Circuit breaker implementation
- Error escalation paths
- Recovery metrics

## 📚 Documentation References
- [Recovery Strategies](${DOC_BASE}/technical-architecture.md#error-recovery)
- [Resilience Patterns](${DOC_BASE}/technical-architecture.md#resilience)

## ✅ Acceptance Criteria
- [ ] Recovery strategies implemented
- [ ] Circuit breakers functional
- [ ] Fallbacks work correctly
- [ ] Metrics show improvement
- [ ] User experience smooth
- [ ] Tests cover failure scenarios"

# Basic Testing Infrastructure
create_tasks_for_story "Basic Testing Infrastructure" \
"Set up testing framework and utilities" \
"## 📋 Task Overview
Establish the foundational testing infrastructure for voice transcription features.

## 🎯 Objective
Create a comprehensive testing framework that supports all types of tests and integrates with CI/CD.

## 🔧 Technical Requirements
- Test framework setup (pytest)
- Mock infrastructure
- Test data generators
- CI/CD integration
- Coverage reporting

## 📚 Documentation References
- [Testing Strategy](${DOC_BASE}/technical-architecture.md#testing-strategy)
- [Test Infrastructure](${DOC_BASE}/technical-architecture.md#test-infrastructure)

## ✅ Acceptance Criteria
- [ ] Testing framework configured
- [ ] Mocking utilities created
- [ ] Test data generation works
- [ ] CI/CD pipeline integrated
- [ ] Coverage reports generated
- [ ] Documentation provided" \
\
"Create test data fixtures and mocks" \
"## 📋 Task Overview
Build comprehensive test fixtures and mocks for voice transcription testing.

## 🎯 Objective
Create realistic test data and mocks that enable thorough testing without external dependencies.

## 🔧 Technical Requirements
- Voice message fixtures
- API response mocks
- User data generators
- Edge case datasets
- Performance test data

## 📚 Documentation References
- [Test Data](${DOC_BASE}/technical-architecture.md#test-data)
- [Mocking Strategy](${DOC_BASE}/technical-architecture.md#mocking)

## ✅ Acceptance Criteria
- [ ] Fixtures cover all scenarios
- [ ] Mocks behave realistically
- [ ] Edge cases included
- [ ] Data generation automated
- [ ] Performance data available
- [ ] Usage documented"

# Epic 2: User Type Management (continued)
# ========================================

echo -e "\n🎯 Epic 2: User Type Management & Quota System (continued)"
echo "---------------------------------------------------------"

# Policy Engine Implementation
create_tasks_for_story "Policy Engine Implementation" \
"Design policy rule engine architecture" \
"## 📋 Task Overview
Design a flexible policy engine that can evaluate complex rules for voice transcription access and quotas.

## 🎯 Objective
Create an extensible rule engine that supports dynamic policy updates and complex conditional logic.

## 🔧 Technical Requirements
- Rule definition language
- Policy evaluation engine
- Rule precedence system
- Dynamic rule loading
- Performance optimization

## 📚 Documentation References
- [Policy Engine](${DOC_BASE}/user-type-architecture.md#3-policy-engine)
- [Rule System](${DOC_BASE}/technical-architecture.md#policy-rules)

## ✅ Acceptance Criteria
- [ ] Rule engine architecture defined
- [ ] Evaluation logic implemented
- [ ] Precedence rules clear
- [ ] Performance targets met
- [ ] Dynamic updates work
- [ ] Tests comprehensive" \
\
"Implement policy enforcement mechanisms" \
"## 📋 Task Overview
Build the enforcement layer that applies policy decisions to transcription requests.

## 🎯 Objective
Create reliable enforcement mechanisms that consistently apply policies across all transcription operations.

## 🔧 Technical Requirements
- Request interception
- Policy evaluation calls
- Decision caching
- Audit logging
- Override capabilities

## 📚 Documentation References
- [Policy Enforcement](${DOC_BASE}/user-type-architecture.md#policy-enforcement)
- [Access Control](${DOC_BASE}/technical-architecture.md#access-control)

## ✅ Acceptance Criteria
- [ ] Enforcement layer complete
- [ ] All requests validated
- [ ] Caching improves performance
- [ ] Audit logs comprehensive
- [ ] Override system secure
- [ ] Integration tested"

echo -e "\n✅ Part 1 complete! Created tasks for Epic 1 and partial Epic 2."
echo "Run create-remaining-tasks-part2.sh to continue with remaining stories."