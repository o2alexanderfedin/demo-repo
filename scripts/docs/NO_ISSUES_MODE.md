# No-Issues Mode: Enforcing Project-Only Workflows

This directory contains tools to prevent the use of GitHub Issues (`gh issue` commands) and enforce a project-only workflow using draft items.

## Why No-Issues Mode?

When working exclusively with GitHub Projects and draft items:
- No repository coupling required
- Simpler permissions model
- Faster to create and manage items
- No issue number conflicts
- Better for non-code planning

## Protection Levels

### 1. Session Protection (`no-issues-mode.sh`)

Temporary protection for current shell session.

```bash
# Activate protection
source ./no-issues-mode.sh

# Try to use gh issue (will fail)
gh issue create  # ❌ ERROR: Repository issues are disabled!

# Deactivate protection
unset -f gh
```

### 2. User-Level Protection (`install-no-issues-mode.sh`)

Permanent protection in your shell configuration.

```bash
# Install protection
./install-no-issues-mode.sh

# Protection active in all new shells
# To disable: Edit ~/.bashrc or ~/.zshrc and remove NO_GITHUB_ISSUES_MODE section
```

### 3. Project-Level Protection (`setup-project-hooks.sh`)

Git hooks that prevent committing code with `gh issue` commands.

```bash
# Install in current project
./setup-project-hooks.sh

# Now commits containing "gh issue" will be blocked
echo "gh issue create" > script.sh
git add script.sh
git commit -m "Add script"  # ❌ ERROR: Found 'gh issue' commands!
```

## How It Works

### Shell Function Override
```bash
gh() {
    if [ "$1" = "issue" ]; then
        echo "ERROR: Repository issues are disabled!"
        return 1
    else
        command gh "$@"  # Allow other gh commands
    fi
}
```

### Pre-commit Hook
- Scans staged files for "gh issue" patterns
- Blocks commits containing forbidden commands
- Provides helpful alternatives

### Commit Template
- Reminds developers about the no-issues policy
- Suggests project-only alternatives

## Alternatives to Common Commands

| Instead of... | Use... |
|--------------|--------|
| `gh issue create` | `gh project item-create` or draft items |
| `gh issue list` | `gh project item-list` |
| `gh issue edit` | GraphQL API with updateProjectV2Item |
| `gh issue close` | Update Status field to "Done" |

## GraphQL Examples

### Create Draft Item
```bash
gh api graphql -f query='
mutation {
  addProjectV2DraftIssue(input: {
    projectId: "PROJECT_ID"
    title: "New Feature"
    body: "Description here"
  }) {
    projectV2Item {
      id
    }
  }
}'
```

### List Project Items
```bash
gh api graphql -f query='
query {
  node(id: "PROJECT_ID") {
    ... on ProjectV2 {
      items(first: 20) {
        nodes {
          id
          content {
            ... on DraftIssue {
              title
              body
            }
          }
        }
      }
    }
  }
}'
```

## Enforcement Strategies

### For Teams

1. **Soft Enforcement**: Documentation and training
2. **Medium Enforcement**: Shared shell aliases
3. **Hard Enforcement**: Git hooks + CI/CD checks

### CI/CD Integration

Add to your GitHub Actions:

```yaml
- name: Check for forbidden commands
  run: |
    if grep -r "gh issue" . --include="*.sh"; then
      echo "::error::Found forbidden 'gh issue' commands"
      exit 1
    fi
```

## Removing Protection

### Session Level
```bash
unset -f gh
unalias 'gh issue' 2>/dev/null
```

### User Level
Edit `~/.bashrc` or `~/.zshrc` and remove the `NO_GITHUB_ISSUES_MODE` section.

### Project Level
```bash
rm .git/hooks/pre-commit
git config --local --unset commit.template
```

## Best Practices

1. **Be Consistent**: Either use issues OR draft items, not both
2. **Document Choice**: Make it clear in README why you chose project-only
3. **Provide Tools**: Share scripts for common operations
4. **Train Team**: Ensure everyone understands the workflow

## Troubleshooting

**Q: I need to use gh issue for another project**
A: Temporarily disable with `unset -f gh` or use `command gh issue ...`

**Q: CI/CD is failing due to gh issue commands**
A: Update scripts to use project-only commands or GraphQL API

**Q: How do I reference items without issue numbers?**
A: Use project item IDs or create your own numbering in titles (e.g., "TASK-001")