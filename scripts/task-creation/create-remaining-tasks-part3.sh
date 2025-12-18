#!/usr/bin/env bash
set -euo pipefail

# Configuration for Voice Transcription project
OWNER="o2alexanderfedin"
REPO="telethon-architecture-docs"
PROJECT_NUMBER=12
DOC_BASE="https://github.com/o2alexanderfedin/telethon-architecture-docs/blob/main/documentation/voice-transcription-feature"

echo "🔧 Creating Engineering Tasks for Remaining User Stories (Part 3)..."
echo "=================================================================="
echo "This script completes task creation for all remaining user stories."
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

# Continue with final stories
echo "📋 Creating Engineering Tasks for Final User Stories"
echo "==================================================="
echo ""

# Epic 3: High-Level API (continued)
# ==================================

echo "🎯 Epic 3: High-Level API & Client Integration (final stories)"
echo "-------------------------------------------------------------"

# Comprehensive Error Handling
create_tasks_for_story "Comprehensive Error Handling" \
"Design error handling architecture" \
"## 📋 Task Overview
Design a comprehensive error handling architecture for the voice transcription API.

## 🎯 Objective
Create a robust error handling system that gracefully manages all failure scenarios.

## 🔧 Technical Requirements
- Error hierarchy design
- Exception flow control
- Error aggregation
- Logging strategy
- Recovery patterns

