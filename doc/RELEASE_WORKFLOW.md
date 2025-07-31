# Release Workflow Guide

This guide outlines the automated and manual processes for creating new releases of `vglog-filter`, leveraging semantic versioning and GitHub Actions. It ensures a consistent and transparent release cycle.

## Table of Contents

- [Overview of the Release Process](#overview-of-the-release-process)
- [Quick Start: Creating a Release](#quick-start-creating-a-release)
  - [1. Analyze Changes](#1-analyze-changes)
  - [2. Review Suggested Version Bump](#2-review-suggested-version-bump)
  - [3. Triggering a Release](#3-triggering-a-release)
- [Detailed Release Workflow](#detailed-release-workflow)
  - [Step 1: Prepare for Release](#step-1-prepare-for-release)
  - [Step 2: Analyze Changes for Versioning](#step-2-analyze-changes-for-versioning)
  - [Step 3: Understanding Automatic Release Thresholds](#step-3-understanding-automatic-release-thresholds)
  - [Step 4: Executing the Release](#step-4-executing-the-release)
  - [Step 5: Verifying the Release](#step-5-verifying-the-release)
  - [Step 6: Post-Release Cleanup (Optional)](#step-6-post-release-cleanup-optional)
- [Examples of Release Scenarios](#examples-of-release-scenarios)
- [Troubleshooting Release Issues](#troubleshooting-release-issues)
- [Best Practices for Releases](#best-practices-for-releases)

## Overview of the Release Process

`vglog-filter` employs a release process primarily driven by [Semantic Versioning (SemVer)](https://semver.org/) and [Conventional Commits](https://www.conventionalcommits.org/). New releases are typically automated via GitHub Actions based on the type of changes merged into the `main` branch. This ensures that version bumps (MAJOR, MINOR, PATCH) accurately reflect the nature of the changes, and release notes are automatically generated.

Key components of the release process include:
-   **`semantic-version-analyzer`**: A utility script (`./dev-bin/semantic-version-analyzer`) that analyzes commit history to suggest the next semantic version bump.
-   **GitHub Actions Workflow (`version-bump.yml`)**: This workflow automates the version bumping, tag creation, and GitHub Release generation based on detected changes.

[↑ Back to top](#release-workflow-guide)

## Quick Start: Creating a Release

This section provides a condensed guide for quickly creating a release.

### 1. Analyze Changes

Before initiating a release, it's good practice to analyze the changes since the last release to understand the suggested version bump. Use the `semantic-version-analyzer` tool:

```bash
# Analyze changes since the last official release
./dev-bin/semantic-version-analyzer --verbose

# Alternatively, analyze changes since a specific Git tag (e.g., v1.1.0)
./dev-bin/semantic-version-analyzer --since v1.1.0 --verbose
```

### 2. Review Suggested Version Bump

The analyzer will output a suggested version bump based on Conventional Commits in the history:
-   **MAJOR**: Indicates breaking changes (`BREAKING CHANGE` in commit footers).
-   **MINOR**: Indicates new features (`feat:` commit type).
-   **PATCH**: Indicates bug fixes (`fix:` commit type).
-   **NONE**: No significant changes warranting a version bump.

### 3. Triggering a Release

#### Option A: Automatic Release (Recommended for most changes)

For most feature additions, bug fixes, or breaking changes, simply push your finalized changes to the `main` branch. The `version-bump.yml` GitHub Actions workflow is configured to automatically detect significant changes (based on predefined thresholds) and trigger a release.

-   Push your changes to `main`:
    ```bash
    git push origin main
    ```
-   Monitor the GitHub Actions tab to see if the "Auto Version Bump with Semantic Release Notes" workflow is triggered and completes successfully.

#### Option B: Manual Release (For specific control or overriding automation)

If you need to manually trigger a release (e.g., for a hotfix, a specific prerelease, or to override the automatic detection):

1.  Navigate to your repository on GitHub.
2.  Go to the **Actions** tab.
3.  Select the workflow named **"Auto Version Bump with Semantic Release Notes"** from the left sidebar.
4.  Click the **"Run workflow"** dropdown button on the right.
5.  Fill in the form:
    -   **Bump type**: Choose `auto` for automatic detection, or explicitly select `major`, `minor`, or `patch`.
    -   **Release notes**: Optionally add custom release notes that will be prepended to the automatically generated notes.
    -   **Prerelease**: Check this box if you are creating a prerelease (e.g., `v1.2.3-beta.1`).
6.  Click **"Run workflow"** to start the release process.

[↑ Back to top](#release-workflow-guide)

## Detailed Release Workflow

This section provides a more in-depth look at each step of the release process.

### Step 1: Prepare for Release

Before initiating any release, ensure your `main` branch is clean, up-to-date, and all intended changes are committed.

```bash
# Ensure your local main branch is synchronized with remote
git checkout main
git pull origin main

# Check for any uncommitted changes
git status

# If there are uncommitted changes, commit them with a Conventional Commit message
git add .
git commit -m "feat: implement new filtering algorithm"

# Push all finalized changes to the main branch
git push origin main
```

### Step 2: Analyze Changes for Versioning

Understanding the impact of your changes on the version number is crucial. The `semantic-version-analyzer` tool helps with this by parsing your Git commit history.

```bash
# Perform a basic analysis to get the suggested bump type
./dev-bin/semantic-version-analyzer

# Get a detailed analysis, including file changes and commit messages
./dev-bin/semantic-version-analyzer --verbose

# Analyze changes since a specific date (e.g., all changes since January 1, 2025)
./dev-bin/semantic-version-analyzer --since-date 2025-01-01

# Analyze changes since a specific commit SHA
./dev-bin/semantic-version-analyzer --since-commit <commit-sha>
```

The analyzer's output will include:
-   **File Changes**: A list of added, modified, and deleted files.
-   **Change Indicators**: Identification of `BREAKING CHANGE`s, `feat:` (features), and `fix:` (bug fixes).
-   **Diff Size**: The total number of lines changed, providing a quantitative measure of the impact.
-   **Recent Commits**: A list of relevant commit messages since the last release.
-   **Version Suggestion**: The recommended semantic version bump (MAJOR, MINOR, PATCH, or NONE).

### Step 3: Understanding Automatic Release Thresholds

The `version-bump.yml` GitHub Actions workflow uses predefined thresholds to determine if an automatic release should be triggered when changes are pushed to `main`:

-   **MAJOR Release**: Triggered if any `BREAKING CHANGE` is detected in the commit history (no size threshold).
-   **MINOR Release**: Triggered if new features (`feat:`) are detected AND the total diff size (lines changed) is greater than 50 lines.
-   **PATCH Release**: Triggered if bug fixes (`fix:`) are detected AND the total diff size is greater than 20 lines.
-   **NO RELEASE**: If changes fall below these thresholds or no significant indicators (breaking, feat, fix) are found, no automatic release will be created.

These thresholds are designed to prevent excessive minor/patch releases for very small changes, while ensuring all significant updates are released promptly.

### Step 4: Executing the Release

As described in the [Quick Start](#3-triggering-a-release) section, you can either rely on the automatic release mechanism by pushing to `main` or manually trigger the GitHub Actions workflow for more control.

**Important**: Avoid manually bumping the `VERSION` file or creating Git tags directly on `main` if you are using the automated GitHub Actions workflow, as this can lead to conflicts or incorrect versioning.

### Step 5: Verifying the Release

After a release workflow has completed, it's essential to verify its success:

1.  **GitHub Actions Status**: Check the GitHub Actions tab to ensure the "Auto Version Bump with Semantic Release Notes" workflow run completed successfully (green checkmark).
2.  **New Git Tag**: Verify that a new Git tag (e.g., `v1.2.3`) corresponding to the new version has been created in your repository.
3.  **GitHub Releases Page**: Navigate to the "Releases" section of your GitHub repository. Confirm that a new release entry exists with the correct version number and automatically generated release notes.
4.  **Artifacts (if any)**: If your release process includes building and attaching artifacts (e.g., compiled binaries), verify that these are present and downloadable.

### Step 6: Post-Release Cleanup (Optional)

Periodically, you might want to clean up old Git tags to keep your repository tidy. This can be done manually or via a GitHub Actions workflow.

```bash
# List all current tags
./dev-bin/tag-manager list

# Clean up old tags, keeping only the 10 most recent ones
./dev-bin/tag-manager cleanup 10
```

Alternatively, you can trigger the **"Tag Cleanup"** GitHub Actions workflow from the Actions tab to automate this process.

[↑ Back to top](#release-workflow-guide)

## Examples of Release Scenarios

Here are practical examples illustrating how different types of changes lead to specific release outcomes.

### Example 1: Bug Fix Release (PATCH)

Suppose you fix a minor bug and commit with `fix: resolve issue with empty input files`.

1.  **Analyze changes**: `./dev-bin/semantic-version-analyzer --verbose` might suggest `PATCH`.
2.  **Trigger release**: Push to `main` or manually trigger the workflow with `patch` bump type.
3.  **Result**: A new patch version (e.g., `v1.0.1` -> `v1.0.2`) is released with notes reflecting the fix.

### Example 2: New Feature Release (MINOR)

You implement a new feature, committing with `feat: add support for custom log formats`.

1.  **Analyze changes**: `./dev-bin/semantic-version-analyzer --verbose` might suggest `MINOR`.
2.  **Trigger release**: Push to `main` or manually trigger the workflow with `minor` bump type.
3.  **Result**: A new minor version (e.g., `v1.0.2` -> `v1.1.0`) is released, including the new feature in the notes.

### Example 3: Breaking Change Release (MAJOR)

You refactor a core API, introducing a breaking change, and your commit message includes `BREAKING CHANGE: Changed API interface for X module` in its footer.

1.  **Analyze changes**: `./dev-bin/semantic-version-analyzer --verbose` will suggest `MAJOR`.
2.  **Trigger release**: Push to `main` or manually trigger the workflow with `major` bump type. You might also consider checking the `Prerelease` box for initial testing.
3.  **Result**: A new major version (e.g., `v1.1.0` -> `v2.0.0`) is released, prominently highlighting the breaking change in the release notes.

[↑ Back to top](#release-workflow-guide)

## Troubleshooting Release Issues

If you encounter problems during the release process, consult these common issues and solutions.

### Common Issues

1.  **Analyzer shows no changes or incorrect suggestion**: Ensure your commit messages follow [Conventional Commits](https://www.conventionalcommits.org/). Verify the `--since` or `--since-date` parameters if you're analyzing a specific range. Sometimes, a `git pull` is needed to get the latest history.
2.  **GitHub Actions workflow fails**: Check the detailed workflow logs in the GitHub Actions tab. Common causes include permission issues (ensure the GitHub Token has write access to releases and tags), network problems, or unexpected script errors.
3.  **Wrong version bump suggested/applied**: Manually review the output of `semantic-version-analyzer --verbose`. If the automation is incorrect, you can manually trigger the workflow and override the bump type.
4.  **Tag cleanup issues**: If `tag-manager cleanup` doesn't work as expected, try running it with a dry-run option (if available) or manually inspect tags with `git tag -l`. Ensure you have the necessary permissions to delete remote tags.

### Getting Help

-   **GitHub Actions Logs**: Always start by examining the detailed logs of the failing workflow run. They provide the most direct clues.
-   **`semantic-version-analyzer` Output**: Review the verbose output of the analyzer to understand why a particular version bump was suggested.
-   **Project Documentation**: Consult the [Versioning Guide](VERSIONING.md) and [CI/CD Guide](CI_CD_GUIDE.md) for more context on how these systems work.
-   **GitHub Issues**: If you suspect a bug in the release tooling or the workflow itself, please [open an issue](https://github.com/eserlxl/vglog-filter/issues).

[↑ Back to top](#release-workflow-guide)

## Best Practices for Releases

Adhering to these best practices will ensure a smooth and reliable release process.

1.  **Regular Analysis**: Run `semantic-version-analyzer` frequently during development and always before a planned release to stay informed about the next version.
2.  **Meaningful Commits**: Consistently write clear, concise, and Conventional Commit-compliant messages. This is the foundation for accurate automated versioning and release notes.
3.  **Review Changes**: Always review the changes that will be included in a release, either by inspecting the `semantic-version-analyzer` output or by reviewing the Git history.
4.  **Test Releases**: For major or complex releases, consider creating a prerelease (e.g., `vX.Y.Z-beta.1`) and thoroughly testing it before promoting to a stable release.
5.  **Post-Release Cleanup**: Periodically clean up old Git tags to maintain a tidy repository and avoid clutter.
6.  **Documentation**: Ensure that any significant changes to the release process or versioning strategy are reflected in this guide and other relevant documentation.

[↑ Back to top](#release-workflow-guide)