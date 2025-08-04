# shellcheck disable=all
# Semantic Version Analyzer - Modular Architecture

This directory contains the refactored semantic version analyzer split into focused, modular components.

## Overview

The original monolithic semantic-version-analyzer \(1782 lines\) has been refactored into smaller, focused binaries that each handle a specific aspect of version analysis.

## Components

### Core Components

#### 1. ref-resolver
- **Purpose**: Resolves git references and determines base references for comparison
- **Key Features**:
  - Handles --since, --since-tag, --since-commit, --since-date options
  - Auto-detects base references \(last tag, parent commit, etc.\)
  - Manages merge-base detection for disjoint branches
  - Validates git references
- **Usage**: ./dev-bin/ref-resolver --since v1.0.0 --target HEAD

#### 2. version-config-loader
- **Purpose**: Loads and validates versioning configuration from YAML files and environment variables
- **Key Features**:
  - Loads configuration from dev-config/versioning.yml
  - Falls back to environment variables
  - Validates configuration values
  - Supports multiple output formats \(JSON, machine-readable\)
- **Usage**: ./dev-bin/version-config-loader --validate-only

#### 3. file-change-analyzer
- **Purpose**: Analyzes file changes and classifies them by type
- **Key Features**:
  - Tracks added, modified, deleted files
  - Classifies files as source, test, documentation
  - Calculates diff size
  - Handles rename/copy detection
- **Usage**: ./dev-bin/file-change-analyzer --base v1.0.0 --target HEAD

#### 4. cli-options-analyzer
- **Purpose**: Detects and analyzes CLI option changes in C/C++ source files
- **Key Features**:
  - Extracts getopt/getopt_long options
  - Detects breaking CLI changes
  - Identifies API breaking changes
  - Manual CLI pattern detection
- **Usage**: ./dev-bin/cli-options-analyzer --base v1.0.0 --target HEAD

#### 5. security-keyword-analyzer
- **Purpose**: Detects security-related keywords in commit messages and code changes
- **Key Features**:
  - Scans commit messages for security keywords
  - Detects CVE references
  - Identifies memory safety issues
  - Counts crash fixes
- **Usage**: ./dev-bin/security-keyword-analyzer --base v1.0.0 --target HEAD

#### 6. version-calculator
- **Purpose**: Calculates next version based on LOC-based delta system and bonus points
- **Key Features**:
  - Implements LOC-based delta formulas
  - Handles version rollover logic
  - Applies bonus points to version increments
  - Supports custom delta formulas
- **Usage**: ./dev-bin/version-calculator --current-version 1.2.3 --bump-type minor --loc 500

### Orchestrator

#### 7. semantic-version-analyzer-v2
- **Purpose**: Orchestrates all modular components for complete version analysis
- **Key Features**:
  - Coordinates all analysis components
  - Calculates total bonus points
  - Determines version bump suggestions
  - Maintains compatibility with original interface
- **Usage**: ./dev-bin/semantic-version-analyzer-v2 --since v1.0.0

## Benefits of Modular Architecture

### 1. **Maintainability**
- Each component has a single responsibility
- Easier to understand and modify individual components
- Reduced complexity per file

### 2. **Testability**
- Individual components can be tested in isolation
- Easier to write unit tests for specific functionality
- Better error isolation

### 3. **Reusability**
- Components can be used independently
- Other tools can leverage specific analysis capabilities
- Easier to integrate into CI/CD pipelines

### 4. **Performance**
- Components can be optimized independently
- Parallel execution possible for independent analyses
- Better resource utilization

### 5. **Extensibility**
- New analysis types can be added as separate components
- Existing components can be enhanced without affecting others
- Plugin-like architecture for custom analyzers

## Migration Guide

### From Original to v2

The original semantic-version-analyzer is still available for backward compatibility. To migrate to the new modular version:

1. **Direct Replacement**: Use semantic-version-analyzer-v2 as a drop-in replacement
2. **Component Usage**: Use individual components for specific analysis needs
3. **Custom Integration**: Combine components for custom workflows

### Example Migration

**Original**:
```bash
./dev-bin/semantic-version-analyzer --since v1.0.0 --verbose
```

**New Modular**:
```bash
./dev-bin/semantic-version-analyzer-v2 --since v1.0.0 --verbose
```

**Component-based**:
```bash
# Get base reference
BASE_REF="$(./dev-bin/ref-resolver --since v1.0.0 --print-base)"

# Analyze file changes
./dev-bin/file-change-analyzer --base "$BASE_REF" --target HEAD --json

# Analyze CLI options
./dev-bin/cli-options-analyzer --base "$BASE_REF" --target HEAD --json

# Calculate version
./dev-bin/version-calculator --current-version 1.2.3 --bump-type minor --loc 500
```

## Configuration

All components support the same configuration system:

1. **YAML Configuration**: dev-config/versioning.yml
2. **Environment Variables**: Fallback configuration
3. **Command Line Options**: Override specific values

## Output Formats

Each component supports multiple output formats:

- **Human-readable**: Default detailed output
- **Machine-readable**: Key=value format for scripting
- **JSON**: Structured data for programmatic consumption

## Error Handling

Each component includes:
- Comprehensive input validation
- Clear error messages
- Appropriate exit codes
- Graceful fallbacks

## Future Enhancements

The modular architecture enables several future enhancements:

1. **Parallel Analysis**: Run independent analyses concurrently
2. **Custom Analyzers**: Add project-specific analysis components
3. **Plugin System**: Load analysis components dynamically
4. **Caching**: Cache analysis results for performance
5. **Distributed Analysis**: Run analyses across multiple machines

## Contributing

When adding new functionality:

1. **Create New Component**: Add a focused binary for new analysis type
2. **Update Orchestrator**: Integrate new component into v2 analyzer
3. **Maintain Compatibility**: Ensure original interface remains functional
4. **Add Documentation**: Update this README with new component details 