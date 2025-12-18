# GitHub Project Management Tools

This directory contains organized scripts for managing GitHub Projects, particularly for the Voice Transcription feature development.

## 📁 Directory Structure

```
github-project-management/
├── project-setup/       # Scripts for creating and configuring projects
├── story-management/    # Scripts for managing epics and user stories  
├── task-creation/       # Scripts for creating engineering tasks
├── utilities/          # Utility scripts for maintenance and updates
└── protection/         # Safety scripts to prevent accidents
```

## 🚀 Quick Start

### 1. Create a New Project
```bash
cd project-setup
./create-scrum-project-complete.sh
```

### 2. Create Epics and User Stories
```bash
cd ../story-management
./create-user-stories.sh
```

### 3. Create Engineering Tasks
```bash
cd ../task-creation
# Run all parts to create all tasks
./create-all-tasks-dynamic.sh
./create-all-tasks-dynamic-part2.sh
./create-all-tasks-dynamic-part3.sh
```

## 📋 Scripts by Category

### 🚀 Project Setup (`project-setup/`)
- **`create-scrum-project-complete.sh`** - Create a new GitHub Project with full Scrum configuration
- **`create-project-only-scrum.sh`** - Create a project using only draft items (no repository issues)
- **`configure-scrum-items.sh`** - Configure existing project items with Scrum fields
- **`add-dependency-fields.sh`** - Add dependency tracking fields to existing projects
- **`add-story-points-field.sh`** - Add Story Points field to existing projects

### 📖 Story Management (`story-management/`)
- **`create-user-stories.sh`** - Create user stories from JSON data (creates epics first)
- **`create-user-stories-only.sh`** - Create only user stories (assumes epics exist)
- **`create-remaining-stories.sh`** - Create any missing user stories

### 🔧 Task Creation (`task-creation/`)
**Dynamic Scripts** (query for issue numbers at runtime):
- **`create-all-tasks-dynamic.sh`** - Part 1: Create initial set of engineering tasks
- **`create-all-tasks-dynamic-part2.sh`** - Part 2: Continue task creation
- **`create-all-tasks-dynamic-part3.sh`** - Part 3: Complete initial task creation

**Remaining Tasks** (for stories not covered in initial scripts):
- **`create-remaining-tasks-part1.sh`** - Create tasks for Epic 1 & 2 stories
- **`create-remaining-tasks-part2.sh`** - Create tasks for Epic 2 & 3 stories
- **`create-remaining-tasks-part3.sh`** - Create tasks for Epic 3, 4 & 5 stories

### 🛠️ Utilities (`utilities/`)
- **`add-documentation-links.sh`** - Add documentation links to project items
- **`add-draft-items.sh`** - Bulk import draft items to a project
- **`assign-story-points.sh`** - Assign story points to all engineering tasks
- **`cleanup-untyped-items.sh`** - Clean up project items without Type field set
- **`delete-draft-issues.sh`** - Remove draft issues from project
- **`field-configuration-guide.sh`** - Display guide for using Status and Dependency Status fields together
- **`reset-status-field.sh`** - Reset all task statuses to Todo

### 📊 Kanban Workflow (`utilities/`)
- **`get-next-kanban-item.sh`** - Automatically select next work item based on Kanban rules
- **`check-wip-limits.sh`** - Check current Work In Progress limits across columns
- **`list-blocked-items.sh`** - List all blocked items with blocking reasons

### 🔧 CI/CD Management (`utilities/`)
- **`fix-ci-failures.sh`** - Analyze and automatically fix common CI/CD failures
- **`monitor-ci-realtime.sh`** - Real-time CI/CD monitoring with progress tracking

### 🌳 GitFlow Enforcement (`utilities/`)
- **`validate-gitflow.sh`** - Validate current branch follows GitFlow conventions
- **`update-task-status.sh`** - Update task status in GitHub Project (used by hooks)

### 🛡️ Protection (`protection/`)
- **`no-issues-mode.sh`** - Temporarily disable gh issue commands
- **`install-no-issues-mode.sh`** - Permanently install gh issue protection
- **`setup-project-hooks.sh`** - Set up git hooks for project safety

## 📊 Project Structure

The scripts support a hierarchical project structure:
```
Epic (Type: Epic)
└── User Story (Type: User Story) - linked as sub-issue
    └── Engineering Task (Type: Task) - linked as sub-issue
```

## 🔧 Configuration

Default values used across scripts:
- **Owner**: `o2alexanderfedin`
- **Repository**: `telethon-architecture-docs`
- **Project Number**: `12`

