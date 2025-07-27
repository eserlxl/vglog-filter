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

The current version is stored in the `VERSION` file at the project root:

```
1.0.0
```

The version is automatically displayed when using the `--version` or `-v` flag:

```bash
vglog-filter --version
# Output: vglog-filter version 1.0.0
```

## Automated Version Bumping

The project uses GitHub Actions to automatically bump versions based on conventional commit messages:

### Commit Message Format

Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Version Bump Rules

- **BREAKING CHANGE**: Triggers a **major** version bump
- **feat**: Triggers a **minor** version bump
- **fix**: Triggers a **patch** version bump
- **docs**, **style**, **refactor**, **perf**, **test**, **chore**: Triggers a **patch** version bump

### Examples

```bash
# Major version bump (breaking change)
git commit -m "feat: change API interface

BREAKING CHANGE: The filter() method now requires a config object"

# Minor version bump (new feature)
git commit -m "feat: add support for custom log formats"

# Patch version bump (bug fix)
git commit -m "fix: handle empty input files correctly"

# Patch version bump (documentation)
git commit -m "docs: update installation instructions"
```

## Manual Version Bumping

To manually bump the version, use the `dev-bin/bump-version` script:

### Usage

```bash
./dev-bin/bump-version [major|minor|patch] [--commit] [--tag]
```

### Arguments

- **major**: Increment major version (breaking changes)
- **minor**: Increment minor version (new features)
- **patch**: Increment patch version (bug fixes)

### Options

- **--commit**: Create a git commit with the version bump
- **--tag**: Create a git tag for the new version

### Examples

```bash
# Bump patch version (1.0.0 -> 1.0.1)
./dev-bin/bump-version patch

# Bump minor version (1.0.0 -> 1.1.0)
./dev-bin/bump-version minor

# Bump major version (1.0.0 -> 2.0.0)
./dev-bin/bump-version major

# Bump and commit changes
./dev-bin/bump-version patch --commit

# Bump minor version, commit, and tag
./dev-bin/bump-version minor --commit --tag
```

## When to Bump Versions

### Patch Version (1.0.0 → 1.0.1)
- Bug fixes
- Minor improvements
- Documentation updates
- Code style changes
- Performance optimizations

### Minor Version (1.0.0 → 1.1.0)
- New features (backward-compatible)
- New CLI options
- Enhanced functionality
- New modes or capabilities

### Major Version (1.0.0 → 2.0.0)
- Breaking changes to CLI interface
- Incompatible changes to configuration
- Major architectural changes
- Removal of deprecated features

## Git Integration

### Tags
Each release should be tagged with the version number:

```bash
git tag v1.0.0
git push origin v1.0.0
```

### Commits
Version bumps should be committed with clear messages:

```bash
git commit -m "Bump version to 1.0.1"
```

## Release Process

### Automated Release Process (Recommended)

1. Commits are pushed to the `main` branch
2. GitHub Actions analyzes commit messages for conventional commit types
3. If conventional commits are found, the version is automatically bumped
4. A new release is created with the bumped version
5. Release notes are automatically generated from conventional commits

### Manual Release Process

1. **Determine the appropriate version bump type**
   - Patch for bug fixes
   - Minor for new features
   - Major for breaking changes

2. **Bump the version**
   ```bash
   ./dev-bin/bump-version patch --commit --tag
   ```

3. **Push changes**
   ```bash
   git push origin main
   git push origin v1.0.1
   ```

4. **Create GitHub release** (optional)
   - Go to GitHub repository
   - Create a new release from the tag
   - Add release notes

## Version in Code

The version is automatically read from the `VERSION` file and made available as the `VGLOG_FILTER_VERSION` environment variable in the main script.

### Accessing Version in Scripts

```bash
# In any sourced script
echo "vglog-filter version: $VGLOG_FILTER_VERSION"
```

## Best Practices

1. **Always bump version before releasing**
2. **Use semantic versioning consistently**
3. **Tag releases with git tags**
4. **Write clear commit messages for version bumps**
5. **Document breaking changes in release notes**
6. **Test thoroughly before releasing**

## Pre-release Versions

For development and testing, you can use pre-release suffixes:

- `1.0.0-alpha.1` (alpha releases)
- `1.0.0-beta.1` (beta releases)
- `1.0.0-rc.1` (release candidates)

These should be manually edited in the `VERSION` file and tagged accordingly.

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-01-XX | Initial release |

## Related Files

- `VERSION` - Current version number
- `dev-bin/bump-version` - Version bumping script
- `src/vglog-filter.cpp` - Main source file (reads version)
- `build.sh` - Build script (may reference version)

## Version File

The current version is stored in the `VERSION` file at the project root. This file is automatically updated by the version bump workflow and should not be manually edited. 