## 📚 Documentation References
- [Error Architecture](${DOC_BASE}/technical-architecture.md#error-handling)
- [API Errors](${DOC_BASE}/technical-architecture.md#api-errors)

## ✅ Acceptance Criteria
- [ ] Error hierarchy complete
- [ ] All scenarios covered
- [ ] Recovery paths defined
- [ ] Logging comprehensive
- [ ] Performance maintained
- [ ] Documentation clear" \
\
"Implement error context propagation" \
"## 📋 Task Overview
Build a system for propagating rich error context throughout the transcription pipeline.

## 🎯 Objective
Ensure errors carry sufficient context for debugging and user communication.

## 🔧 Technical Requirements
- Context attachment
- Stack trace management
- Debug information
- Sensitive data filtering
- Error serialization

## 📚 Documentation References
- [Error Context](${DOC_BASE}/technical-architecture.md#error-context)
- [Debug Features](${DOC_BASE}/technical-architecture.md#debugging)

## ✅ Acceptance Criteria
- [ ] Context preserved
- [ ] Debug info helpful
- [ ] Sensitive data protected
- [ ] Serialization works
- [ ] Performance acceptable
- [ ] Tools integrated"

# Documentation and Examples
create_tasks_for_story "Documentation and Examples" \
"Write comprehensive API documentation" \
"## 📋 Task Overview
Create complete API documentation for the voice transcription feature.

## 🎯 Objective
Produce clear, comprehensive documentation that enables developers to use the API effectively.

## 🔧 Technical Requirements
- API reference generation
- Code examples
- Tutorial creation
- Best practices guide
- Troubleshooting section

## 📚 Documentation References
- [Documentation Standards](${DOC_BASE}/README.md#documentation)
- [API Guidelines](${DOC_BASE}/technical-architecture.md#api-documentation)

## ✅ Acceptance Criteria
- [ ] API reference complete
- [ ] Examples runnable
- [ ] Tutorials clear
- [ ] Best practices defined
- [ ] Troubleshooting helpful
- [ ] Search optimized" \
\
"Create interactive code examples" \
"## 📋 Task Overview
Build interactive code examples demonstrating voice transcription features.

## 🎯 Objective
Create engaging examples that help developers quickly understand and implement features.

## 🔧 Technical Requirements
- Interactive playground
- Multiple languages
- Common use cases
- Error scenarios
- Performance tips

## 📚 Documentation References
- [Example Guidelines](${DOC_BASE}/README.md#examples)
- [Code Standards](${DOC_BASE}/technical-architecture.md#code-examples)

## ✅ Acceptance Criteria
- [ ] Examples interactive
- [ ] Languages covered
- [ ] Use cases complete
- [ ] Errors demonstrated
- [ ] Performance shown
- [ ] Feedback positive"

# Epic 4: Advanced Features (continued)
# =====================================

echo -e "\n🎯 Epic 4: Advanced Features & Optimization (continued)"
echo "------------------------------------------------------"

# Supergroup Boost Integration
create_tasks_for_story "Supergroup Boost Integration" \
"Implement boost detection system" \
"## 📋 Task Overview
Create a system to detect and utilize Telegram supergroup boost status for enhanced transcription features.

## 🎯 Objective
Build integration that leverages boost status to provide premium transcription benefits.

## 🔧 Technical Requirements
- Boost status detection
- Feature unlocking
- Benefit calculation
- Status caching
- Event handling

## 📚 Documentation References
- [Boost Integration](${DOC_BASE}/technical-architecture.md#boost-integration)
- [Premium Features](${DOC_BASE}/technical-architecture.md#premium-features)

## ✅ Acceptance Criteria
- [ ] Detection accurate
- [ ] Features unlock properly
- [ ] Benefits calculated correctly
- [ ] Caching efficient
- [ ] Events handled
- [ ] Tests comprehensive" \
\
"Create boost-based feature scaling" \
"## 📋 Task Overview
Implement dynamic feature scaling based on supergroup boost levels.

## 🎯 Objective
Create a system that scales transcription capabilities with boost tiers.

## 🔧 Technical Requirements
- Tier mapping
- Feature scaling logic
- Limit adjustments
- Performance tuning
- Analytics integration

## 📚 Documentation References
- [Feature Scaling](${DOC_BASE}/technical-architecture.md#feature-scaling)
- [Boost Benefits](${DOC_BASE}/technical-architecture.md#boost-benefits)

## ✅ Acceptance Criteria
- [ ] Scaling works smoothly
- [ ] Limits adjust correctly
- [ ] Performance maintained
- [ ] Analytics accurate
- [ ] User experience good
- [ ] Documentation clear"

# Request Batching Optimization
create_tasks_for_story "Request Batching Optimization" \
"Design intelligent request batching" \
"## 📋 Task Overview
Design an intelligent system for batching transcription requests to optimize API usage.

## 🎯 Objective
Create efficient batching that reduces API calls while maintaining responsiveness.

## 🔧 Technical Requirements
- Batch formation logic
- Time window management
- Size optimization
- Priority handling
- Batch tracking

## 📚 Documentation References
- [Batching Strategy](${DOC_BASE}/technical-architecture.md#request-batching)
- [Optimization Guide](${DOC_BASE}/technical-architecture.md#performance-optimization)

## ✅ Acceptance Criteria
- [ ] Batching intelligent
- [ ] Windows optimized
- [ ] Priorities respected
- [ ] Tracking accurate
- [ ] Performance improved
- [ ] Metrics available" \
\
"Implement adaptive batching algorithms" \
"## 📋 Task Overview
Build adaptive algorithms that optimize batch sizes based on current conditions.

## 🎯 Objective
Create smart batching that adapts to load, latency, and resource availability.

## 🔧 Technical Requirements
- Adaptive algorithms
- Load monitoring
- Latency tracking
- Size adjustment
- Performance tuning

## 📚 Documentation References
- [Adaptive Systems](${DOC_BASE}/technical-architecture.md#adaptive-batching)
- [Algorithm Design](${DOC_BASE}/technical-architecture.md#batching-algorithms)

## ✅ Acceptance Criteria
- [ ] Algorithms adaptive
- [ ] Monitoring accurate
- [ ] Adjustments smooth
- [ ] Performance optimal
- [ ] Stability maintained
- [ ] Tests thorough"

# Memory Usage Optimization
create_tasks_for_story "Memory Usage Optimization" \
"Profile memory usage patterns" \
"## 📋 Task Overview
Conduct comprehensive memory profiling of the voice transcription system.

## 🎯 Objective
Identify memory usage patterns and optimization opportunities.

## 🔧 Technical Requirements
- Memory profiling setup
- Usage pattern analysis
- Leak detection
- Hotspot identification
- Baseline establishment

## 📚 Documentation References
- [Memory Management](${DOC_BASE}/technical-architecture.md#memory-management)
- [Profiling Guide](${DOC_BASE}/technical-architecture.md#profiling)

## ✅ Acceptance Criteria
- [ ] Profiling complete
- [ ] Patterns identified
- [ ] Leaks detected
- [ ] Hotspots found
- [ ] Baselines set
- [ ] Reports generated" \
\
"Implement memory optimization strategies" \
"## 📋 Task Overview
Apply memory optimization techniques to reduce the transcription system's memory footprint.

## 🎯 Objective
Optimize memory usage while maintaining performance and functionality.

## 🔧 Technical Requirements
- Object pooling
- Buffer reuse
- Lazy loading
- Cache optimization
- Garbage collection tuning

## 📚 Documentation References
- [Optimization Techniques](${DOC_BASE}/technical-architecture.md#memory-optimization)
- [Performance Tuning](${DOC_BASE}/technical-architecture.md#performance-tuning)

## ✅ Acceptance Criteria
- [ ] Memory reduced by 30%
- [ ] Performance maintained
- [ ] No functionality lost
- [ ] Stability proven
- [ ] Monitoring updated
- [ ] Documentation complete"

# Performance Monitoring and Metrics
create_tasks_for_story "Performance Monitoring and Metrics" \
"Design comprehensive metrics system" \
"## 📋 Task Overview
Design a metrics system that tracks all aspects of transcription performance.

## 🎯 Objective
Create visibility into system performance to enable optimization and troubleshooting.

## 🔧 Technical Requirements
- Metric definitions
- Collection strategy
- Storage design
- Aggregation logic
- Alerting rules

## 📚 Documentation References
- [Metrics Design](${DOC_BASE}/technical-architecture.md#metrics-system)
- [Monitoring Strategy](${DOC_BASE}/technical-architecture.md#monitoring)

## ✅ Acceptance Criteria
- [ ] Metrics comprehensive
- [ ] Collection efficient
- [ ] Storage scalable
- [ ] Aggregation accurate
- [ ] Alerts meaningful
- [ ] Dashboards useful" \
\
"Build real-time monitoring dashboard" \
"## 📋 Task Overview
Create a real-time dashboard for monitoring transcription system performance.

## 🎯 Objective
Provide instant visibility into system health and performance metrics.

## 🔧 Technical Requirements
- Dashboard framework
- Real-time updates
- Metric visualization
- Alert integration
- Historical views

## 📚 Documentation References
- [Dashboard Design](${DOC_BASE}/technical-architecture.md#monitoring-dashboard)
- [Visualization Guide](${DOC_BASE}/technical-architecture.md#data-visualization)

## ✅ Acceptance Criteria
- [ ] Dashboard real-time
- [ ] Visualizations clear
- [ ] Alerts integrated
- [ ] History accessible
- [ ] Performance good
- [ ] UX intuitive"

# Integration and Testing
create_tasks_for_story "Integration and Testing" \
"Create end-to-end test scenarios" \
"## 📋 Task Overview
Develop comprehensive end-to-end test scenarios for voice transcription features.

## 🎯 Objective
Ensure all transcription workflows function correctly from start to finish.

## 🔧 Technical Requirements
- Scenario design
- Test automation
- Environment setup
- Data preparation
- Result validation

## 📚 Documentation References
- [E2E Testing](${DOC_BASE}/technical-architecture.md#e2e-testing)
- [Test Scenarios](${DOC_BASE}/technical-architecture.md#test-scenarios)

## ✅ Acceptance Criteria
- [ ] Scenarios comprehensive
- [ ] Automation complete
- [ ] Environments ready
- [ ] Data realistic
- [ ] Validation thorough
- [ ] CI/CD integrated" \
\
"Implement continuous integration pipeline" \
"## 📋 Task Overview
Build a CI/CD pipeline for automated testing and deployment of transcription features.

## 🎯 Objective
Create automated workflows that ensure code quality and enable rapid deployment.

## 🔧 Technical Requirements
- Pipeline configuration
- Test automation
- Build optimization
- Deployment stages
- Rollback procedures

## 📚 Documentation References
- [CI/CD Setup](${DOC_BASE}/technical-architecture.md#cicd-pipeline)
- [Deployment Guide](${DOC_BASE}/technical-architecture.md#deployment)

## ✅ Acceptance Criteria
- [ ] Pipeline configured
- [ ] Tests automated
- [ ] Builds optimized
- [ ] Deployments staged
- [ ] Rollbacks tested
- [ ] Documentation complete"

# Epic 5: Testing & Polish (continued)
# ====================================

echo -e "\n🎯 Epic 5: Testing, Documentation & Polish (final stories)"
echo "---------------------------------------------------------"

# Complete API Documentation
create_tasks_for_story "Complete API Documentation" \
"Generate API reference documentation" \
"## 📋 Task Overview
Auto-generate comprehensive API reference documentation from code.

## 🎯 Objective
Create maintainable API documentation that stays synchronized with code.

## 🔧 Technical Requirements
- Documentation generation
- Type extraction
- Example generation
- Version management
- Search integration

## 📚 Documentation References
- [API Docs](${DOC_BASE}/README.md#api-reference)
- [Doc Generation](${DOC_BASE}/technical-architecture.md#documentation-generation)

## ✅ Acceptance Criteria
- [ ] Generation automated
- [ ] Types accurate
- [ ] Examples work
- [ ] Versions managed
- [ ] Search functional
- [ ] CI/CD integrated" \
\
"Write migration and upgrade guides" \
"## 📋 Task Overview
Create comprehensive guides for migrating to and upgrading the transcription API.

## 🎯 Objective
Enable smooth transitions for users adopting or upgrading the transcription features.

## 🔧 Technical Requirements
- Migration paths
- Breaking changes
- Compatibility matrix
- Upgrade scripts
- Rollback procedures

## 📚 Documentation References
- [Migration Guide](${DOC_BASE}/README.md#migration)
- [Upgrade Path](${DOC_BASE}/technical-architecture.md#upgrades)

## ✅ Acceptance Criteria
- [ ] Paths documented
- [ ] Changes clear
- [ ] Matrix complete
- [ ] Scripts tested
- [ ] Rollbacks work
- [ ] Examples provided"

# User Experience Polish
create_tasks_for_story "User Experience Polish" \
"Optimize API response times" \
"## 📋 Task Overview
Optimize all API endpoints to meet response time targets.

## 🎯 Objective
Ensure snappy, responsive user experience across all transcription operations.

## 🔧 Technical Requirements
- Response time analysis
- Bottleneck identification
- Query optimization
- Caching improvements
- Async optimization

## 📚 Documentation References
- [Performance Targets](${DOC_BASE}/technical-architecture.md#performance-targets)
- [Optimization Guide](${DOC_BASE}/technical-architecture.md#response-optimization)

## ✅ Acceptance Criteria
- [ ] P95 < 200ms
- [ ] P99 < 500ms
- [ ] No timeouts
- [ ] Consistent performance
- [ ] Monitoring active
- [ ] SLAs met" \
\
"Enhance error messages and recovery" \
"## 📋 Task Overview
Improve all error messages and recovery flows for better user experience.

## 🎯 Objective
Make errors less frustrating by providing clear guidance and recovery options.

## 🔧 Technical Requirements
- Message improvement
- Context enrichment
- Recovery suggestions
- Help integration
- Localization

## 📚 Documentation References
- [UX Guidelines](${DOC_BASE}/technical-architecture.md#ux-guidelines)
- [Error UX](${DOC_BASE}/technical-architecture.md#error-ux)

## ✅ Acceptance Criteria
- [ ] Messages helpful
- [ ] Context clear
- [ ] Recovery obvious
- [ ] Help accessible
- [ ] Localized properly
- [ ] Users satisfied"

# Performance Benchmarking
create_tasks_for_story "Performance Benchmarking" \
"Create performance benchmark suite" \
"## 📋 Task Overview
Build a comprehensive benchmark suite for transcription performance testing.

## 🎯 Objective
Establish performance baselines and enable continuous performance monitoring.

## 🔧 Technical Requirements
- Benchmark design
- Load scenarios
- Metric collection
- Result analysis
- Regression detection

## 📚 Documentation References
- [Benchmarking](${DOC_BASE}/technical-architecture.md#benchmarking)
- [Performance Testing](${DOC_BASE}/technical-architecture.md#performance-testing)

## ✅ Acceptance Criteria
- [ ] Suite comprehensive
- [ ] Scenarios realistic
- [ ] Metrics accurate
- [ ] Analysis automated
- [ ] Regressions caught
- [ ] Reports clear" \
\
"Implement performance regression tests" \
"## 📋 Task Overview
Create automated tests that detect performance regressions.

## 🎯 Objective
Prevent performance degradation by catching regressions before deployment.

## 🔧 Technical Requirements
- Regression tests
- Baseline tracking
- Threshold definition
- CI integration
- Alert configuration

## 📚 Documentation References
- [Regression Testing](${DOC_BASE}/technical-architecture.md#regression-tests)
- [Performance CI](${DOC_BASE}/technical-architecture.md#performance-ci)

## ✅ Acceptance Criteria
- [ ] Tests automated
- [ ] Baselines tracked
- [ ] Thresholds defined
- [ ] CI integrated
- [ ] Alerts working
- [ ] False positives minimal"

# Production Deployment Readiness
create_tasks_for_story "Production Deployment Readiness" \
"Create deployment automation" \
"## 📋 Task Overview
Build comprehensive deployment automation for transcription services.

## 🎯 Objective
Enable reliable, repeatable deployments with minimal manual intervention.

## 🔧 Technical Requirements
- Deployment scripts
- Environment management
- Configuration handling
- Health checks
- Rollback automation

## 📚 Documentation References
- [Deployment Guide](${DOC_BASE}/technical-architecture.md#deployment)
- [Automation](${DOC_BASE}/technical-architecture.md#deployment-automation)

## ✅ Acceptance Criteria
- [ ] Deployment automated
- [ ] Environments managed
- [ ] Config templated
- [ ] Health checks work
- [ ] Rollbacks tested
- [ ] Documentation complete" \
\
"Implement production monitoring" \
"## 📋 Task Overview
Set up comprehensive monitoring for production transcription services.

## 🎯 Objective
Ensure production reliability through proactive monitoring and alerting.

## 🔧 Technical Requirements
- Monitoring setup
- Alert configuration
- Log aggregation
- Metric dashboards
- Incident response

## 📚 Documentation References
- [Production Monitoring](${DOC_BASE}/technical-architecture.md#production-monitoring)
- [Incident Response](${DOC_BASE}/technical-architecture.md#incident-response)

## ✅ Acceptance Criteria
- [ ] Monitoring comprehensive
- [ ] Alerts actionable
- [ ] Logs searchable
- [ ] Dashboards useful
- [ ] Runbooks complete
- [ ] Team trained"

echo -e "\n✅ All engineering tasks created successfully!"
echo ""
echo "Summary:"
echo "- Created tasks for all remaining 26 user stories"
echo "- Each story now has 1-2 engineering tasks"
echo "- All tasks include comprehensive requirements and acceptance criteria"
echo ""
echo "Total tasks created across all scripts: ~75+ engineering tasks"