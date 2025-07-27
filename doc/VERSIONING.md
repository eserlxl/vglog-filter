# Versioning Strategy

This document describes the versioning strategy used by vglog-filter.

## Semantic Versioning

vglog-filter follows [Semantic Versioning](https://semver.org/) (SemVer) with the format `MAJOR.MINOR.PATCH`:

- **MAJOR** version for incompatible API changes
- **MINOR** version for backwards-compatible functionality additions
- **PATCH** version for backwards-compatible bug fixes

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

```bash
# Bump patch version (1.0.0 -> 1.0.1)
./dev-bin/bump-version patch

# Bump minor version (1.0.0 -> 1.1.0)
./dev-bin/bump-version minor

# Bump major version (1.0.0 -> 2.0.0)
./dev-bin/bump-version major

# Bump and commit changes
./dev-bin/bump-version patch --commit
```

## Version File

The current version is stored in the `VERSION` file at the project root. This file is automatically updated by the version bump workflow and should not be manually edited.

## Release Process

1. Commits are pushed to the `main` branch
2. GitHub Actions analyzes commit messages for conventional commit types
3. If conventional commits are found, the version is automatically bumped
4. A new release is created with the bumped version
5. Release notes are automatically generated from conventional commits

## Version History

- `1.0.0` - Initial release 