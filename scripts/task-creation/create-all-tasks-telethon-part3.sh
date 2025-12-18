#!/usr/bin/env bash
set -euo pipefail

# Configuration for Voice Transcription project - Updated for Telethon repository
OWNER="o2alexanderfedin"
REPO="Telethon"
PROJECT_NUMBER=12
DOC_BASE="https://github.com/o2alexanderfedin/Telethon/blob/develop/docs/architecture/documentation/voice-transcription-feature"

echo "🔧 Creating Engineering Tasks for Voice Transcription Project (Part 3)..."
echo "========================================================"
echo "This script creates the final set of engineering tasks"
echo "for User Stories in Epic 3 (continued), Epic 4, and Epic 5"
echo ""

# Get project and field IDs once
echo "📋 Initializing project configuration..."
PROJECT_DATA=$(gh api graphql -H "GraphQL-Features: project_v2" \
  --raw-field query='{
      user(login:"'$OWNER'") {
        projectV2(number:'$PROJECT_NUMBER') { 
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
    }')

PROJECT_ID=$(echo "$PROJECT_DATA" | jq -r '.data.user.projectV2.id')
TYPE_FIELD_ID=$(echo "$PROJECT_DATA" | jq -r '.data.user.projectV2.field.id')
TASK_OPTION_ID=$(echo "$PROJECT_DATA" | jq -r '.data.user.projectV2.field.options[] | select(.name == "Task") | .id')

# Get repository ID
REPO_ID=$(gh api graphql \
  --raw-field query='{
      repository(owner:"'$OWNER'", name:"'$REPO'") { id }
    }' \
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
echo "📋 Creating Engineering Tasks for User Stories"
echo "=============================================="
echo ""

# Epic 3: High-Level API & Client Integration (continued)
# =======================================================

echo "🎯 Epic 3: High-Level API & Client Integration (continued)"
echo "---------------------------------------------------------"

# Event System for Transcription Progress
create_tasks_for_story "Event System for Transcription Progress" \
"Design event-driven architecture for progress updates" \
"## 📋 Task Overview
Design and implement a robust event-driven system for real-time transcription progress updates, enabling reactive UI updates and progress monitoring.

## 🎯 Objective
Create a flexible event system that provides granular progress information while maintaining performance and allowing multiple subscribers.

## 🔧 Technical Requirements

### 1. Event Architecture
- **Event Types**
  - TranscriptionStarted
  - TranscriptionProgress
  - TranscriptionCompleted
  - TranscriptionFailed
  - TranscriptionCancelled

- **Event Data**
  - Message reference
  - Progress percentage
  - Time elapsed/remaining
  - Partial results
  - Error information

### 2. Event Bus Design
- **Publishing**
  - Async event emission
  - Ordered delivery
  - Broadcast support
  - Priority levels

- **Subscription**
  - Topic-based filtering
  - Wildcard subscriptions
  - One-time listeners
  - Cleanup mechanisms

### 3. Performance
- **Optimization**
  - Event batching
  - Throttling
  - Debouncing
  - Memory pooling

- **Scalability**
  - Distributed events
  - Event sourcing
  - Replay capability
  - Load balancing

## 📚 Documentation References
- [Event System Design](${DOC_BASE}/technical-architecture.md#3-event-system-integration)
- [Progress Tracking](${DOC_BASE}/technical-architecture.md#progress-tracking)
- [Architecture Patterns](${DOC_BASE}/technical-architecture.md#architecture-patterns)

## ✅ Acceptance Criteria
- [ ] All event types implemented
- [ ] Event delivery guaranteed
- [ ] Performance targets met
- [ ] Memory usage bounded
- [ ] Subscription management works
- [ ] Documentation complete
- [ ] Examples provided
- [ ] Tests comprehensive
- [ ] Monitoring enabled
- [ ] Scalability proven

## 🔍 Testing Considerations
- High-frequency event testing
- Memory leak detection
- Concurrent subscriber testing
- Event ordering verification
- Performance benchmarking" \
\
"Implement WebSocket support for live updates" \
"## 📋 Task Overview
Add WebSocket support to enable real-time transcription progress updates in web applications and other clients requiring live data streams.

## 🎯 Objective
Provide a WebSocket interface for transcription events that is reliable, scalable, and easy to integrate with various client applications.

## 🔧 Technical Requirements

### 1. WebSocket Server
- **Connection Management**
  - Authentication/authorization
  - Connection pooling
  - Heartbeat/keepalive
  - Graceful disconnection

- **Protocol Design**
  - Message format (JSON)
  - Event types mapping
  - Error handling
  - Compression support

### 2. Client Features
- **Subscription Model**
  - Channel-based subscriptions
  - Dynamic subscribe/unsubscribe
  - Filtered event streams
  - Presence detection

- **Reliability**
  - Automatic reconnection
  - Message queuing
  - Delivery acknowledgment
  - Offline support

### 3. Integration
- **API Compatibility**
  - REST fallback
  - Long polling option
  - SSE alternative
  - GraphQL subscriptions

- **Client Libraries**
  - JavaScript SDK
  - Python client
  - Mobile SDKs
  - Example applications

## 📚 Documentation References
- [WebSocket Integration](${DOC_BASE}/technical-architecture.md#websocket-support)
- [Real-time Features](${DOC_BASE}/technical-architecture.md#real-time-updates)
- [Client SDKs](${DOC_BASE}/README.md#client-libraries)

## ✅ Acceptance Criteria
- [ ] WebSocket server stable
- [ ] Authentication secure
- [ ] < 100ms latency
- [ ] 10K concurrent connections
- [ ] Auto-reconnection works
- [ ] Client SDKs functional
- [ ] Documentation complete
- [ ] Examples comprehensive
- [ ] Load tests pass
- [ ] Security audited

## 🔍 Testing Considerations
- Connection limit testing
- Network failure simulation
- Message ordering tests
- Security penetration testing
- Cross-browser compatibility"

# Epic 4: Advanced Features & Optimization
# ========================================

echo -e "\n🎯 Epic 4: Advanced Features & Optimization"
echo "-------------------------------------------"

# Intelligent Caching System
create_tasks_for_story "Intelligent Caching System" \
"Build distributed caching layer" \
"## 📋 Task Overview
Implement a sophisticated distributed caching system for transcription results that reduces API calls and improves response times.

## 🎯 Objective
Create an intelligent caching layer that stores transcription results efficiently while handling cache invalidation and ensuring data consistency.

## 🔧 Technical Requirements

### 1. Cache Architecture
- **Distributed Design**
  - Redis cluster support
  - Consistent hashing
  - Replication strategy
  - Failover handling

- **Cache Layers**
  - Memory cache (L1)
  - Redis cache (L2)
  - CDN integration (L3)
  - Edge caching

### 2. Caching Strategy
- **Storage Optimization**
  - Compression algorithms
  - Binary serialization
  - Partial caching
  - Delta updates

- **Invalidation**
  - TTL-based expiry
  - Event-driven invalidation
  - Cascade invalidation
  - Manual purging

### 3. Intelligence Features
- **Predictive Caching**
  - Usage pattern analysis
  - Preemptive loading
  - Hot data detection
  - Cache warming

- **Adaptive Behavior**
  - Dynamic TTL adjustment
  - Load-based eviction
  - Cost-based caching
  - Quality metrics

## 📚 Documentation References
- [Caching Architecture](${DOC_BASE}/technical-architecture.md#caching-strategy)
- [Performance Optimization](${DOC_BASE}/technical-architecture.md#performance-considerations)
- [Distributed Systems](${DOC_BASE}/technical-architecture.md#distributed-architecture)

## ✅ Acceptance Criteria
- [ ] Cache hit rate >90%
- [ ] Response time <50ms
- [ ] Zero data corruption
- [ ] Failover <1 second
- [ ] Memory efficient
- [ ] Monitoring complete
- [ ] Documentation thorough
- [ ] Load tests pass
- [ ] Security hardened
- [ ] Cost optimized

## 🔍 Testing Considerations
- Cache consistency testing
- Failover simulation
- Performance benchmarking
- Memory pressure testing
- Security audit" \
\
"Implement cache warming strategies" \
"## 📋 Task Overview
Develop intelligent cache warming strategies to preload frequently accessed transcriptions and optimize cold start performance.

## 🎯 Objective
Create a system that predicts and preloads transcription data to minimize cache misses and improve user experience.

## 🔧 Technical Requirements

### 1. Prediction Engine
- **Pattern Analysis**
  - User behavior tracking
  - Access pattern mining
  - Time-based predictions
  - Correlation detection

- **ML Integration**
  - Feature extraction
  - Model training
  - Real-time inference
  - Feedback loop

### 2. Warming Strategies
- **Scheduled Warming**
  - Peak hour preparation
  - Batch processing
  - Priority queuing
  - Resource limiting

- **Triggered Warming**
  - Related content loading
  - User session based
  - Event-driven warming
  - Cascade warming

### 3. Resource Management
- **Optimization**
  - Cost/benefit analysis
  - Resource allocation
  - Bandwidth management
  - Storage limits

- **Monitoring**
  - Warming effectiveness
  - Hit rate improvement
  - Cost tracking
  - Performance metrics

## 📚 Documentation References
- [Cache Warming](${DOC_BASE}/technical-architecture.md#cache-warming)
- [ML Integration](${DOC_BASE}/technical-architecture.md#ml-features)
- [Performance Tuning](${DOC_BASE}/technical-architecture.md#performance-tuning)

## ✅ Acceptance Criteria
- [ ] Prediction accuracy >80%
- [ ] Cache hit improvement >20%
- [ ] Resource usage optimal
- [ ] No service degradation
- [ ] ML models accurate
- [ ] Monitoring dashboards
- [ ] A/B testing enabled
- [ ] Documentation complete
- [ ] Cost controlled
- [ ] Scalable design

## 🔍 Testing Considerations
- Prediction accuracy testing
- Resource limit testing
- A/B test validation
- Performance impact
- Cost analysis"

# External STT Fallback System
create_tasks_for_story "External STT Fallback System" \
"Integrate external STT providers" \
"## 📋 Task Overview
Build a fallback system that seamlessly switches to external Speech-to-Text providers when Telegram's native transcription is unavailable.

## 🎯 Objective
Create a robust multi-provider STT integration that ensures transcription availability while managing costs and maintaining quality.

## 🔧 Technical Requirements

### 1. Provider Integration
- **Supported Providers**
  - Google Cloud STT
  - AWS Transcribe
  - Azure Speech Services
  - OpenAI Whisper API

- **Provider Management**
  - Dynamic selection
  - Load balancing
  - Failover logic
  - Cost optimization

### 2. Fallback Logic
- **Trigger Conditions**
  - API unavailability
  - Quota exhaustion
  - Quality thresholds
  - User preferences

- **Switching Strategy**
  - Seamless transition
  - State preservation
  - Progress mapping
  - Result normalization

### 3. Quality Control
- **Result Processing**
  - Format normalization
  - Confidence mapping
  - Language detection
  - Error handling

- **Quality Metrics**
  - Accuracy comparison
  - Processing time
  - Cost per request
  - User satisfaction

## 📚 Documentation References
- [Fallback System](${DOC_BASE}/technical-architecture.md#fallback-strategies)
- [Provider Integration](${DOC_BASE}/technical-architecture.md#external-providers)
- [Quality Management](${DOC_BASE}/technical-architecture.md#quality-control)

## ✅ Acceptance Criteria
- [ ] 4+ providers integrated
- [ ] Failover <2 seconds
- [ ] Quality maintained
- [ ] Cost tracking works
- [ ] Seamless UX
- [ ] Monitoring complete
- [ ] Documentation thorough
- [ ] Security validated
- [ ] Compliance met
- [ ] Tests comprehensive

## 🔍 Testing Considerations
- Provider failure simulation
- Quality comparison testing
- Cost optimization testing
- Security audit
- Compliance verification" \
\
"Create provider selection algorithm" \
"## 📋 Task Overview
Develop an intelligent algorithm for selecting the optimal STT provider based on multiple factors including cost, quality, and availability.

## 🎯 Objective
Build a decision engine that automatically selects the best provider for each transcription request while optimizing for user-defined priorities.

## 🔧 Technical Requirements

### 1. Decision Factors
- **Performance Metrics**
  - Response time
  - Accuracy scores
  - Language support
  - Feature availability

- **Cost Analysis**
  - Per-minute pricing
  - Volume discounts
  - Budget constraints
  - ROI calculation

### 2. Selection Algorithm
- **Scoring System**
  - Weighted factors
  - Dynamic weights
  - Historical performance
  - Real-time adjustments

- **Optimization**
  - Multi-objective optimization
  - Constraint satisfaction
  - Pareto efficiency
  - Learning feedback

### 3. Configuration
- **User Preferences**
  - Quality vs cost
  - Provider preferences
  - Language priorities
  - Feature requirements

- **Admin Controls**
  - Provider limits
  - Budget caps
  - Override rules
  - A/B testing

## 📚 Documentation References
- [Selection Algorithm](${DOC_BASE}/technical-architecture.md#provider-selection)
- [Optimization Logic](${DOC_BASE}/technical-architecture.md#optimization)
- [Configuration Guide](${DOC_BASE}/README.md#configuration)

## ✅ Acceptance Criteria
- [ ] Algorithm documented
- [ ] Selection <10ms
- [ ] Cost optimized
- [ ] Quality maintained
- [ ] Configurable weights
- [ ] A/B testing ready
- [ ] Monitoring enabled
- [ ] Tests complete
- [ ] Performance verified
- [ ] Documentation clear

## 🔍 Testing Considerations
- Algorithm correctness
- Performance testing
- Cost simulation
- Edge case handling
- Configuration testing"

# Epic 5: Testing, Documentation & Polish
# =======================================

echo -e "\n🎯 Epic 5: Testing, Documentation & Polish"
echo "------------------------------------------"

# Comprehensive Test Coverage
create_tasks_for_story "Comprehensive Test Coverage" \
"Create unit test suite" \
"## 📋 Task Overview
Develop a comprehensive unit test suite that covers all components of the voice transcription feature with high code coverage.

## 🎯 Objective
Build a thorough test suite that ensures reliability, catches regressions early, and serves as living documentation for the codebase.

## 🔧 Technical Requirements

### 1. Test Coverage
- **Component Tests**
  - Schema validation
  - Request handling
  - Event processing
  - Cache operations

- **Coverage Targets**
  - Line coverage >95%
  - Branch coverage >90%
  - Function coverage 100%
  - Integration points

### 2. Test Framework
- **Testing Tools**
  - pytest framework
  - Mock/patch utilities
  - Fixtures library
  - Coverage reporting

- **Test Organization**
  - Logical grouping
  - Shared fixtures
  - Helper utilities
  - Clear naming

### 3. Test Types
- **Unit Tests**
  - Isolated components
  - Edge cases
  - Error conditions
  - Performance bounds

- **Property Tests**
  - Hypothesis framework
  - Invariant testing
  - Fuzzing inputs
  - State machines

## 📚 Documentation References
- [Testing Strategy](${DOC_BASE}/technical-architecture.md#testing-strategy)
- [Test Guidelines](${DOC_BASE}/technical-architecture.md#test-guidelines)
- [Coverage Requirements](${DOC_BASE}/technical-architecture.md#coverage)

## ✅ Acceptance Criteria
- [ ] Coverage targets met
- [ ] All features tested
- [ ] Tests run <2 minutes
- [ ] No flaky tests
- [ ] Mocks appropriate
- [ ] Documentation complete
- [ ] CI/CD integrated
- [ ] Reports generated
- [ ] Examples included
- [ ] Maintainable code

## 🔍 Testing Considerations
- Test isolation
- Mock complexity
- Performance impact
- Maintenance burden
- Documentation clarity" \
\
"Implement integration test suite" \
"## 📋 Task Overview
Create comprehensive integration tests that verify the voice transcription feature works correctly with Telegram's API and Telethon framework.

## 🎯 Objective
Build integration tests that validate end-to-end functionality, API interactions, and system behavior under realistic conditions.

## 🔧 Technical Requirements

### 1. Test Scenarios
- **API Integration**
  - Real API calls
  - Mock server tests
  - Network conditions
  - Error responses

- **End-to-End Flows**
  - Complete transcription
  - Progress tracking
  - Error recovery
  - Quota management

### 2. Test Infrastructure
- **Environment Setup**
  - Test accounts
  - Mock services
  - Data fixtures
  - Cleanup routines

- **Test Execution**
  - Parallel running
  - Dependency management
  - Result collection
  - Failure analysis

### 3. Validation
- **Result Verification**
  - Response accuracy
  - Timing constraints
  - State consistency
  - Side effects

- **Performance Testing**
  - Load simulation
  - Stress testing
  - Memory profiling
  - Resource monitoring

## 📚 Documentation References
- [Integration Testing](${DOC_BASE}/technical-architecture.md#2-integration-tests)
- [Test Environment](${DOC_BASE}/technical-architecture.md#test-environment)
- [E2E Testing](${DOC_BASE}/technical-architecture.md#e2e-tests)

## ✅ Acceptance Criteria
- [ ] All flows tested
- [ ] API mocks complete
- [ ] Tests reliable
- [ ] Performance validated
- [ ] Documentation clear
- [ ] CI/CD integrated
- [ ] Reports detailed
- [ ] Debugging easy
- [ ] Maintenance simple
- [ ] Coverage tracked

## 🔍 Testing Considerations
- API rate limits
- Test data management
- Environment isolation
- Cost management
- Security concerns"

# Security Audit and Hardening
create_tasks_for_story "Security Audit and Hardening" \
"Conduct security vulnerability assessment" \
"## 📋 Task Overview
Perform a comprehensive security audit of the voice transcription feature to identify and address potential vulnerabilities.

## 🎯 Objective
Ensure the transcription feature is secure against common attacks and follows security best practices for handling sensitive audio data.

## 🔧 Technical Requirements

### 1. Security Analysis
- **Vulnerability Scanning**
  - Code analysis
  - Dependency audit
  - OWASP compliance
  - Penetration testing

- **Threat Modeling**
  - Attack vectors
  - Risk assessment
  - Impact analysis
  - Mitigation strategies

### 2. Security Measures
- **Data Protection**
  - Encryption at rest
  - Encryption in transit
  - Key management
  - Access controls

- **API Security**
  - Authentication
  - Authorization
  - Rate limiting
  - Input validation

### 3. Compliance
- **Standards**
  - GDPR compliance
  - Privacy policies
  - Data retention
  - User consent

- **Auditing**
  - Access logs
  - Activity monitoring
  - Incident response
  - Forensics support

## 📚 Documentation References
- [Security Guidelines](${DOC_BASE}/technical-architecture.md#security-considerations)
- [Privacy Compliance](${DOC_BASE}/technical-architecture.md#privacy)
- [Audit Requirements](${DOC_BASE}/technical-architecture.md#auditing)

## ✅ Acceptance Criteria
- [ ] No critical vulnerabilities
- [ ] Encryption implemented
- [ ] Access controls working
- [ ] Compliance documented
- [ ] Audit logs complete
- [ ] Incident plan ready
- [ ] Training provided
- [ ] Tests automated
- [ ] Reviews scheduled
- [ ] Sign-off obtained

## 🔍 Testing Considerations
- Penetration testing
- Vulnerability scanning
- Compliance validation
- Performance impact
- User experience" \
\
"Implement security hardening measures" \
"## 📋 Task Overview
Apply security hardening measures identified during the security audit to protect the voice transcription feature.

## 🎯 Objective
Implement robust security controls that protect user data and prevent unauthorized access while maintaining usability.

## 🔧 Technical Requirements

### 1. Access Control
- **Authentication**
  - Token validation
  - Session management
  - MFA support
  - OAuth integration

- **Authorization**
  - Role-based access
  - Resource permissions
  - API key management
  - Scope limitations

### 2. Data Security
- **Encryption**
  - AES-256 for storage
  - TLS 1.3 for transport
  - Key rotation
  - HSM integration

- **Data Handling**
  - Secure deletion
  - Memory scrubbing
  - Temporary file cleanup
  - Cache security

### 3. Monitoring
- **Security Events**
  - Failed auth attempts
  - Suspicious patterns
  - Anomaly detection
  - Real-time alerts

- **Incident Response**
  - Automated blocking
  - Alert escalation
  - Evidence collection
  - Recovery procedures

## 📚 Documentation References
- [Security Implementation](${DOC_BASE}/technical-architecture.md#security-implementation)
- [Hardening Guide](${DOC_BASE}/technical-architecture.md#hardening)
- [Monitoring Setup](${DOC_BASE}/technical-architecture.md#monitoring)

## ✅ Acceptance Criteria
- [ ] All measures implemented
- [ ] No performance degradation
- [ ] User experience maintained
- [ ] Monitoring active
- [ ] Alerts configured
- [ ] Documentation updated
- [ ] Team trained
- [ ] Tests passing
- [ ] Compliance verified
- [ ] Approval received

## 🔍 Testing Considerations
- Security testing
- Performance testing
- Usability testing
- Monitoring validation
- Incident simulation"

echo -e "\n✅ Part 3 complete! All engineering tasks have been created."
echo ""
echo "This script has created engineering tasks for:"
echo "- Epic 3: High-Level API & Client Integration (completed)"
echo "- Epic 4: Advanced Features & Optimization"
echo "- Epic 5: Testing, Documentation & Polish"
echo ""
echo "All tasks are now created as sub-issues under their parent user stories"
echo "with proper Type field set to 'Task' and linked in the project."