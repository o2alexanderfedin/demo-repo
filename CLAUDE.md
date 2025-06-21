# CLAUDE.md - Project Reference

## Git Hook Rules

This project uses git hooks to maintain code quality and consistency. The hook rules are defined in the following files:

### Pre-commit Hook Rules
- **Location**: `.claude/pre-commit.rules`
- **Purpose**: Validates code quality, security, and formatting before commits
- **Key Checks**:
  - Code linting and syntax validation
  - Security scanning for credentials and API keys
  - File size and format validation
  - Test execution for modified files

### Commit Message Hook Rules
- **Location**: `.claude/commit-msg.rules`
- **Purpose**: Ensures consistent and meaningful commit messages
- **Key Requirements**:
  - Conventional commit format (feat, fix, docs, etc.)
  - Character limits for subject and body
  - Issue reference requirements
  - Content restrictions

### Pre-push Hook Rules
- **Location**: `.claude/pre-push.rules`
- **Purpose**: Final validation before code is pushed to remote
- **Key Validations**:
  - Branch protection enforcement
  - Full test suite execution
  - Security and vulnerability scanning
  - Documentation requirements

## Code Principles (SOLID, KISS, DRY, Clean Code)

This project enforces SOLID, KISS, DRY, and Clean Code principles for all development activities.

### Principle Files
- **Code Principles**: `.claude/code-principles.rules` - Comprehensive guide to all principles
- **Review Checklist**: `.claude/code-review-checklist.md` - Systematic review process
- **Pre-commit Rules**: `.claude/pre-commit.rules` - Automated enforcement

### Core Principles

#### SOLID
- **S**ingle Responsibility: One class, one purpose
- **O**pen/Closed: Open for extension, closed for modification
- **L**iskov Substitution: Subclasses must be substitutable
- **I**nterface Segregation: No unused interface methods
- **D**ependency Inversion: Depend on abstractions

#### KISS (Keep It Simple, Stupid)
- Choose simplest working solution
- Avoid premature optimization
- Functions under 20-30 lines
- No deeply nested code (>3 levels)
- Clear over clever code

#### DRY (Don't Repeat Yourself)
- Extract common code
- Use constants for repeated values
- Create reusable components
- Centralize configuration

#### Clean Code
- Meaningful names
- Small, focused functions
- Self-documenting code
- Proper error handling
- Consistent formatting

### Enforcement
- Pre-commit hooks check compliance
- Code reviews use standardized checklist
- Automated tools detect violations
- All code must follow these principles

## Project Standards

### Code Quality
- All code must pass linting checks
- Minimum test coverage: 80%
- No console.log statements in production code
- No hardcoded credentials or secrets
- Must follow SOLID, KISS, DRY, Clean Code principles

### Git Workflow
- Use conventional commits format
- Create feature branches for new work
- Require pull requests for main branch
- Keep commits atomic and focused

### Security
- Regular dependency vulnerability scanning
- No sensitive data in repositories
- Use environment variables for configuration
- Follow principle of least privilege

## Development Commands

### Testing
```bash
npm test          # Run all tests
npm run test:coverage  # Run tests with coverage report
```

### Linting
```bash
npm run lint      # Run linter
npm run lint:fix  # Auto-fix linting issues
```

### Building
```bash
npm run build     # Build the project
npm run build:prod  # Production build
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes following the hook rules
4. Submit a pull request
5. Ensure all checks pass

## GitFlow Integration

This project uses GitFlow for branch management with Claude-aware hooks for better AI assistance.

### GitFlow Commands
```bash
# Start a new feature
git flow feature start <feature-name>

# Finish a feature
git flow feature finish <feature-name>

# Start a release
git flow release start <version>

# Start a hotfix
git flow hotfix start <version>
```

### Claude GitFlow Hooks

#### Post-flow-feature-start Hook
- **Location**: `.git/hooks/post-flow-feature-start`
- **Purpose**: Creates environment status file for Claude
- **Creates**: `.claude/gitflow-status.env` with feature information
- **Action Required**: Update FEATURE_DESCRIPTION in the status file

#### Post-commit Hook
- **Location**: `.git/hooks/post-commit`
- **Purpose**: Reminds Claude about active GitFlow branches
- **Shows**: Current feature/release/hotfix status and suggests finishing

#### Pre-push Hook  
- **Location**: `.git/hooks/pre-push`
- **Purpose**: Final reminder before pushing GitFlow branches
- **Shows**: Comprehensive status and next steps

### GitFlow Status File
When working on a feature, the `.claude/gitflow-status.env` file contains:
- `GITFLOW_ACTIVE`: Whether GitFlow is active
- `GITFLOW_TYPE`: Branch type (feature/release/hotfix)
- `GITFLOW_BRANCH`: Current branch name
- `GITFLOW_FEATURE_NAME`: Feature name without prefix
- `GITFLOW_STARTED_AT`: When the feature was started
- `GITFLOW_STATUS`: Current status
- `FEATURE_DESCRIPTION`: Description of the feature (update this!)
- `GITFLOW_COMMIT_COUNT`: Number of commits on the branch
- `GITFLOW_LAST_COMMIT`: Timestamp of last commit
- `GITFLOW_LAST_PUSH`: Timestamp of last push

## Conversation Tracking

All conversations with Claude are tracked in `.claude/conversations/` directory in a todo listicle format. This helps maintain project history and task continuity.

### Conversation Log Structure
- **Location**: `.claude/conversations/`
- **Format**: `YYYY-MM-DD-session-NNN.md`
- **Template**: `.claude/conversations/template.md`

Each log contains:
- Summary of conversation goals
- Tasks completed with status tracking
- Commands executed during session
- Files modified with descriptions
- Key decisions and reasoning
- Follow-up items for future work
- Additional notes and context

### Benefits
- Track project evolution over time
- Reference past decisions and implementations
- Maintain task continuity between sessions
- Document command history for reproduction
- Identify patterns and improvements

## Hook Installation

To install the git hooks locally:
```bash
# Install pre-commit framework (if using)
npm install --save-dev husky

# Initialize husky
npx husky init

# Add hooks
npx husky add .husky/pre-commit "npm test"
npx husky add .husky/commit-msg "npx commitlint --edit $1"
npx husky add .husky/pre-push "npm run build && npm test"
```