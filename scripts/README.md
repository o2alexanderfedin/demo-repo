# Project Scripts

All utility scripts have been organized into this directory for better accessibility and maintenance.

## Directory Structure

### 📁 github-project/
GitHub project management and kanban workflow scripts (24 scripts):
- `get-next-kanban-item-simple.sh` - Get next task from kanban board
- `update-task-status-simple.sh` - Update task status in project
- `check-pr-status.sh` - Check pull request status
- `check-wip-limits.sh` - Check work-in-progress limits
- `list-blocked-items.sh` - List blocked project items
- `fix-ci-failures.sh` - Auto-fix CI/CD failures
- `monitor-ci-realtime.sh` - Monitor CI/CD in real-time
- `assign-dependency-fields.sh` - Manage task dependencies
- `assign-story-points.sh` - Assign story points to tasks
- And more...

### 📁 task-creation/
Scripts for creating and managing tasks in bulk (6 scripts):
- `create-all-tasks-dynamic.sh` - Create all tasks dynamically
- `create-remaining-tasks-part*.sh` - Create remaining tasks in parts
- Task generation and management scripts

### 📁 story-management/
Scripts for managing user stories (3 scripts):
- `create-user-stories.sh` - Create user stories
- `create-user-stories-only.sh` - Create only user stories
- `create-remaining-stories.sh` - Create remaining stories

### 📁 workflow/
Git workflow and development process scripts (1 script):
- `show-workflow-status.sh` - Show comprehensive workflow status

### 📁 setup/
Initial setup and configuration scripts (2 scripts):
- `install-workflow-hooks.sh` - Install git hooks for workflow automation
- `configure-auto-completion.sh` - Configure shell auto-completion

### 📁 project-setup/
GitHub project setup and configuration scripts (5 scripts):
- `create-scrum-project-complete.sh` - Create complete scrum project
- `add-dependency-fields.sh` - Add dependency fields to project
- `add-story-points-field.sh` - Add story points field
- `configure-scrum-items.sh` - Configure scrum items
- `create-project-only-scrum.sh` - Create project-only scrum setup

### 📁 protection/
Project protection and mode scripts (3 scripts):
- `setup-project-hooks.sh` - Setup project protection hooks
- `install-no-issues-mode.sh` - Install no-issues mode
- `no-issues-mode.sh` - No-issues mode script

### 📁 docs/
Documentation and summaries (9 files):
- Various markdown documentation files
- Project summaries and analyses
- Configuration documentation

## Quick Start

Most commonly used scripts:

```bash
# Get next task and start working
./scripts/github-project/get-next-kanban-item-simple.sh --auto-assign

# Update task status
./scripts/github-project/update-task-status-simple.sh <task-number> "In Progress"

# Check workflow status
./scripts/workflow/show-workflow-status.sh

# Install git hooks
./scripts/setup/install-workflow-hooks.sh
```

## Migration Note

These scripts were moved from:
- `tools/github-project-management/utilities/` → `scripts/github-project/`
- `tools/github-project-management/project-setup/` → `scripts/project-setup/`
- `tools/github-project-management/protection/` → `scripts/protection/`
- `tools/` → `scripts/workflow/` and `scripts/setup/`
- `workspace/telethon-architecture-docs/tools/` → `scripts/`

All scripts maintain their original functionality and permissions.