Update these values in the scripts if working with different repositories.

## 📝 Data Files

The scripts work with JSON data files:
- `documentation/voice-transcription-feature/epics.json`
- `documentation/voice-transcription-feature/user-stories.json`

## ⚠️ Important Notes

1. **Dynamic Scripts**: Use runtime queries instead of hardcoded issue numbers
2. **Rate Limiting**: Scripts include delays to respect API limits
3. **Error Handling**: Scripts continue on errors rather than stopping
4. **Sub-issue Linking**: Requires `GraphQL-Features: sub_issues` header
5. **Script Order**: Run scripts in the order listed for best results
6. **Status Tracking**: Use built-in "Status" field for basic workflow, "Dependency Status" for dependency tracking

## 🛡️ Safety Features

- Protection against accidental `gh issue` usage
- Git hooks for command validation
- Draft item support for project-only workflows
- Cleanup utilities for maintaining project hygiene

## 📈 Current Project Status

Based on the Voice Transcription project:
- **5 Epics** created
- **37 User Stories** created and linked to epics
- **74 Engineering Tasks** created and linked to user stories
- **Total: 116 issues** properly organized in the project hierarchy

## 🔄 Working Modes

### Repository-Based Mode
Use when working with GitHub repository issues:
- Issues exist in the repository
- Full GitHub issue features (labels, milestones, assignees)
- Good for open source projects
- Supports sub-issue linking

### Project-Only Mode
Use when you don't need repository issues:
- All items are draft items in the project
- No repository required
- Good for planning and brainstorming
- Can convert to issues later

### Kanban Workflow Mode
Use for pull-based work management:
- **WIP Limits**: In Progress (3), In Review (2), Testing (2)
- **Automatic Selection**: `./utilities/get-next-kanban-item.sh --auto-assign`
- **Daily Workflow**: Check blocks → Update status → Pull work → Complete fast
- **Rules**: See `.claude/kanban-workflow.rules` for complete guidelines

### GitFlow + Kanban Integration Mode
**ENFORCED** workflow combining GitFlow and Kanban:
- **Branch Protection**: Direct commits to main/develop are blocked
- **Auto Task Linking**: Features automatically search for and link tasks
- **Status Automation**: Tasks move from "Todo" → "In Progress" → "Done"
- **Time Tracking**: Features track duration, commits, and completion stats
- **Rules**: See `.claude/gitflow-kanban-rules.md` for enforcement details

#### Quick Workflow:
```bash
git next                          # Get task
git flow feature start <name>     # Start (auto-links)
# ... work ...
git flow feature finish <name>    # Finish (auto-completes)
```

## 📚 Field Configuration

### Type Field
- **Epic**: High-level features or initiatives
- **User Story**: User-facing functionality
- **Task**: Technical implementation work
- **Bug**: Defects or issues to fix
- **Spike**: Research or investigation

### Priority
- **High**: Critical or urgent
- **Medium**: Important but not urgent
- **Low**: Nice to have

### Story Points
- **1, 2**: Small tasks
- **3, 5**: Medium tasks
- **8**: Large tasks
- **13**: Extra large tasks

### Dependency Status
- **Ready**: All dependencies satisfied, ready to start
- **Blocked**: Waiting on dependencies to complete
- **Partial**: Some dependencies satisfied, can start prep work
- **Unknown**: Dependencies not yet analyzed

### Implementation Phase
- **Phase 1**: Foundation - Core Infrastructure
- **Phase 2**: User Management - Quota System
- **Phase 3**: High-Level API - Client Integration
- **Phase 4**: Advanced Features - Optimization
- **Phase 5**: Testing & Production

### Parallelization
- **Sequential**: Must complete before other work can start
- **Parallel**: Can run alongside other development
- **Independent**: No dependencies on or from other work
- **Conditional**: Parallel possible with coordination

### Dependency Risk
- **Critical**: Blocks multiple other items
- **High**: Blocks some important work
- **Medium**: Minor impact on other work
- **Low**: Minimal or no blocking impact

## 🛠️ Requirements

- GitHub CLI (`gh`) installed and authenticated
- `jq` for JSON processing
- Bash shell
- Write access to the repository
- Project permissions for your GitHub account

## 📖 Additional Documentation

- `NO_ISSUES_MODE.md` - Details about gh issue protection
- `project-restoration-summary.md` - Voice Transcription project restoration details
- `task-creation-summary.md` - Summary of task creation process