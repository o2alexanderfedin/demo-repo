#!/usr/bin/env bash
set -euo pipefail

# Configuration for Voice Transcription project
OWNER="o2alexanderfedin"
REPO="telethon-architecture-docs"
PROJECT_NUMBER=12
DOC_BASE="https://github.com/o2alexanderfedin/telethon-architecture-docs/blob/main/documentation/voice-transcription-feature"

echo "🔧 Creating Engineering Tasks for Remaining User Stories (Part 2)..."
echo "=================================================================="
echo "This script continues creating tasks for the remaining user stories."
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

# Continue with remaining stories
echo "📋 Creating Engineering Tasks for Remaining User Stories"
echo "======================================================="
echo ""

# Epic 2: User Type Management (continued)
# ========================================

echo "🎯 Epic 2: User Type Management & Quota System (continued)"
echo "---------------------------------------------------------"

# Quota Consumption Management
create_tasks_for_story "Quota Consumption Management" \
"Build quota consumption tracking service" \
"## 📋 Task Overview
Implement a service that accurately tracks quota consumption across all transcription operations.

## 🎯 Objective
Create a reliable tracking service that monitors usage in real-time and prevents quota violations.

## 🔧 Technical Requirements
- Real-time usage tracking
- Atomic quota operations
- Multi-resource tracking
- Usage aggregation
- Quota enforcement hooks

