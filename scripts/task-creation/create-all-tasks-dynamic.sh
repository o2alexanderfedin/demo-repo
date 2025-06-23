#!/usr/bin/env bash
set -euo pipefail

# Configuration for Voice Transcription project
OWNER="o2alexanderfedin"
REPO="telethon-architecture-docs"
PROJECT_NUMBER=12
DOC_BASE="https://github.com/o2alexanderfedin/telethon-architecture-docs/blob/main/documentation/voice-transcription-feature"

echo "🔧 Creating Engineering Tasks for Voice Transcription Project..."
echo "=================================================="
echo "This script will create detailed engineering tasks as sub-issues"
echo "under each user story with comprehensive documentation links"
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
echo "   Project ID: $PROJECT_ID"
echo "   Repository ID: $REPO_ID"
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

# Create tasks for each user story
echo "📋 Creating Engineering Tasks for User Stories"
echo "=============================================="
echo ""

# Epic 1: Core Infrastructure & Raw API Support
# =============================================

echo "🎯 Epic 1: Core Infrastructure & Raw API Support"
echo "----------------------------------------------"

# TL Schema Definitions
create_tasks_for_story "TL Schema Definitions" \
"Define voice message TL schema structures" \
"## 📋 Task Overview
This task involves creating the foundational TL (Type Language) schema definitions that will enable voice transcription functionality in Telethon. These schemas define the data structures for communication with Telegram's API for voice message transcription.

## 🎯 Objective
Design and implement comprehensive TL schema structures that support all aspects of voice transcription, including requests, responses, updates, and error handling.

## 🔧 Technical Requirements

### 1. Core Schema Definitions
- **VoiceTranscriptionRequest**: Define the request structure for initiating voice transcriptions
  - Include message ID reference
  - Language preference parameters
  - Quality/speed trade-off options
  - Callback configuration
  
- **VoiceTranscriptionResult**: Define the response structure for completed transcriptions
  - Transcribed text content
  - Confidence scores
  - Language detection results
  - Timing information (start/end timestamps)
  - Alternative transcriptions (if available)
  
- **VoiceTranscriptionUpdate**: Define update events for transcription progress
  - Progress percentage
  - Partial results
  - Status changes (pending, processing, completed, failed)
  - Error information

### 2. Supporting Structures
- Define enums for transcription states
- Create flag structures for optional features
- Design error code definitions specific to voice transcription
- Implement metadata structures for audio properties

### 3. Compatibility Requirements
- Ensure schemas align with existing Telethon patterns
- Maintain backward compatibility considerations
- Follow Telegram's schema versioning practices

