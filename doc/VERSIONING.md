# Versioning Strategy

This document describes the versioning strategy used by vglog-filter.

## Semantic Versioning

vglog-filter follows [Semantic Versioning](https://semver.org/) (SemVer) with the format `MAJOR.MINOR.PATCH`:

- **MAJOR** version for incompatible API changes
- **MINOR** version for backwards-compatible functionality additions
- **PATCH** version for backwards-compatible bug fixes

### Version Format Examples

- `1.0.0` → `1.0.1` (bug fix)
- `1.0.1` → `1.1.0` (new feature)
- `1.1.0` → `2.0.0` (breaking change)

## Version Storage and Display

The current version is stored in the `VERSION` file at the project root and is read at runtime from multiple locations in order of preference.

The version is automatically displayed when using the `--version` or `-V` flag:

```bash
vglog-filter --version
# Output: vglog-filter version X.Y.Z
```

**Note**: The version is read from multiple locations in order of preference:
1. `./VERSION` (local development)
2. `../VERSION` (build directory)
3. `/usr/share/vglog-filter/VERSION` (system installation)
4. `/usr/local/share/vglog-filter/VERSION` (local installation)

If none of these files are accessible, the version will be displayed as "unknown".

## Semantic Version Bumping

The project uses a semantic versioning system that analyzes actual code changes and supports both manual and automatic releases based on the significance of changes.

### Automatic Release Detection

The system automatically detects and releases for significant changes using conservative thresholds to prevent rapid version increases:

- **MAJOR releases**: Breaking changes with large diffs (>200 lines)
- **MINOR releases**: New features with significant diffs (>50 lines)
- **PATCH releases**: Bug fixes with notable diffs (>20 lines)
- **No release**: Changes that don't meet the thresholds

**Note**: These conservative thresholds were implemented to prevent rapid version increases and ensure that only truly significant changes trigger automatic releases.

### Semantic Version Analyzer

A dedicated script (`dev-bin/semantic-version-analyzer`) analyzes actual code changes and suggests appropriate version bumps:

```bash
# Analyze changes since last tag
./dev-bin/semantic-version-analyzer

# Analyze changes since specific tag
./dev-bin/semantic-version-analyzer --since vX.Y.Z

# Show detailed analysis
./dev-bin/semantic-version-analyzer --verbose

# Analyze changes since specific date
./dev-bin/semantic-version-analyzer --since-date 2025-01-01
```

### What the Analyzer Checks

The semantic version analyzer examines actual code changes with a focus on CLI tools:

1. **File Changes**:
   - Added files (new source files, test files, documentation)
   - Modified files (existing code changes)
   - Deleted files (removed functionality)

2. **CLI Interface Analysis**:
   - New command-line options (indicates new features)
   - Removed command-line options (breaking changes)
   - Enhanced existing options (non-breaking improvements)
   - New source files (indicates new functionality)
   - New test files (indicates new functionality)
   - New documentation files (indicates new features)

3. **Change Magnitude**:
   - Diff size analysis for threshold-based decisions
   - Conservative thresholds to prevent rapid version increases

### Manual Version Bumping

You can manually trigger version bumps through the GitHub Actions interface:
1. Go to the "Actions" tab in your repository
2. Select "Auto Version Bump with Semantic Release Notes"
3. Click "Run workflow"
4. Choose the bump type (auto, major, minor, patch)
5. Optionally add custom release notes
6. Mark as prerelease if needed

### Automatic vs Manual Releases

The system supports both automatic and manual release workflows:

#### Automatic Releases
- Triggered by significant changes detected by the semantic analyzer
- Uses conservative thresholds to prevent rapid version increases
- Creates releases with automatically generated release notes
- Runs as part of the CI/CD pipeline

#### Manual Releases
- Triggered through GitHub Actions interface
- Allows full control over version bump type
- Supports custom release notes
- Can be used for hotfixes or special releases

## Version Management Tools

### Semantic Version Analyzer

The `dev-bin/semantic-version-analyzer` script provides comprehensive version analysis:

```bash
# Basic analysis
./dev-bin/semantic-version-analyzer

# Detailed analysis with file changes
./dev-bin/semantic-version-analyzer --verbose

# Analyze since specific tag
./dev-bin/semantic-version-analyzer --since vX.Y.Z

# Analyze since specific date
./dev-bin/semantic-version-analyzer --since-date 2025-01-01

# Show help
./dev-bin/semantic-version-analyzer --help
```

### Version Bump Script

The `dev-bin/bump-version` script handles version bumping and release creation:

```bash
# Bump patch version
./dev-bin/bump-version patch

# Bump minor version
./dev-bin/bump-version minor

# Bump major version
./dev-bin/bump-version major

# Auto-detect bump type
./dev-bin/bump-version auto
```

### Tag Manager

The `dev-bin/tag-manager` script provides tag management capabilities:

```bash
# List all tags
./dev-bin/tag-manager list

# Clean up old tags
./dev-bin/tag-manager cleanup [count]

# Create new tag
./dev-bin/tag-manager create <version>

# Show tag info
./dev-bin/tag-manager info <tag>
```

## Release Process

### 1. Prepare for Release

Before creating a release, ensure your changes are ready:

```bash
# Check current status
git status

# Make sure all changes are committed
git add .
git commit -m "feat: final changes before release"

# Push to main
git push origin main
```

### 2. Analyze Changes

Use the semantic version analyzer to understand what changed:

```bash
# Basic analysis
./dev-bin/semantic-version-analyzer

# Detailed analysis with file changes
./dev-bin/semantic-version-analyzer --verbose
```

### 3. Create Release

#### Option A: Automatic Release (Recommended)
- Simply push your changes to main
- If significant changes are detected, a release will be created automatically
- Check GitHub Actions to monitor the process

#### Option B: Manual Release
1. Go to GitHub → Actions → "Auto Version Bump with Semantic Release Notes"
2. Click "Run workflow"
3. Choose the suggested bump type (or "auto" for automatic detection)
4. Add custom release notes (optional)
5. Mark as prerelease if needed
6. Click "Run workflow"

## Version History

### Recent Releases

The project maintains a version history that can be viewed using:

```bash
# List all version tags
git tag --sort=-version:refname

# Show recent releases
git log --oneline --tags --decorate --max-count=10
```

### Version Evolution

The project has evolved through several major versions:

- **v1.x**: Initial development and basic functionality
- **v2.x**: Performance improvements and large file support
- **v3.x**: Advanced features and comprehensive testing
- **v4.x**: Current major version with semantic versioning and CI/CD improvements

## Best Practices

### When to Bump Versions

- **MAJOR**: Breaking changes, incompatible API modifications
- **MINOR**: New features, backward-compatible additions
- **PATCH**: Bug fixes, minor improvements, documentation updates

### Commit Message Guidelines

Follow [Conventional Commits](https://www.conventionalcommits.org/) for automatic version detection:

```bash
# Major version bump
git commit -m "feat!: breaking change"

# Minor version bump
git commit -m "feat: new feature"

# Patch version bump
git commit -m "fix: bug fix"
```

### Release Notes

- Include a summary of changes
- List new features and improvements
- Document breaking changes
- Mention bug fixes and security updates
- Include migration notes if needed

## Troubleshooting

### Common Issues

1. **Version not detected**: Ensure the VERSION file exists and is readable
2. **Automatic release not triggered**: Check if changes meet the conservative thresholds
3. **Tag conflicts**: Use the tag manager to clean up old tags
4. **Build failures**: Ensure all tests pass before creating releases

### Getting Help

- Check the [FAQ](FAQ.md) for common questions
- Review the [Developer Guide](DEVELOPER_GUIDE.md) for detailed information
- Open an issue for bugs or feature requests
- Check GitHub Actions for build and test status

---

For more information about the release workflow, see [RELEASE_WORKFLOW.md](RELEASE_WORKFLOW.md).
For tag management strategies, see [TAG_MANAGEMENT.md](TAG_MANAGEMENT.md). 
