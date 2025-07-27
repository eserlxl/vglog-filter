# Developer Guide

This guide provides comprehensive information for developers working on vglog-filter, including build options, versioning system, and testing infrastructure.

## Table of Contents

- [Build Options](#build-options)
  - [Usage with build.sh](#usage-with-buildsh)
- [Versioning System](#versioning-system)
  - [Current Version](#current-version)
  - [Automated Version Bumping](#automated-version-bumping)
  - [Manual Version Management](#manual-version-management)
- [Testing & CI/CD](#testing--cicd)
  - [GitHub Actions Workflows](#github-actions-workflows)
  - [Local Testing](#local-testing)
  - [Development Tools](#development-tools)

## Build Options

This project supports several build modes via CMake options and the `build.sh` script:

- **PERFORMANCE_BUILD**: Enables performance optimizations (`-O3 -march=native -mtune=native -flto`, defines `NDEBUG`).
- **WARNING_MODE**: Enables extra compiler warnings (`-Wextra` in addition to `-Wall -pedantic`).
- **DEBUG_MODE**: Enables debug flags (`-g -O0`, defines `DEBUG`). Mutually exclusive with PERFORMANCE_BUILD (debug takes precedence).

### Usage with build.sh

You can use the `build.sh` script to configure builds with these options:

- Default build:
  ```sh
  ./build.sh
  ```
- Performance build:
  ```sh
  ./build.sh performance
  ```
- Extra warnings:
  ```sh
  ./build.sh warnings
  ```
- Debug build:
  ```sh
  ./build.sh debug
  ```
- Clean build (removes all build artifacts):
  ```sh
  ./build.sh clean
  ```
- Combine options (e.g., debug + warnings):
  ```sh
  ./build.sh debug warnings
  ```
- Performance build with warnings and clean:
  ```sh
  ./build.sh performance warnings clean
  ```

If both `debug` and `performance` are specified, debug mode takes precedence. The `clean` option can be combined with any other options.

[↑ Back to top](#developer-guide)

## Versioning System

vglog-filter uses [Semantic Versioning](https://semver.org/) with automated version management:

### Current Version
The current version is stored in the `VERSION` file and displayed with:
```sh
./vglog-filter --version
# or
./vglog-filter -V
```

**Note**: The version is read from `/usr/share/vglog-filter/VERSION` at runtime. If the file is not accessible, the version will be displayed as "unknown".

### Automated Version Bumping
The project uses GitHub Actions to automatically bump versions based on [Conventional Commits](https://www.conventionalcommits.org/):

- **BREAKING CHANGE**: Triggers a **major** version bump
- **feat**: Triggers a **minor** version bump  
- **fix**: Triggers a **patch** version bump
- **docs**, **style**, **refactor**, **perf**, **test**, **chore**: Triggers a **patch** version bump

### Manual Version Management
For manual version bumps, use the provided tools:

```sh
# Command-line version bump
./dev-bin/bump-version [major|minor|patch] [--commit] [--tag]

# Interactive version bump (Cursor IDE)
./dev-bin/cursor-version-bump
```

[↑ Back to top](#developer-guide)

## Testing & CI/CD

The project includes comprehensive testing infrastructure:

### GitHub Actions Workflows
- **Build and Test**: Multi-platform testing with multiple build configurations
- **Code Security**: Automated security analysis with CodeQL
- **Shell Script Linting**: ShellCheck validation for all scripts
- **Automated Versioning**: Semantic version bumping based on commit messages

### Local Testing
All build configurations are tested locally and in CI:
- Default build
- Performance build (optimized)
- Debug build
- Warnings build (extra compiler warnings)

### Development Tools
The `dev-bin/` directory contains development utilities:
- `bump-version`: Command-line version management
- `cursor-version-bump`: Interactive version bumping for Cursor IDE

[↑ Back to top](#developer-guide) 