## 📚 Documentation References
- [TL Schema Definitions Guide](${DOC_BASE}/technical-architecture.md#tl-schema-definitions)
- [Data Flow Architecture](${DOC_BASE}/technical-architecture.md#data-flow)
- [Voice Transcription Overview](${DOC_BASE}/README.md)
- [Technical Architecture Overview](${DOC_BASE}/technical-architecture.md)

## ✅ Acceptance Criteria
- [ ] All three core schemas (Request, Result, Update) are fully defined
- [ ] Schemas include comprehensive field documentation
- [ ] All required fields are properly marked as non-optional
- [ ] Optional fields have sensible defaults defined
- [ ] Enum values are clearly documented with use cases
- [ ] Schema compilation passes without warnings or errors
- [ ] Schemas follow Telethon's naming conventions
- [ ] Version compatibility markers are included
- [ ] Unit tests validate schema structure integrity
- [ ] Performance impact of schema size is analyzed
- [ ] Documentation includes usage examples
- [ ] Peer review completed by senior team member

## 🔍 Testing Considerations
- Validate schema serialization with edge cases
- Test with malformed data inputs
- Verify field presence/absence handling
- Check enum value validation
- Test version negotiation scenarios" \
\
"Implement schema serialization/deserialization methods" \
"## 📋 Task Overview
Implement robust serialization and deserialization methods for the voice transcription TL schemas. This is critical for reliable communication with Telegram's API and ensures data integrity throughout the transcription lifecycle.

## 🎯 Objective
Create high-performance, error-resistant serialization/deserialization implementations that handle all edge cases while maintaining compatibility with Telethon's existing serialization framework.

## 🔧 Technical Requirements

### 1. Serialization Implementation (to_bytes)
- **Efficient Binary Encoding**
  - Implement optimal field ordering for size efficiency
  - Use appropriate data type representations
  - Handle variable-length fields correctly
  - Implement proper padding and alignment

- **Field Validation**
  - Validate all fields before serialization
  - Check string length limits
  - Verify enum values are valid
  - Ensure required fields are present

- **Error Handling**
  - Raise descriptive exceptions for invalid data
  - Provide field-specific error messages
  - Implement graceful handling of optional fields

### 2. Deserialization Implementation (from_bytes)
- **Robust Parsing**
  - Handle incomplete data gracefully
  - Validate data integrity during parsing
  - Support version detection and handling
  - Implement proper boundary checking

- **Type Safety**
  - Ensure type conversions are safe
  - Handle numeric overflow/underflow
  - Validate string encodings (UTF-8)
  - Check array/list bounds

- **Performance Optimization**
  - Minimize memory allocations
  - Use efficient parsing strategies
  - Implement lazy loading where appropriate
  - Cache frequently accessed data

### 3. Utility Methods
- Implement \`__repr__\` for debugging
- Add \`to_dict\` / \`from_dict\` for JSON compatibility
- Create validation helper methods
- Implement equality comparison methods

## 📚 Documentation References
- [Serialization Patterns](${DOC_BASE}/technical-architecture.md#serialization)
- [Data Flow Documentation](${DOC_BASE}/technical-architecture.md#data-flow)
- [Error Handling Guidelines](${DOC_BASE}/technical-architecture.md#error-handling)
- [Performance Considerations](${DOC_BASE}/technical-architecture.md#performance-considerations)

## ✅ Acceptance Criteria
- [ ] All schemas have complete to_bytes implementations
- [ ] All schemas have complete from_bytes implementations
- [ ] Serialization round-trip tests pass (serialize → deserialize → compare)
- [ ] Performance benchmarks meet targets (<1ms for typical payloads)
- [ ] Memory usage is optimized (no unnecessary allocations)
- [ ] Edge cases are handled (empty strings, null values, max values)
- [ ] Invalid data triggers appropriate exceptions
- [ ] Partial data handling works correctly
- [ ] Version compatibility is maintained
- [ ] Thread safety is ensured
- [ ] Code coverage exceeds 95%
- [ ] Documentation includes serialization format specification
- [ ] Integration tests with mock API responses pass
- [ ] Performance profiling shows no bottlenecks

## 🔍 Testing Considerations
- Fuzz testing with random data
- Boundary value testing
- Concurrency testing
- Memory leak detection
- Performance regression testing" \
\
"Create comprehensive schema validation and testing suite" \
"## 📋 Task Overview
Develop a comprehensive testing suite specifically for voice transcription schemas. This suite will ensure schema integrity, validate business logic, and prevent regressions as the feature evolves.

## 🎯 Objective
Build a robust, maintainable test suite that provides high confidence in schema correctness, handles edge cases, and serves as living documentation for schema behavior.

## 🔧 Technical Requirements

### 1. Unit Test Coverage
- **Schema Structure Tests**
  - Validate all fields are present and correctly typed
  - Test field optionality rules
  - Verify default values
  - Check field ordering for serialization

- **Validation Tests**
  - Test boundary conditions for all numeric fields
  - Validate string length constraints
  - Test enum value restrictions
  - Verify complex validation rules

- **Serialization Tests**
  - Test all valid schema configurations
  - Test edge cases (empty, minimal, maximal)
  - Verify byte-level correctness
  - Test version compatibility

### 2. Integration Tests
- **API Compatibility Tests**
  - Test against known good API responses
  - Validate against Telegram's documentation
  - Test error response handling
  - Verify update event processing

- **Telethon Integration**
  - Test within Telethon's framework
  - Verify MTProto layer compatibility
  - Test with real connection scenarios
  - Validate event handling integration

### 3. Performance Tests
- **Serialization Performance**
  - Benchmark serialization speed
  - Measure memory allocation
  - Test with various payload sizes
  - Profile CPU usage

- **Load Testing**
  - Test high-frequency transcription requests
  - Simulate concurrent operations
  - Measure resource usage under load
  - Test memory leak scenarios

### 4. Test Utilities
- Create schema factory methods for tests
- Implement custom assertions for schemas
- Build test data generators
- Create mock API response builders

## 📚 Documentation References
- [Testing Strategy](${DOC_BASE}/technical-architecture.md#testing-strategy)
- [Schema Validation Rules](${DOC_BASE}/technical-architecture.md#tl-schema-definitions)
- [Integration Testing Guide](${DOC_BASE}/technical-architecture.md#2-integration-tests)
- [Performance Testing](${DOC_BASE}/technical-architecture.md#3-performance-tests)

## ✅ Acceptance Criteria
- [ ] 100% code coverage for schema modules
- [ ] All schema fields have specific test cases
- [ ] Edge cases documented and tested
- [ ] Performance benchmarks established and met
- [ ] Memory usage tests show no leaks
- [ ] Concurrent access tests pass
- [ ] Integration with CI/CD pipeline complete
- [ ] Test execution time under 30 seconds
- [ ] Fuzz testing framework integrated
- [ ] Test data generators created and documented
- [ ] Mock API responses cover all scenarios
- [ ] Test reports generated automatically
- [ ] Performance regression detection implemented
- [ ] Documentation includes test writing guide

## 🔍 Testing Considerations
- Property-based testing for invariants
- Mutation testing for test quality
- Cross-platform compatibility testing
- Backward compatibility verification
- Security testing for malicious inputs"

# Basic Request Implementation
create_tasks_for_story "Basic Request Implementation" \
"Create VoiceTranscriptionRequest class implementation" \
"## 📋 Task Overview
Implement the core VoiceTranscriptionRequest class that serves as the primary interface for initiating voice message transcriptions. This class must seamlessly integrate with Telethon's request framework while providing a clean, intuitive API for developers.

## 🎯 Objective
Build a production-ready request class that handles all aspects of voice transcription requests, including parameter validation, error handling, and integration with Telethon's infrastructure.

## 🔧 Technical Requirements

### 1. Class Architecture
- **Inheritance Structure**
  - Extend appropriate Telethon base request class
  - Implement required abstract methods
  - Override necessary lifecycle hooks
  - Maintain compatibility with request pipeline

- **Constructor Design**
  - Accept voice message reference (ID or object)
  - Language preference parameters (auto-detect or specific)
  - Quality/speed trade-off settings
  - Optional callback configuration
  - Timeout specifications

- **Method Implementation**
  - \`get_input_chat()\` for chat resolution
  - \`get_input_user()\` for user context
  - \`resolve()\` for reference resolution
  - \`on_response()\` for response handling
  - \`on_error()\` for error processing

### 2. Parameter Validation
- **Input Validation**
  - Verify voice message exists and is accessible
  - Validate language codes against supported list
  - Check quality parameters are within bounds
  - Ensure timeout values are reasonable

- **State Validation**
  - Check user has necessary permissions
  - Verify chat/channel access rights
  - Validate quota availability
  - Check for rate limit compliance

### 3. Request Optimization
- **Caching Strategy**
  - Cache resolved entity references
  - Store computed request parameters
  - Implement smart cache invalidation
  - Minimize redundant API calls

- **Batching Support**
  - Design for future batch request support
  - Implement request grouping logic
  - Handle partial batch failures
  - Optimize for bulk operations

## 📚 Documentation References
- [Request Implementation Guide](${DOC_BASE}/technical-architecture.md#data-flow)
- [API Integration Points](${DOC_BASE}/technical-architecture.md#integration-points)
- [Component Design](${DOC_BASE}/technical-architecture.md#component-design)
- [Error Handling](${DOC_BASE}/technical-architecture.md#error-handling)

## ✅ Acceptance Criteria
- [ ] Class properly extends Telethon's request base
- [ ] All constructor parameters are validated
- [ ] Required methods are fully implemented
- [ ] Error handling covers all failure scenarios
- [ ] Request serialization works correctly
- [ ] Integration with Telethon's auth system works
- [ ] Rate limiting is properly respected
- [ ] Caching improves performance measurably
- [ ] Async/await patterns properly implemented
- [ ] Thread safety is guaranteed
- [ ] Memory footprint is optimized
- [ ] Documentation includes usage examples
- [ ] Unit tests achieve 100% coverage
- [ ] Integration tests with mock server pass
- [ ] Performance meets <100ms overhead target

## 🔍 Testing Considerations
- Test with various voice message formats
- Verify behavior with deleted messages
- Test permission denial scenarios
- Validate timeout handling
- Test concurrent request handling" \
\
"Implement intelligent rate limiting system" \
"## 📋 Task Overview
Design and implement a sophisticated rate limiting system for voice transcription requests that balances user experience with API constraints. The system must be fair, efficient, and provide clear feedback to users about their usage.

## 🎯 Objective
Create a rate limiting implementation that prevents API abuse while maximizing legitimate usage, with support for different user tiers and graceful degradation under load.

## 🔧 Technical Requirements

### 1. Token Bucket Implementation
- **Core Algorithm**
  - Implement token bucket with configurable capacity
  - Support variable refill rates based on user type
  - Handle burst allowances for premium users
  - Implement smooth rate limiting (no hard stops)

- **Multi-Tier Support**
  - Free tier: Basic rate limits
  - Premium tier: Enhanced limits
  - Business tier: Minimal restrictions
  - Admin override capabilities

- **Resource Tracking**
  - Track requests per user
  - Monitor bandwidth usage
  - Count transcription minutes
  - Aggregate by time windows

### 2. Adaptive Rate Limiting
- **Dynamic Adjustment**
  - Monitor global API health
  - Adjust limits based on server load
  - Implement fairness algorithms
  - Support emergency throttling

- **Predictive Limiting**
  - Analyze usage patterns
  - Predict limit exhaustion
  - Proactive user warnings
  - Suggest optimal usage times

### 3. User Experience
- **Feedback Mechanisms**
  - Real-time quota status
  - Time until limit reset
  - Suggested retry times
  - Usage statistics API

- **Grace Periods**
  - Soft limits with warnings
  - Gradual throttling
  - Priority queuing for premium
  - Burst allowances

### 4. Integration Features
- **Metrics Collection**
  - Rate limit hit statistics
  - User behavior analytics
  - Performance impact metrics
  - Abuse detection signals

- **Configuration Management**
  - Hot-reloadable limits
  - A/B testing support
  - Regional variations
  - Time-based adjustments

## 📚 Documentation References
- [Rate Limiting Architecture](${DOC_BASE}/technical-architecture.md#rate-limiting-and-quotas)
- [User Type Management](${DOC_BASE}/user-type-architecture.md)
- [Quota System Design](${DOC_BASE}/technical-architecture.md#rate-limiting-and-quotas)
- [Performance Optimization](${DOC_BASE}/technical-architecture.md#performance-considerations)

## ✅ Acceptance Criteria
- [ ] Token bucket algorithm correctly implemented
- [ ] Rate limits enforced accurately (±1% tolerance)
- [ ] Different user tiers properly supported
- [ ] Burst handling works as designed
- [ ] Rate limit headers included in responses
- [ ] Quota status API endpoint functional
- [ ] Graceful degradation under high load
- [ ] No memory leaks under sustained usage
- [ ] Configuration changes apply without restart
- [ ] Metrics dashboard shows real-time data
- [ ] User notifications work reliably
- [ ] Performance overhead <5ms per request
- [ ] Distributed rate limiting synchronized
- [ ] Abuse patterns detected and mitigated
- [ ] Documentation includes configuration guide

## 🔍 Testing Considerations
- Load testing with varied patterns
- Concurrent user simulation
- Rate limit boundary testing
- Clock skew handling
- Distributed system testing"

echo -e "\n✅ Script complete! Tasks are being created..."
echo ""
echo "Note: This script creates detailed engineering tasks with:"
echo "- Comprehensive task descriptions"
echo "- Clear technical requirements"
echo "- Detailed acceptance criteria"
echo "- Relevant documentation links"
echo "- Testing considerations"
echo ""
echo "The tasks are created as sub-issues under their parent user stories"
echo "and are properly typed and linked in the project."