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

### Kanban Workflow
```bash
# Get next work item based on Kanban rules
./scripts/github-project/get-next-kanban-item.sh

# Auto-assign next item to "In Progress"
./scripts/github-project/get-next-kanban-item.sh --auto-assign

# Check WIP limits
./scripts/github-project/check-wip-limits.sh

# List blocked items
./scripts/github-project/list-blocked-items.sh
```

## Kanban Workflow Rules

This project uses Kanban for work management. Key rules:

### WIP Limits
- **In Progress**: Maximum 3 items
- **In Review**: Maximum 2 items  
- **Testing**: Maximum 2 items

### Pull Order
1. Blocked items you can unblock
2. Items blocking others
3. Highest priority + story points
4. Oldest ready items

### Daily Flow
1. Check blocked items
2. Update current status
3. Check WIP limits
4. Pull next item if ready
5. Complete work fast

See `.claude/kanban-workflow.rules` for complete guidelines.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes following the hook rules
4. Submit a pull request
5. Ensure all checks pass

## GitFlow + Kanban Workflow Integration

This project **enforces** GitFlow for branch management combined with Kanban for work management, with comprehensive hooks that automate the entire workflow, including **automatic task completion** on successful pushes.

### 🚨 CRITICAL: Task Assignment Requirements

**ALL development work MUST have:**
1. A GitHub issue/task assigned to you
2. Task status set to "In Progress" in the project board
3. Feature branch linked to the task

**The pre-commit hook will BLOCK commits if these requirements are not met!**

### 🚨 MANDATORY: GitFlow Enforcement

**All development MUST use GitFlow branches:**
- Direct commits to `main` and `develop` are **BLOCKED**
- Every feature MUST start with `git flow feature start`
- Every feature MUST have a linked Kanban task
- Task status is automatically managed (In Progress → Done)
- Architecture docs are consulted when starting tasks
- Completion reports are added to tasks when finishing

### Workflow Hooks

#### Installation
```bash
./scripts/setup/install-workflow-hooks.sh
```

#### Installed Hooks
- **pre-commit**: Enforces GitFlow branches, blocks main/develop commits, checks task status
- **post-commit**: Shows GitFlow status and Kanban reminders after commits
- **pre-push**: Final checks and reminders before pushing
- **post-push**: Auto-completes tasks on successful pushes, monitors CI/CD, and auto-fixes failures
- **post-checkout**: Branch validation and context-aware guidance
- **post-merge**: Dependency checks and next steps after merges
- **prepare-commit-msg**: Adds context and templates to commit messages
- **post-flow-feature-start**: Auto-links tasks, updates status to "In Progress"
- **post-flow-feature-finish**: Updates task to "Done", archives statistics

#### Git Aliases
After installation, use these shortcuts:
- `git workflow` - Complete workflow status dashboard
- `git next` - Get next Kanban item to work on
- `git wip` - Check current WIP limits
- `git blocked` - List all blocked items
- `git ci-fix` - Analyze and fix CI/CD failures
- `git ci-monitor` - Real-time CI/CD monitoring
- `git validate` - Check GitFlow compliance
- `git task-status` - Update task status manually
- `git feature-start` - Quick feature start
- `git feature-finish` - Quick feature finish
- `git arch` - Show architecture guidance
- `git pr-status` - Check status of all open PRs
- `git pr-merge` - Merge PR with squash and delete branch

### Workflow Status Dashboard
```bash
./scripts/workflow/show-workflow-status.sh
# Or after installation: git workflow
```

Shows:
- Current GitFlow branch and context
- Kanban WIP status and limits
- Blocked items count
- Quick action commands
- Git working directory status

### Complete Workflow Example

```bash
# 1. Get next task from Kanban
git next
# Shows: "Issue #123: Implement user authentication"

# 2. Start feature (auto-links task)
git flow feature start user-authentication
# ✅ Auto-linked task #123
# ✅ Task status → "In Progress"
# ✅ Architecture docs displayed
# ✅ Start comment added to task

# 3. Work on feature
git add .
git commit -m "feat: add login endpoint

Refs #123"
# ✅ Pre-commit validates GitFlow branch
# ✅ Tracks time and commits

# 4. Push (PR created automatically)
git push -u origin feature/user-authentication
# ✅ PR created with task reference
# ✅ Linked to task #123
# ✅ CI/CD monitoring starts

# 5. Review and merge PR
git pr-status
# Shows PR status and required actions
gh pr merge <number> --squash
# ✅ Merges PR to develop

# 6. Finish feature
git flow feature finish user-authentication
# ✅ Cleans up feature branch
# ✅ Task #123 → "Done"
# ✅ Completion report added to task
# ✅ Archives feature stats

# 7. Get next task (only allowed with no open PRs)
git next
# ✅ Checks for open PRs first
# ✅ Shows next available task
```

