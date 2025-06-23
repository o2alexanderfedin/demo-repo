#!/usr/bin/env bash
set -euo pipefail

# Configuration for Voice Transcription project
OWNER="o2alexanderfedin"
REPO="telethon-architecture-docs"
PROJECT_NUMBER=12
DOC_BASE="https://github.com/o2alexanderfedin/telethon-architecture-docs/blob/main/documentation/voice-transcription-feature"

echo "🔧 Creating Engineering Tasks for Voice Transcription Project (Part 2)..."
echo "========================================================"
echo "This script continues creating detailed engineering tasks"
echo "for User Stories in Epic 2 and Epic 3"
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
echo "📋 Creating Engineering Tasks for User Stories"
echo "=============================================="
echo ""

# Epic 2: User Type Management & Quota System
# ===========================================

echo "🎯 Epic 2: User Type Management & Quota System"
echo "----------------------------------------------"

# User Type Detection System
create_tasks_for_story "User Type Detection System" \
"Implement user type detection logic" \
"## 📋 Task Overview
Create the core logic for detecting and categorizing Telegram users into different types (free, premium, business) to enable tier-based transcription features.

## 🎯 Objective
Build a reliable user type detection system that accurately identifies user subscription levels and maintains this information efficiently for quota management.

## 🔧 Technical Requirements

### 1. User Type Detection
- **API Integration**
  - Query user premium status from Telegram API
  - Detect business account features
  - Handle API response variations
  - Cache user type information

- **Type Categories**
  - Free users (basic limits)
  - Premium users (enhanced features)
  - Business accounts (highest tier)
  - Special cases (bots, channels)

### 2. Detection Strategies
- **Real-time Detection**
  - Check on first transcription request
  - Periodic re-verification
  - Handle status changes
  - Update notifications

- **Fallback Mechanisms**
  - Handle API failures gracefully
  - Use cached data when available
  - Default to most restrictive tier
  - Manual override support

### 3. Performance Optimization
- **Caching Layer**
  - In-memory cache for active users
  - Persistent cache for offline access
  - TTL-based expiration
  - Cache warming strategies