## 📚 Documentation References
- [Quota Tracking](${DOC_BASE}/user-type-architecture.md#quota-tracking)
- [Consumption Management](${DOC_BASE}/technical-architecture.md#quota-consumption)

## ✅ Acceptance Criteria
- [ ] Usage tracked accurately
- [ ] No quota overruns
- [ ] Performance impact minimal
- [ ] Multi-resource support
- [ ] Reports generated
- [ ] Tests comprehensive" \
\
"Implement usage analytics and reporting" \
"## 📋 Task Overview
Create analytics and reporting capabilities for quota usage patterns and trends.

## 🎯 Objective
Build comprehensive analytics that help users understand their usage and administrators plan capacity.

## 🔧 Technical Requirements
- Usage pattern analysis
- Trend identification
- Predictive analytics
- Custom report generation
- Data visualization

## 📚 Documentation References
- [Analytics System](${DOC_BASE}/technical-architecture.md#analytics)
- [Reporting Features](${DOC_BASE}/technical-architecture.md#reporting)

## ✅ Acceptance Criteria
- [ ] Analytics engine functional
- [ ] Reports customizable
- [ ] Visualizations clear
- [ ] Performance optimized
- [ ] Data privacy maintained
- [ ] API documented"

# Usage Prediction and Warnings
create_tasks_for_story "Usage Prediction and Warnings" \
"Develop ML-based usage prediction model" \
"## 📋 Task Overview
Create a machine learning model that predicts future quota usage based on historical patterns.

## 🎯 Objective
Build an accurate prediction system that helps users manage their quotas proactively.

## 🔧 Technical Requirements
- Feature engineering
- Model training pipeline
- Real-time inference
- Model versioning
- Accuracy monitoring

## 📚 Documentation References
- [ML Features](${DOC_BASE}/technical-architecture.md#ml-features)
- [Prediction System](${DOC_BASE}/user-type-architecture.md#usage-prediction)

## ✅ Acceptance Criteria
- [ ] Model accuracy >85%
- [ ] Inference latency <100ms
- [ ] Training pipeline automated
- [ ] Monitoring in place
- [ ] A/B testing enabled
- [ ] Documentation complete" \
\
"Create proactive warning system" \
"## 📋 Task Overview
Implement a warning system that alerts users before they exhaust their quotas.

## 🎯 Objective
Build a proactive notification system that helps users avoid service interruptions.

## 🔧 Technical Requirements
- Warning threshold configuration
- Multi-channel notifications
- Warning escalation
- Snooze capabilities
- Integration with predictions

## 📚 Documentation References
- [Warning System](${DOC_BASE}/user-type-architecture.md#4-user-experience-handlers)
- [Notifications](${DOC_BASE}/technical-architecture.md#notifications)

## ✅ Acceptance Criteria
- [ ] Warnings sent on time
- [ ] Multiple channels work
- [ ] Users can configure thresholds
- [ ] No spam/alert fatigue
- [ ] Integration tested
- [ ] UX optimized"

# Premium User Experience
create_tasks_for_story "Premium User Experience" \
"Design premium feature set and benefits" \
"## 📋 Task Overview
Define and design the premium features and benefits for voice transcription service.

## 🎯 Objective
Create a compelling premium offering that provides clear value over free tier.

## 🔧 Technical Requirements
- Feature differentiation
- Priority processing
- Enhanced limits
- Exclusive features
- Premium support

## 📚 Documentation References
- [Premium Features](${DOC_BASE}/user-type-architecture.md#premium-features)
- [User Tiers](${DOC_BASE}/technical-architecture.md#user-tiers)

## ✅ Acceptance Criteria
- [ ] Feature set defined
- [ ] Value proposition clear
- [ ] Technical feasibility confirmed
- [ ] Pricing model created
- [ ] Migration path defined
- [ ] Documentation complete" \
\
"Implement premium tier infrastructure" \
"## 📋 Task Overview
Build the technical infrastructure to support premium tier features and benefits.

## 🎯 Objective
Create robust infrastructure that delivers premium features reliably and efficiently.

## 🔧 Technical Requirements
- Tier detection logic
- Priority queue implementation
- Enhanced limit enforcement
- Premium feature flags
- Billing integration

## 📚 Documentation References
- [Premium Infrastructure](${DOC_BASE}/technical-architecture.md#premium-tier)
- [Feature Implementation](${DOC_BASE}/technical-architecture.md#feature-flags)

## ✅ Acceptance Criteria
- [ ] Infrastructure deployed
- [ ] Priority processing works
- [ ] Feature flags functional
- [ ] Billing integrated
- [ ] Performance targets met
- [ ] Monitoring complete"

# Error Handling and User Feedback
create_tasks_for_story "Error Handling and User Feedback" \
"Create user-friendly error messages" \
"## 📋 Task Overview
Design and implement clear, actionable error messages for all transcription-related errors.

## 🎯 Objective
Create error messages that help users understand and resolve issues independently.

## 🔧 Technical Requirements
- Error message templates
- Contextual information
- Suggested actions
- Multi-language support
- A/B testing framework

## 📚 Documentation References
- [Error Messages](${DOC_BASE}/technical-architecture.md#error-messages)
- [UX Guidelines](${DOC_BASE}/technical-architecture.md#ux-guidelines)

## ✅ Acceptance Criteria
- [ ] All errors have messages
- [ ] Messages are actionable
- [ ] Localization implemented
- [ ] A/B testing ready
- [ ] User feedback positive
- [ ] Style guide created" \
\
"Build error recovery UI components" \
"## 📋 Task Overview
Create UI components that guide users through error recovery processes.

## 🎯 Objective
Build intuitive recovery flows that minimize user frustration and support tickets.

## 🔧 Technical Requirements
- Recovery flow components
- Progress indicators
- Retry mechanisms
- Help integration
- Analytics tracking

## 📚 Documentation References
- [UI Components](${DOC_BASE}/technical-architecture.md#ui-components)
- [Recovery Flows](${DOC_BASE}/technical-architecture.md#recovery-flows)

## ✅ Acceptance Criteria
- [ ] Components reusable
- [ ] Flows intuitive
- [ ] Progress visible
- [ ] Help accessible
- [ ] Analytics integrated
- [ ] Accessibility compliant"

# Integration with Core Infrastructure
create_tasks_for_story "Integration with Core Infrastructure" \
"Integrate quota system with Telethon core" \
"## 📋 Task Overview
Seamlessly integrate the quota management system with Telethon's core infrastructure.

## 🎯 Objective
Create deep integration that feels native to Telethon while maintaining modularity.

## 🔧 Technical Requirements
- API integration points
- Event system hooks
- Authentication integration
- Session management
- Configuration system

## 📚 Documentation References
- [Integration Guide](${DOC_BASE}/technical-architecture.md#integration-points)
- [Telethon Architecture](${DOC_BASE}/technical-architecture.md#telethon-integration)

## ✅ Acceptance Criteria
- [ ] Integration seamless
- [ ] No breaking changes
- [ ] Performance maintained
- [ ] Events propagated
- [ ] Configuration unified
- [ ] Tests passing" \
\
"Create migration utilities for existing users" \
"## 📋 Task Overview
Build utilities to migrate existing Telethon users to the new quota system.

## 🎯 Objective
Enable smooth migration without disrupting existing user workflows or data.

## 🔧 Technical Requirements
- Data migration scripts
- Rollback capabilities
- Progress tracking
- Validation checks
- Zero-downtime migration

## 📚 Documentation References
- [Migration Guide](${DOC_BASE}/technical-architecture.md#migration)
- [Data Migration](${DOC_BASE}/technical-architecture.md#data-migration)

## ✅ Acceptance Criteria
- [ ] Migration scripts tested
- [ ] Rollback procedures work
- [ ] No data loss
- [ ] Downtime minimized
- [ ] Validation comprehensive
- [ ] Documentation clear"

# Epic 3: High-Level API (continued)
# ==================================

echo -e "\n🎯 Epic 3: High-Level API & Client Integration (continued)"
echo "---------------------------------------------------------"

# Progress Callbacks and Async Patterns
create_tasks_for_story "Progress Callbacks and Async Patterns" \
"Design async/await API patterns" \
"## 📋 Task Overview
Design elegant async/await patterns for voice transcription operations in Telethon.

## 🎯 Objective
Create intuitive async APIs that integrate naturally with Telethon's existing patterns.

## 🔧 Technical Requirements
- Async method signatures
- Promise/Future handling
- Cancellation support
- Progress streaming
- Error propagation

## 📚 Documentation References
- [Async Patterns](${DOC_BASE}/technical-architecture.md#async-patterns)
- [API Design](${DOC_BASE}/technical-architecture.md#api-design)

## ✅ Acceptance Criteria
- [ ] API patterns consistent
- [ ] Cancellation works
- [ ] Progress updates smooth
- [ ] Errors handled properly
- [ ] Documentation clear
- [ ] Examples provided" \
\
"Implement streaming progress updates" \
"## 📋 Task Overview
Build a streaming system for real-time transcription progress updates.

## 🎯 Objective
Create efficient progress streaming that provides granular updates without overwhelming clients.

## 🔧 Technical Requirements
- Stream implementation
- Backpressure handling
- Progress throttling
- Buffer management
- Connection resilience

## 📚 Documentation References
- [Streaming API](${DOC_BASE}/technical-architecture.md#streaming)
- [Progress Updates](${DOC_BASE}/technical-architecture.md#progress-tracking)

## ✅ Acceptance Criteria
- [ ] Streaming efficient
- [ ] Backpressure handled
- [ ] Updates throttled appropriately
- [ ] Memory usage bounded
- [ ] Resilience tested
- [ ] Performance optimized"

# Batch Transcription Support
create_tasks_for_story "Batch Transcription Support" \
"Design batch processing architecture" \
"## 📋 Task Overview
Create an architecture for efficiently processing multiple voice messages in batches.

## 🎯 Objective
Build a batch processing system that maximizes throughput while maintaining individual request tracking.

## 🔧 Technical Requirements
- Batch request API
- Job orchestration
- Progress aggregation
- Error isolation
- Resource optimization

## 📚 Documentation References
- [Batch Processing](${DOC_BASE}/technical-architecture.md#batch-processing)
- [Job Management](${DOC_BASE}/technical-architecture.md#job-orchestration)

## ✅ Acceptance Criteria
- [ ] Batch API designed
- [ ] Orchestration reliable
- [ ] Progress tracking works
- [ ] Errors isolated
- [ ] Performance optimized
- [ ] Limits enforced" \
\
"Implement parallel processing engine" \
"## 📋 Task Overview
Build a parallel processing engine for batch transcription operations.

## 🎯 Objective
Create an efficient engine that processes multiple transcriptions in parallel while respecting resource limits.

## 🔧 Technical Requirements
- Worker pool management
- Load balancing
- Resource allocation
- Concurrency control
- Performance monitoring

## 📚 Documentation References
- [Parallel Processing](${DOC_BASE}/technical-architecture.md#parallel-processing)
- [Resource Management](${DOC_BASE}/technical-architecture.md#resource-management)

## ✅ Acceptance Criteria
- [ ] Parallel processing works
- [ ] Resources managed properly
- [ ] Load balanced effectively
- [ ] Monitoring comprehensive
- [ ] Performance targets met
- [ ] Stability proven"

# Quality Rating System
create_tasks_for_story "Quality Rating System" \
"Design transcription quality metrics" \
"## 📋 Task Overview
Define comprehensive quality metrics for voice transcription results.

## 🎯 Objective
Create meaningful quality indicators that help users assess transcription reliability.

## 🔧 Technical Requirements
- Confidence score calculation
- Quality dimensions
- Metric aggregation
- Baseline establishment
- Continuous improvement

## 📚 Documentation References
- [Quality Metrics](${DOC_BASE}/technical-architecture.md#quality-metrics)
- [Rating System](${DOC_BASE}/technical-architecture.md#quality-rating)

## ✅ Acceptance Criteria
- [ ] Metrics well-defined
- [ ] Scores meaningful
- [ ] Calculation accurate
- [ ] Baselines established
- [ ] Improvement tracked
- [ ] Documentation clear" \
\
"Build user feedback collection system" \
"## 📋 Task Overview
Implement a system for collecting user feedback on transcription quality.

## 🎯 Objective
Create an unobtrusive feedback system that helps improve transcription quality over time.

## 🔧 Technical Requirements
- Feedback UI components
- Rating storage
- Feedback analytics
- Quality correlation
- Improvement tracking

## 📚 Documentation References
- [Feedback System](${DOC_BASE}/technical-architecture.md#feedback-collection)
- [Quality Improvement](${DOC_BASE}/technical-architecture.md#quality-improvement)

## ✅ Acceptance Criteria
- [ ] Feedback UI intuitive
- [ ] Storage efficient
- [ ] Analytics insightful
- [ ] Correlation proven
- [ ] Improvements measurable
- [ ] Privacy maintained"

echo -e "\n✅ Part 2 complete! Continuing with remaining stories..."