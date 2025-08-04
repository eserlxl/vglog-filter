# Git Tag Management Guide

This guide provides comprehensive instructions and best practices for managing Git tags within the `vglog-filter` project. Proper tag management is crucial for maintaining a clean repository, accurately tracking releases, and ensuring consistency with our semantic versioning strategy.

## Table of Contents

- [Overview of Tag Management](#overview-of-tag-management)
- [Tagging Strategy and Conventions](#tagging-strategy-and-conventions)
- [Automated Tag Cleanup](#automated-tag-cleanup)
- [Manual Tag Management with `tag-manager`](#manual-tag-management-with-tag-manager)
- [Troubleshooting Tag Issues](#troubleshooting-tag-issues)
- [Best Practices for Tagging](#best-practices-for-tagging)

## Overview of Tag Management

In `vglog-filter`, Git tags are primarily used to mark official releases and significant milestones. Our approach emphasizes automation and consistency to avoid common issues such as:

-   **Tag Proliferation**: Preventing an excessive number of tags for minor changes.
-   **Inconsistent Formats**: Ensuring all release tags follow a standardized naming convention.
-   **Manual Errors**: Reducing the likelihood of human error in tagging.

This is achieved through:
-   **Semantic Versioning**: All release tags adhere to the `vX.Y.Z` format, reflecting major, minor, and patch versions.
-   **Automated Release Workflow**: New release tags are automatically created by GitHub Actions as part of the [Release Workflow](RELEASE_WORKFLOW.md).
-   **Automated Tag Cleanup**: A dedicated GitHub Actions workflow periodically cleans up old tags.
-   **`tag-manager` Script**: A command-line utility for local and manual tag operations.
-   **LOC-Based Delta System**: Advanced versioning that ensures consistent tag progression.

[↑ Back to top](#git-tag-management-guide)

## Tagging Strategy and Conventions

Our tagging strategy is tightly integrated with our [Semantic Versioning](VERSIONING.md) and [Release Workflow](RELEASE_WORKFLOW.md).

### When to Create Tags

Tags are created exclusively for official releases. They are **not** created for every commit. A new tag is generated when:

-   A **MAJOR** release occurs (e.g., `v10.0.0` to `v11.0.0`): Signifies breaking changes or large-scale refactoring.
-   A **MINOR** release occurs (e.g., `v10.5.0` to `v10.6.0`): Signifies new backward-compatible features.
-   A **PATCH** release occurs (e.g., `v10.5.0` to `v10.5.1`): Signifies backward-compatible bug fixes or minor improvements.

These version bumps are primarily determined by the [Conventional Commits](https://www.conventionalcommits.org/) in the Git history and automated by the `version-bump.yml` GitHub Actions workflow, using the advanced LOC-based delta system.

### Tag Naming Convention

All release tags must follow the `vX.Y.Z` format, where:
-   `v`: A mandatory prefix indicating a version tag.
-   `X`: The major version number.
-   `Y`: The minor version number.
-   `Z`: The patch version number.

**Examples:** `v10.5.0`, `v10.5.1`, `v10.6.0`, `v11.0.0-beta.1` (for prereleases).

This consistent format ensures easy parsing and sorting of tags.

### Current Version Context

The project is currently at version `10.5.0`, using the LOC-based delta system. This means:
- All version changes increment only the patch version (the last number)
- The increment amount is calculated based on Lines of Code (LOC) changed plus bonus additions
- Rollover logic uses mod 100 for patch and minor version limits
- Example progression: `10.5.0` → `10.5.1` → `10.5.2` → ... → `10.6.0` (patch rollover)

[↑ Back to top](#git-tag-management-guide)

## Automated Tag Cleanup

To prevent the accumulation of old or unnecessary tags, `vglog-filter` utilizes an automated tag cleanup workflow.

### GitHub Actions Workflow (`tag-cleanup.yml`)

A dedicated GitHub Actions workflow is responsible for periodically cleaning up old tags from the repository.

-   **Schedule**: By default, this workflow runs every Sunday at 2 AM UTC.
-   **Retention Policy**: It keeps the 10 most recent tags by default. This number is configurable.
-   **Manual Trigger**: The workflow can also be triggered manually from the GitHub Actions interface for immediate cleanup.
-   **Dry Run Mode**: The manual trigger allows for a `dry_run` option, which shows which tags *would* be deleted without actually deleting them.

#### How to Trigger Manually (with Dry Run)

1.  Navigate to your repository on GitHub.
2.  Go to the **Actions** tab.
3.  Select the workflow named **"Tag Cleanup"** from the left sidebar.
4.  Click the **"Run workflow"** dropdown button on the right.
5.  In the form:
    -   Set `keep_count` to your desired number of tags to retain (e.g., `10`).
    -   Set `dry_run` to `true` to preview the deletion without making actual changes.
6.  Click **"Run workflow"**.
7.  Review the workflow logs to see which tags would be deleted. If satisfied, run again with `dry_run` set to `false`.

### Tag Cleanup Strategy

The cleanup strategy prioritizes:
1. **Recent Releases**: Always keep the most recent tags
2. **Major Versions**: Preserve tags representing major version milestones
3. **Stability**: Maintain a clean, manageable tag history
4. **Automation**: Reduce manual maintenance overhead

[↑ Back to top](#git-tag-management-guide)

## Manual Tag Management with `tag-manager`

The `dev-bin/tag-manager` script provides command-line utilities for local and manual management of Git tags. This is useful for development, specific cleanup tasks, or when direct Git commands are preferred.

### Commands

-   **`./dev-bin/tag-manager list`**: Lists all Git tags in the repository, sorted by version (newest first).
    ```bash
    ./dev-bin/tag-manager list
    # Example output:
    # v10.5.0
    # v10.4.0
    # v10.3.0
    # v10.2.0
    # v10.1.0
    ```

-   **`./dev-bin/tag-manager cleanup [count]`**: Interactively cleans up old tags. If `count` is provided, it will keep only the specified number of most recent tags. Otherwise, it will prompt for confirmation for each tag.
    ```bash
    # Interactively clean up tags
    ./dev-bin/tag-manager cleanup

    # Keep only the 5 most recent tags
    ./dev-bin/tag-manager cleanup 5
    ```

-   **`./dev-bin/tag-manager create <version>`**: Creates a new tag with the specified version. Use with caution, as this bypasses the automated release workflow.
    ```bash
    # Create a tag for version 10.5.1 (use with caution)
    ./dev-bin/tag-manager create v10.5.1
    ```

-   **`./dev-bin/tag-manager info <tag>`**: Shows detailed information about a specific tag, including commit hash, author, date, and message.
    ```bash
    # Get information about a specific tag
    ./dev-bin/tag-manager info v10.5.0
    ```

### Advanced Usage

#### Batch Operations
```bash
# List tags matching a pattern
git tag --list "v10.*" | sort -V

# Delete multiple tags locally
git tag -d v10.1.0 v10.2.0 v10.3.0

# Push tag deletions to remote
git push origin --delete v10.1.0 v10.2.0 v10.3.0
```

#### Tag Analysis
```bash
# Show tag history with commit information
git log --tags --oneline --decorate --max-count=10

# Compare two tags
git diff v10.4.0..v10.5.0 --stat

# Show files changed between tags
git diff v10.4.0..v10.5.0 --name-only
```

[↑ Back to top](#git-tag-management-guide)

## Troubleshooting Tag Issues

### Common Issues and Solutions

#### Issue: Tag Conflicts
**Symptoms**: Workflow fails with "tag already exists" error
**Solutions**:
- Check for existing tags: `git tag --list "v*"`
- Delete conflicting tag locally: `git tag -d v10.5.1`
- Delete conflicting tag remotely: `git push origin --delete v10.5.1`
- Re-run the release workflow

#### Issue: Missing Tags
**Symptoms**: Expected tags not present in repository
**Solutions**:
- Check if tags were pushed: `git ls-remote --tags origin`
- Verify local tags: `git tag --list`
- Pull latest tags: `git fetch --tags`
- Check workflow logs for tag creation failures

#### Issue: Tag Ordering Problems
**Symptoms**: Tags not sorted correctly by version
**Solutions**:
- Use version-aware sorting: `git tag --sort=-version:refname`
- Check tag format consistency
- Ensure all tags follow `vX.Y.Z` format
- Use `./dev-bin/tag-manager list` for proper sorting

#### Issue: Cleanup Not Working
**Symptoms**: Tag cleanup workflow fails or doesn't work as expected
**Solutions**:
- Check workflow permissions
- Verify `keep_count` parameter
- Review workflow logs for errors
- Use dry run mode first
- Check for protected tags

### Debugging Commands

```bash
# Check current tags
git tag --list | sort -V

# Verify tag format
git tag --list | grep -E "^v[0-9]+\.[0-9]+\.[0-9]+$"

# Check remote tags
git ls-remote --tags origin

# Show tag details
git show v10.5.0 --stat

# Compare tag dates
git for-each-ref --format='%(refname:short) %(creatordate)' refs/tags | sort -k2
```

### Getting Help

-   **GitHub Actions Logs**: Check the detailed logs of the tag cleanup workflow for specific error messages.
-   **`tag-manager` Output**: Use the verbose output of the tag manager script to understand tag operations.
-   **Git Documentation**: Refer to the [Git Tag Documentation](https://git-scm.com/docs/git-tag) for advanced tag operations.
-   **Project Documentation**: Consult the [Versioning Guide](VERSIONING.md) and [Release Workflow Guide](RELEASE_WORKFLOW.md) for context.

[↑ Back to top](#git-tag-management-guide)

## Best Practices for Tagging

### Automated Tagging

1.  **Rely on Automation**: Let the GitHub Actions workflow handle tag creation for releases. Avoid manually creating tags for official releases.
2.  **Conventional Commits**: Use proper commit message formats to ensure accurate version detection and tag creation.
3.  **Review Before Release**: Always review the suggested version bump before triggering a release.
4.  **Test Prereleases**: Use prerelease tags (e.g., `v11.0.0-beta.1`) for major changes to allow testing before stable release.

### Manual Tagging (When Necessary)

1.  **Use `tag-manager`**: Prefer the `tag-manager` script over direct Git commands for consistency.
2.  **Follow Naming Convention**: Always use the `vX.Y.Z` format for release tags.
3.  **Document Purpose**: Include meaningful commit messages when creating tags manually.
4.  **Coordinate with Team**: Ensure team members are aware of manual tag operations.

### Tag Maintenance

1.  **Regular Cleanup**: Periodically clean up old tags to maintain repository health.
2.  **Monitor Tag Count**: Keep the number of tags manageable (recommended: 10-20 recent tags).
3.  **Preserve Important Tags**: Ensure major version tags are preserved during cleanup.
4.  **Backup Strategy**: Consider backing up important tags before cleanup operations.

### Integration with LOC-Based Delta System

1.  **Understand Delta Calculations**: Be aware of how the LOC-based delta system affects version increments.
2.  **Monitor Rollovers**: Watch for patch and minor version rollovers in the versioning system.
3.  **Configuration Management**: Use the YAML configuration system for consistent versioning behavior.
4.  **Predictable Progression**: The system ensures predictable tag progression with calculated increments.

### Quality Assurance

1.  **Tag Verification**: Always verify that tags are created correctly after release workflows.
2.  **Release Notes**: Ensure release notes are generated and attached to tags.
3.  **Testing**: Test releases locally before pushing tags to remote.
4.  **Documentation**: Keep tag management documentation up-to-date.

### Security Considerations

1.  **Protected Tags**: Consider protecting important tags from accidental deletion.
2.  **Access Control**: Limit tag creation and deletion permissions to authorized users.
3.  **Audit Trail**: Maintain logs of tag operations for security auditing.
4.  **Backup Strategy**: Implement backup strategies for critical tags.

[↑ Back to top](#git-tag-management-guide)