### Workflow Rules

See `.claude/gitflow-kanban-rules.md` for complete rules and enforcement details.

### Architecture & Code Quality

#### Automatic Architecture Guidance
When starting work on a task:
- Relevant documentation is automatically found and displayed
- Architecture references are saved to `.claude/task-<number>-arch-refs.md`
- SOLID, KISS, DRY, and Clean Code principles are shown
- Task-specific patterns and guidelines are provided

Use `git arch` to view architecture guidance anytime.

#### Enforced Principles
Every feature MUST follow:
- **SOLID** - Single Responsibility, Open/Closed, Liskov Substitution, Interface Segregation, Dependency Inversion
- **KISS** - Keep It Simple, Stupid
- **DRY** - Don't Repeat Yourself
- **Clean Code** - Meaningful names, small functions, proper error handling

#### Completion Reports
When finishing a feature, a detailed report is automatically added to the task:
- Work summary with duration and statistics
- List of files changed and commits made
- Linked pull requests
- Implementation notes
- Next steps and recommendations

### CI/CD Integration

#### Automatic CI/CD Monitoring
The post-push hook automatically:
1. Monitors GitHub Actions after each push
2. Waits for CI/CD completion
3. Analyzes failures if any occur
4. Attempts automatic fixes for common issues:
   - Linting errors (ESLint, Prettier)
   - Missing dependencies
   - Security vulnerabilities
   - Markdown formatting
5. Creates fix branches and PRs if needed

#### Manual CI/CD Commands
```bash
# Analyze and fix recent failures
./scripts/github-project/fix-ci-failures.sh --auto-fix

# Create PR with fixes
./scripts/github-project/fix-ci-failures.sh --auto-fix --create-pr

# Monitor CI in real-time
./scripts/github-project/monitor-ci-realtime.sh

# Or use git aliases
git ci-fix --auto-fix
git ci-monitor
```

#### Supported Auto-Fixes
- **Linting**: ESLint, Prettier, Black, isort
- **Dependencies**: npm/yarn install, pip install
- **Security**: npm/yarn audit fix
- **Formatting**: Markdown linting
- **TypeScript**: Type definition suggestions
- **Docker**: Build error analysis

## Automatic Task Completion

This project includes **intelligent task auto-completion** that automatically moves project tasks to "Done" status when work is successfully pushed.

### 🎯 Auto-Completion Rules

**Tasks are automatically completed when:**
1. ✅ Task is in "In Progress" status
2. ✅ Push is to a feature branch (`feature/*`)
3. ✅ Feature branch has ≥1 commits compared to develop
4. ✅ Feature branch has ≥1 files changed
5. ✅ Push completes successfully
6. ✅ (Optional) CI/CD checks pass

### 🔧 Configuration Commands

```bash
# Configure auto-completion settings
./scripts/setup/configure-auto-completion.sh

# View current configuration
grep "AUTO_" .claude/auto-completion.rules

# Test auto-completion setup
./scripts/setup/configure-auto-completion.sh
# → Choose option 5: Test configuration
```

### ⚙️ Customization Options

**Auto-completion can be configured for:**
- Minimum commits required (`MIN_FEATURE_COMMITS`)
- Minimum files changed (`MIN_CHANGED_FILES`)
- Required task status (`REQUIRED_TASK_STATUS`)
- Allowed branches (`ALLOWED_BRANCHES`)
- Wait for CI success (`AUTO_COMPLETE_ON_CI_SUCCESS`)
- Add completion comments (`ADD_COMPLETION_COMMENT`)

### 🔒 Disable Auto-Completion

```bash
# Globally disable
echo "AUTO_COMPLETION_ENABLED=false" >> .claude/auto-completion.rules

# Disable for specific task (add label to GitHub issue)
gh issue edit <task-number> --add-label "manual-completion"

# Disable for current push only
git push --no-verify
```

### 📊 Auto-Completion Statistics

```bash
# View auto-completion log
cat .claude/auto-completion.log

# View last auto-completed tasks
tail -5 .claude/auto-completion.log
```

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