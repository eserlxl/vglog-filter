# Version Management Scripts - Modular Architecture

This directory contains modular version management scripts for the vglog-filter project. The original monolithic `bump-version` script has been split into smaller, focused modules for better maintainability and development.

## Architecture Overview

The modular architecture consists of the following components:

### Core Scripts

- **`bump-version-core`** - Main orchestrator script that coordinates all modules
- **`bump-version`** - Original monolithic script (preserved for backward compatibility)

### Utility Modules

- **`version-utils`** - Common utilities and helper functions
  - Color management
  - Path resolution
  - File operations
  - Git utilities
  - Validation helpers
  - Error handling

- **`version-validator`** - Version format validation and comparison
  - Semantic version validation
  - Version comparison
  - Pre-release handling
  - Version order validation

- **`version-calculator-loc`** - LOC-based version calculation
  - Semantic analyzer integration
  - Rollover logic
  - Delta calculation
  - Configuration management

- **`git-operations`** - Git commit, tag, and push operations
  - Commit creation
  - Tag management
  - Push operations
  - Dirty tree checking
  - Signing support

- **`cmake-updater`** - CMakeLists.txt version updates
  - Version field detection
  - Format-specific updates
  - Dry run simulation
  - Backup/restore functionality

- **`cli-parser`** - Command line argument parsing
  - Option parsing
  - Validation
  - Help generation
  - Environment variable export

## Module Dependencies

```
bump-version-core
├── version-utils
├── cli-parser
├── version-validator
├── version-calculator-loc
├── cmake-updater
└── git-operations
    ├── version-utils
    └── version-validator
```

## Usage

### Using the Modular Script

```bash
# Basic usage (same as original)
./dev-bin/bump-version.sh patch --dry-run
./dev-bin/bump-version.sh minor --commit --tag
./dev-bin/bump-version.sh --set 1.0.0 --allow-prerelease

# Backward compatibility (original script still works)
./dev-bin/bump-version.sh patch --dry-run
```

### Using Individual Modules

Each module can be used independently for specific tasks:

```bash
# Validate version format
./dev-bin/version-validator.sh validate 1.0.0
./dev-bin/version-validator.sh validate 1.0.0-rc.1 true

# Compare versions
./dev-bin/version-validator.sh compare 1.0.0 1.0.1

# Calculate new version
./dev-bin/version-calculator.sh-loc.sh --current-version 1.0.0 --bump-type patch

# Update CMakeLists.txt
./dev-bin/cmake-updater.sh update CMakeLists.txt 1.0.1

# Check git operations
./dev-bin/git-operations.sh check-dirty

# Parse CLI arguments
./dev-bin/cli-parser.sh parse patch --commit --tag
```

## Benefits of Modular Architecture

### Maintainability
- **Single Responsibility**: Each module has a focused purpose
- **Easier Testing**: Individual modules can be tested in isolation
- **Reduced Complexity**: Smaller, more manageable code units
- **Clear Dependencies**: Explicit module relationships

### Development
- **Parallel Development**: Multiple developers can work on different modules
- **Incremental Improvements**: Modules can be enhanced independently
- **Reusability**: Modules can be used by other scripts
- **Debugging**: Easier to isolate and fix issues

### Flexibility
- **Standalone Usage**: Modules can be used independently
- **Custom Integration**: Other scripts can use specific modules
- **Configuration**: Each module can have its own configuration
- **Extensibility**: New modules can be added easily

## Module Details

### version-utils
Common utilities used across all modules:
- Color management with TTY detection
- Path resolution and validation
- File operations with safety checks
- Git repository utilities
- Error handling and logging
- Validation helpers

### version-validator
Handles all version-related validation:
- Semantic version format validation
- Version comparison logic
- Pre-release format support
- Version order validation
- Tag prefix handling

### version-calculator-loc
LOC-based version calculation with semantic analysis:
- Integration with semantic-version-analyzer
- Rollover logic for version limits
- Delta calculation based on code changes
- Configuration via environment variables
- Fallback to default deltas

### git-operations
Comprehensive git operations management:
- Commit creation with proper messages
- Tag creation (lightweight, annotated, signed)
- Push operations for branches and tags
- Dirty tree validation
- Signing key validation
- Summary generation

### cmake-updater
CMakeLists.txt version field management:
- Automatic format detection
- Support for multiple CMake patterns
- Safe file updates with backup
- Dry run simulation
- Validation and error handling

### cli-parser
Robust command line argument handling:
- Comprehensive option parsing
- Validation and error reporting
- Environment variable export
- Help generation
- Backward compatibility

## Migration Guide

### For Users
No changes required - the modular script maintains full backward compatibility with the original `bump-version` script.

### For Developers
- Use `bump-version-core` for new development
- Individual modules can be used for specific tasks
- New features should be added to appropriate modules
- Testing can be done on individual modules

### For CI/CD
- Update workflows to use `bump-version-core` if desired
- Individual modules can be used for specific CI tasks
- No changes required for existing workflows

## Testing

Each module includes standalone usage for testing:

```bash
# Test version validation
./dev-bin/version-validator.sh validate 1.0.0

# Test version calculation
./dev-bin/version-calculator.sh-loc.sh --current-version 1.0.0 --bump-type patch

# Test CMake updates
./dev-bin/cmake-updater.sh detect CMakeLists.txt

# Test git operations
./dev-bin/git-operations.sh check-dirty

# Test CLI parsing
./dev-bin/cli-parser.sh validate patch --commit
```

## Future Enhancements

The modular architecture enables several future enhancements:

1. **Plugin System**: Additional modules for different versioning strategies
2. **Configuration Management**: Centralized configuration for all modules
3. **API Integration**: Modules for external service integration
4. **Advanced Validation**: Enhanced validation rules and custom validators
5. **Multi-format Support**: Support for different version file formats
6. **Audit Trail**: Comprehensive logging and audit capabilities

## Contributing

When contributing to the version management system:

1. **Identify the appropriate module** for your changes
2. **Maintain module boundaries** - don't add unrelated functionality
3. **Update documentation** for any new features
4. **Add tests** for new functionality
5. **Ensure backward compatibility** when possible
6. **Follow the existing patterns** for consistency

## License

All scripts are licensed under the GNU General Public License v3.0 or later, same as the main project. 