## 📚 Documentation References
- [User Type Architecture](${DOC_BASE}/user-type-architecture.md#1-user-type-detector)
- [Detection Flow](${DOC_BASE}/user-type-architecture.md#detection-flow)
- [Integration Points](${DOC_BASE}/technical-architecture.md#integration-points)

## ✅ Acceptance Criteria
- [ ] User type detection completes in <50ms
- [ ] All user types correctly identified
- [ ] Cache hit rate exceeds 90%
- [ ] API failures handled gracefully
- [ ] Status changes detected within 5 minutes
- [ ] Memory usage remains bounded
- [ ] Thread-safe implementation
- [ ] Comprehensive logging
- [ ] Unit test coverage >95%
- [ ] Integration tests pass

## 🔍 Testing Considerations
- Test with various user types
- Simulate API failures
- Verify cache behavior
- Test concurrent access
- Performance benchmarking" \
\
"Create user type caching system" \
"## 📋 Task Overview
Implement a sophisticated caching system for user type information that balances performance with data freshness while minimizing API calls.

## 🎯 Objective
Build a multi-layer caching solution that provides fast access to user type data while ensuring information remains current and accurate.

## 🔧 Technical Requirements

### 1. Cache Architecture
- **Multi-Layer Design**
  - L1: In-memory cache (hot data)
  - L2: Redis/persistent cache
  - L3: Database backup
  - Automatic tier promotion

- **Cache Strategies**
  - LRU eviction policy
  - TTL-based expiration
  - Refresh-ahead pattern
  - Write-through updates

### 2. Data Management
- **Cache Operations**
  - Atomic get/set operations
  - Bulk loading support
  - Partial updates
  - Cache invalidation

- **Consistency**
  - Version tracking
  - Conflict resolution
  - Eventual consistency
  - Transaction support

### 3. Performance Features
- **Optimization**
  - Bloom filters for existence checks
  - Compression for large entries
  - Batch operations
  - Async refresh

- **Monitoring**
  - Hit/miss ratios
  - Latency tracking
  - Memory usage
  - Eviction rates

## 📚 Documentation References
- [Caching Strategy](${DOC_BASE}/technical-architecture.md#caching-strategy)
- [Performance Optimization](${DOC_BASE}/technical-architecture.md#performance-considerations)
- [User Type Management](${DOC_BASE}/user-type-architecture.md)

## ✅ Acceptance Criteria
- [ ] Cache operations complete in <5ms
- [ ] 95%+ cache hit rate achieved
- [ ] Zero data loss on crashes
- [ ] Automatic failover works
- [ ] Memory limits respected
- [ ] TTL refresh logic works
- [ ] Monitoring dashboards active
- [ ] Load tests pass 10K ops/sec
- [ ] Documentation complete
- [ ] Backup strategies tested

## 🔍 Testing Considerations
- Stress test cache limits
- Test failover scenarios
- Verify data consistency
- Benchmark performance
- Test memory pressure"

# Quota Tracking Infrastructure
create_tasks_for_story "Quota Tracking Infrastructure" \
"Design quota tracking database schema" \
"## 📋 Task Overview
Design and implement a robust database schema for tracking user transcription quotas, usage history, and quota-related metrics.

## 🎯 Objective
Create a scalable database design that efficiently tracks quota usage while supporting real-time queries and historical analysis.

## 🔧 Technical Requirements

### 1. Schema Design
- **Core Tables**
  - User quotas (limits by tier)
  - Usage records (per request)
  - Quota history (changes over time)
  - Billing periods (reset cycles)

- **Relationships**
  - User → Quota assignments
  - Usage → Transcription requests
  - History → Audit trail
  - Periods → Usage aggregation

### 2. Data Optimization
- **Indexing Strategy**
  - User ID lookups
  - Time-based queries
  - Aggregation support
  - Range scans

- **Partitioning**
  - Time-based partitions
  - User-based sharding
  - Archive old data
  - Hot/cold storage

### 3. Query Patterns
- **Real-time Queries**
  - Current usage check
  - Remaining quota
  - Rate limit status
  - Near-limit alerts

- **Analytics**
  - Usage trends
  - Peak periods
  - User patterns
  - Capacity planning

## 📚 Documentation References
- [Database Design](${DOC_BASE}/technical-architecture.md#database-design)
- [Quota System](${DOC_BASE}/user-type-architecture.md#2-quota-manager)
- [Data Model](${DOC_BASE}/technical-architecture.md#data-model)

## ✅ Acceptance Criteria
- [ ] Schema supports all quota types
- [ ] Queries execute in <10ms
- [ ] Indexes optimize common queries
- [ ] Partitioning strategy defined
- [ ] Migration scripts ready
- [ ] Backup procedures documented
- [ ] Performance benchmarks met
- [ ] Data integrity constraints
- [ ] Audit trail complete
- [ ] Documentation thorough

## 🔍 Testing Considerations
- Load test with millions of records
- Query performance testing
- Concurrent update handling
- Backup/restore procedures
- Data migration testing" \
\
"Implement real-time quota tracking" \
"## 📋 Task Overview
Build a real-time quota tracking system that monitors usage, enforces limits, and provides instant feedback on quota status.

## 🎯 Objective
Create a high-performance tracking system that accurately monitors quota consumption with minimal latency impact on transcription requests.

## 🔧 Technical Requirements

### 1. Tracking Implementation
- **Usage Monitoring**
  - Per-request tracking
  - Atomic increment operations
  - Concurrent request handling
  - Rollback on failures

- **Quota Enforcement**
  - Pre-request validation
  - Soft and hard limits
  - Grace period handling
  - Quota exhaustion alerts

### 2. Real-time Features
- **Live Updates**
  - WebSocket notifications
  - Server-sent events
  - Push notifications
  - Dashboard updates

- **Aggregation**
  - Running totals
  - Moving windows
  - Rate calculations
  - Trend detection

### 3. Integration
- **API Endpoints**
  - Current usage query
  - Quota status check
  - History retrieval
  - Reset operations

- **Event System**
  - Usage events
  - Limit warnings
  - Quota resets
  - Anomaly alerts

## 📚 Documentation References
- [Real-time Systems](${DOC_BASE}/technical-architecture.md#real-time-updates)
- [Event Architecture](${DOC_BASE}/technical-architecture.md#3-event-system-integration)
- [API Design](${DOC_BASE}/technical-architecture.md#1-transcriptionmixin)

## ✅ Acceptance Criteria
- [ ] Tracking latency <5ms
- [ ] 100% accuracy in counting
- [ ] Real-time updates work
- [ ] Concurrent requests handled
- [ ] No lost transactions
- [ ] Alerts trigger correctly
- [ ] API responds quickly
- [ ] Dashboard shows live data
- [ ] Stress tests pass
- [ ] Zero data loss

## 🔍 Testing Considerations
- High concurrency testing
- Race condition verification
- Accuracy validation
- Performance under load
- Failure recovery testing"

# Epic 3: High-Level API & Client Integration
# ===========================================

echo -e "\n🎯 Epic 3: High-Level API & Client Integration"
echo "----------------------------------------------"

# Basic Transcription Method
create_tasks_for_story "Basic Transcription Method" \
"Implement core transcribe_voice_message method" \
"## 📋 Task Overview
Implement the main public API method that developers will use to transcribe voice messages, providing a clean and intuitive interface.

## 🎯 Objective
Create a user-friendly transcription method that handles all complexity internally while providing a simple API for developers.

## 🔧 Technical Requirements

### 1. Method Signature
- **Parameters**
  - Message object or ID
  - Language preference (optional)
  - Callback function (optional)
  - Timeout setting (optional)
  - Quality preference (optional)

- **Return Values**
  - Transcription object
  - Async/await support
  - Promise-based API
  - Error handling

### 2. Implementation Details
- **Validation**
  - Parameter checking
  - Message type verification
  - Permission validation
  - Quota checking

- **Processing**
  - Request preparation
  - API call execution
  - Response parsing
  - Result formatting

### 3. Error Handling
- **Exception Types**
  - Invalid parameters
  - Network errors
  - API errors
  - Quota exceeded
  - Timeout errors

- **Recovery**
  - Automatic retry
  - Fallback options
  - Graceful degradation
  - User feedback

## 📚 Documentation References
- [API Design](${DOC_BASE}/technical-architecture.md#1-transcriptionmixin)
- [Method Signatures](${DOC_BASE}/technical-architecture.md#method-signatures)
- [Integration Guide](${DOC_BASE}/README.md#usage)

## ✅ Acceptance Criteria
- [ ] Method signature is intuitive
- [ ] All parameters validated
- [ ] Async/await works correctly
- [ ] Errors handled gracefully
- [ ] Documentation complete
- [ ] Examples provided
- [ ] Type hints accurate
- [ ] Performance optimal
- [ ] Thread-safe implementation
- [ ] Backward compatible

## 🔍 Testing Considerations
- Various message types
- Parameter combinations
- Error scenarios
- Concurrent calls
- Performance testing" \
\
"Add comprehensive parameter validation" \
"## 📋 Task Overview
Implement thorough parameter validation for the transcription API to ensure robustness and provide helpful error messages.

## 🎯 Objective
Create a validation layer that catches errors early, provides clear feedback, and ensures API reliability.

## 🔧 Technical Requirements

### 1. Validation Rules
- **Message Validation**
  - Check message exists
  - Verify it's a voice message
  - Validate message access
  - Check message size limits

- **Parameter Validation**
  - Language code format
  - Timeout ranges
  - Callback signatures
  - Optional parameter defaults

### 2. Error Messages
- **User-Friendly Errors**
  - Clear descriptions
  - Suggested fixes
  - Error codes
  - Documentation links

- **Developer Experience**
  - Detailed stack traces
  - Parameter highlights
  - Usage examples
  - Common mistakes

### 3. Performance
- **Optimization**
  - Early validation exit
  - Cached validations
  - Minimal overhead
  - Batch validation

- **Monitoring**
  - Validation metrics
  - Common errors
  - Performance impact
  - Usage patterns

## 📚 Documentation References
- [Validation Patterns](${DOC_BASE}/technical-architecture.md#validation)
- [Error Handling](${DOC_BASE}/technical-architecture.md#error-handling)
- [API Guidelines](${DOC_BASE}/technical-architecture.md#api-design)

## ✅ Acceptance Criteria
- [ ] All parameters validated
- [ ] Error messages helpful
- [ ] Validation <1ms overhead
- [ ] No false positives
- [ ] Edge cases handled
- [ ] Documentation clear
- [ ] Examples comprehensive
- [ ] Metrics collected
- [ ] Tests cover all cases
- [ ] Performance maintained

## 🔍 Testing Considerations
- Invalid parameter testing
- Boundary value testing
- Injection attack testing
- Performance impact
- Error message clarity"

# Message Object Integration
create_tasks_for_story "Message Object Integration" \
"Extend Message class with transcription methods" \
"## 📋 Task Overview
Integrate transcription functionality directly into Telethon's Message class, providing convenient methods for voice message transcription.

## 🎯 Objective
Seamlessly extend the Message class to support transcription operations while maintaining backward compatibility and Telethon's design patterns.

## 🔧 Technical Requirements

### 1. Method Extensions
- **New Methods**
  - `message.transcribe()`
  - `message.get_transcription()`
  - `message.is_transcribable()`
  - `message.transcription_status()`

- **Property Additions**
  - `message.transcription`
  - `message.can_transcribe`
  - `message.transcription_language`
  - `message.transcription_confidence`

### 2. Integration Approach
- **Monkey Patching**
  - Safe method injection
  - Namespace isolation
  - Conflict prevention
  - Version checking

- **Compatibility**
  - Telethon version support
  - Graceful fallbacks
  - Feature detection
  - Migration path

### 3. State Management
- **Caching**
  - Transcription results
  - Status information
  - Metadata storage
  - Cache invalidation

- **Persistence**
  - Database storage
  - Memory efficiency
  - Lazy loading
  - Cleanup routines

## 📚 Documentation References
- [Message Integration](${DOC_BASE}/technical-architecture.md#2-message-object-integration)
- [API Extensions](${DOC_BASE}/technical-architecture.md#api-extensions)
- [Class Design](${DOC_BASE}/technical-architecture.md#class-design)

## ✅ Acceptance Criteria
- [ ] Methods integrate seamlessly
- [ ] No breaking changes
- [ ] Performance unchanged
- [ ] Memory efficient
- [ ] Documentation updated
- [ ] Type hints correct
- [ ] Tests comprehensive
- [ ] Examples clear
- [ ] Backward compatible
- [ ] Thread-safe

## 🔍 Testing Considerations
- Integration testing
- Compatibility testing
- Memory leak testing
- Performance regression
- Edge case handling" \
\
"Implement lazy loading for transcriptions" \
"## 📋 Task Overview
Create a lazy loading system for transcription data to optimize performance and memory usage when working with large message sets.

## 🎯 Objective
Build an efficient loading mechanism that fetches transcription data only when needed, minimizing memory footprint and API calls.

## 🔧 Technical Requirements

### 1. Lazy Loading Design
- **Proxy Pattern**
  - Transparent access
  - On-demand fetching
  - Smart caching
  - Memory management

- **Loading Strategies**
  - Single item loading
  - Batch prefetching
  - Predictive loading
  - Background loading

### 2. Cache Management
- **Memory Optimization**
  - Weak references
  - LRU eviction
  - Size limits
  - Garbage collection

- **Persistence**
  - Disk caching
  - Compression
  - Expiration
  - Cleanup

### 3. Performance
- **Optimization**
  - Minimal overhead
  - Fast access
  - Efficient storage
  - Smart prefetching

- **Monitoring**
  - Load metrics
  - Cache efficiency
  - Memory usage
  - API calls

## 📚 Documentation References
- [Performance Patterns](${DOC_BASE}/technical-architecture.md#performance-considerations)
- [Caching Strategy](${DOC_BASE}/technical-architecture.md#caching-strategy)
- [Memory Management](${DOC_BASE}/technical-architecture.md#memory-management)

## ✅ Acceptance Criteria
- [ ] Transparent lazy loading
- [ ] Memory usage optimized
- [ ] No performance degradation
- [ ] Cache works efficiently
- [ ] API calls minimized
- [ ] Thread-safe access
- [ ] Documentation complete
- [ ] Tests verify behavior
- [ ] Monitoring implemented
- [ ] Examples provided

## 🔍 Testing Considerations
- Large dataset testing
- Memory pressure testing
- Concurrent access
- Cache effectiveness
- Performance benchmarks"

echo -e "\n✅ Part 2 complete! Tasks are being created..."
echo ""
echo "This script has created engineering tasks for:"
echo "- Epic 2: User Type Management & Quota System"
echo "- Epic 3: High-Level API & Client Integration (partial)"
echo ""
echo "Run create-all-tasks-dynamic-part3.sh to continue with remaining tasks."