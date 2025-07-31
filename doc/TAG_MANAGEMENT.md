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

[↑ Back to top](#git-tag-management-guide)

## Tagging Strategy and Conventions

Our tagging strategy is tightly integrated with our [Semantic Versioning](VERSIONING.md) and [Release Workflow](RELEASE_WORKFLOW.md).

### When to Create Tags

Tags are created exclusively for official releases. They are **not** created for every commit. A new tag is generated when:

-   A **MAJOR** release occurs (e.g., `v1.0.0` to `v2.0.0`): Signifies breaking changes.
-   A **MINOR** release occurs (e.g., `v1.1.0` to `v1.2.0`): Signifies new backward-compatible features.
-   A **PATCH** release occurs (e.g., `v1.1.1` to `v1.1.2`): Signifies backward-compatible bug fixes or minor improvements.

These version bumps are primarily determined by the [Conventional Commits](https://www.conventionalcommits.org/) in the Git history and automated by the `version-bump.yml` GitHub Actions workflow.

### Tag Naming Convention

All release tags must follow the `vX.Y.Z` format, where:
-   `v`: A mandatory prefix indicating a version tag.
-   `X`: The major version number.
-   `Y`: The minor version number.
-   `Z`: The patch version number.

**Examples:** `v1.0.0`, `v1.2.3`, `v2.0.0-beta.1` (for prereleases).

This consistent format ensures easy parsing and sorting of tags.

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

[↑ Back to top](#git-tag-management-guide)

## Manual Tag Management with `tag-manager`

The `dev-bin/tag-manager` script provides command-line utilities for local and manual management of Git tags. This is useful for development, specific cleanup tasks, or when direct Git commands are preferred.

### Commands

-   **`./dev-bin/tag-manager list`**: Lists all Git tags in the repository, sorted by version (newest first).
    ```bash
    ./dev-bin/tag-manager list
    ```

-   **`./dev-bin/tag-manager cleanup [count]`**: Interactively cleans up old tags. If `count` is provided, it will keep only the specified number of most recent tags. Otherwise, it will prompt for confirmation for each tag.
    ```bash
    # Interactively clean up tags
    ./dev-bin/tag-manager cleanup

    # Keep only the 5 most recent tags and delete older ones
    ./dev-bin/tag-manager cleanup 5
    ```

-   **`./dev-bin/tag-manager create <version>`**: Creates a new annotated Git tag with the specified version (e.g., `1.2.0`). This should generally be avoided in favor of the automated release workflow unless you have a specific reason.
    ```bash
    # Create a new tag v1.2.0 (use with caution, prefer automated releases)
    ./dev-bin/tag-manager create 1.2.0
    ```

-   **`./dev-bin/tag-manager info <tag>`**: Displays detailed information about a specific tag.
    ```bash
    # Show information about tag v1.1.2
    ./dev-bin/tag-manager info v1.1.2
    ```

[↑ Back to top](#git-tag-management-guide)

## Troubleshooting Tag Issues

If you encounter problems with Git tags, consider the following troubleshooting steps:

### Common Issues

1.  **Too Many Tags**: If your repository has an excessive number of tags, run the automated tag cleanup workflow or use `./dev-bin/tag-manager cleanup`.
2.  **Inconsistent Tag Formats**: Manually identify and delete inconsistently named tags. Ensure all new tags adhere to the `vX.Y.Z` convention.
3.  **Accidental Tags**: If you accidentally create a tag, you can delete it locally and remotely:
    ```bash
    git tag -d <tag_name>             # Delete local tag
    git push origin :refs/tags/<tag_name> # Delete remote tag
    ```
4.  **Automated Workflow Failures**: If the `tag-cleanup.yml` or `version-bump.yml` workflows fail, check the GitHub Actions logs for specific error messages. Common causes include insufficient permissions for the GitHub Token or network issues.

### Useful Git Commands for Tags

-   **List all tags (sorted by version, newest first)**:
    ```bash
    git tag --sort=-version:refname
    ```
-   **Show details of a tag (commit, author, message)**:
    ```bash
    git show <tag_name>
    ```
-   **Compare changes between two tags**:
    ```bash
    git log <old_tag>..<new_tag> --oneline
    ```

[↑ Back to top](#git-tag-management-guide)

## Best Practices for Tagging

Adhering to these best practices will ensure effective and maintainable tag management.

1.  **Automate Tagging**: Whenever possible, rely on the automated release workflow to create tags. This ensures consistency and reduces manual errors.
2.  **Follow Naming Conventions**: Always use the `vX.Y.Z` format for release tags. Consistency is key for tooling and human readability.
3.  **Regular Cleanup**: Utilize the automated tag cleanup workflow to keep your repository tidy. A smaller number of relevant tags is more useful than a large number of irrelevant ones.
4.  **Document Releases**: Ensure that each release tag is accompanied by clear and comprehensive release notes, detailing the changes included. Our automated release workflow handles this.
5.  **Avoid Manual Tag Creation on `main`**: Unless absolutely necessary (e.g., for a hotfix outside the normal release cycle), avoid manually creating tags directly on the `main` branch to prevent conflicts with automation.

[↑ Back to top](#git-tag-management-guide)