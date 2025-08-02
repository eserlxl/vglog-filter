# LOC-Based Delta System

## Overview

The LOC-based delta system is an advanced versioning mechanism that **always increases only the last identifier (patch)** with a delta calculated based on the magnitude of code changes. This system prevents version number inflation while maintaining semantic meaning and provides intelligent rollover logic.

## Problem Solved

For projects with rapid iteration cycles, traditional semantic versioning can lead to version number inflation:
- Small bug fixes increment versions unnecessarily
- Large changes get the same increment as small ones
- Version numbers grow too quickly
- **New Problem**: Restrictive thresholds prevent meaningful changes from getting version bumps

## How It Works

### Core Concept
The new versioning system **always increases only the last identifier (patch)** with a delta calculated based on Lines of Code (LOC) changed plus bonus additions for specific types of changes. **Every change now results in at least a patch bump**, with the LOC-based system determining the actual increment amount:

```bash
# Base delta from LOC
PATCH: 1 * (1 + LOC/250)  # Small changes get small increments
MINOR: 5 * (1 + LOC/500)  # Medium changes get medium increments  
MAJOR: 10 * (1 + LOC/1000) # Large changes get large increments

# Bonus additions for impact
+ Breaking CLI changes: +2
+ API breaking changes: +3
+ Removed options: +1
+ CLI changes: +2
+ New files: +1 each
+ Security keywords: +2 each
```

### Key Features

1. **Always Increase Only the Last Identifier**: All version changes increment only the patch version (the last number)
2. **LOC-Based Delta Calculation**: The increment amount is calculated based on Lines of Code (LOC) changed plus bonus additions
3. **Rollover Logic**: Uses mod 100 for patch and minor version limits with automatic rollover
4. **Enhanced Reason Format**: Includes LOC value and version type in analysis output

### Bonus System
The system automatically detects and applies bonuses for:

#### Breaking Changes
- **Breaking CLI changes**: +2 (CLI option removals)
- **API breaking changes**: +3 (function signature changes, removed prototypes)
- **Removed options**: +1 (short or long option removals)

#### Feature Additions
- **CLI changes**: +2 (new CLI options added)
- **Manual CLI changes**: +1 (manual CLI detection)
- **New source files**: +1 each
- **New test files**: +1 each
- **New documentation**: +1 each
- **Added options**: +1 (short or long option additions)

#### Security Fixes
- **Security keywords**: +2 each (security-related terms in code)

### Universal Patch Detection
**Every change now results in at least a patch bump**, regardless of size. The old restrictive thresholds (requiring both file count AND line count) have been replaced with a permissive approach:

- **Any modified files > 0** OR **any diff size > 0** triggers a patch bump
- The LOC-based delta system then calculates the actual increment amount
- This ensures no meaningful changes are missed

### New Rollover System
The system implements intelligent rollover logic:

- **Patch rollover**: When patch + delta >= 100, apply mod 100 and increment minor
- **Minor rollover**: When minor + 1 >= 100, apply mod 100 and increment major
- **Example**: 9.3.95 + 6 = 9.4.1 (patch rollover)
- **Example**: 9.99.95 + 6 = 10.0.1 (minor rollover)

### Enhanced Reason Format
The system now provides enhanced analysis output that includes:
- **LOC value**: The actual lines of code changed
- **Version type**: MAJOR, MINOR, or PATCH
- **Example**: "cli_added (LOC: 200, MINOR)"

### Examples

#### Small Change (50 LOC) - No Bonuses
```bash
PATCH: 1 * (1 + 50/250) = 1.2 → 1
MINOR: 5 * (1 + 50/500) = 5.5 → 5
MAJOR: 10 * (1 + 50/1000) = 10.5 → 10

Result: 9.3.0 → 9.3.1 (patch)
```

#### Medium Change (500 LOC) with CLI Additions
```bash
Base PATCH: 1 * (1 + 500/250) = 3
Bonus: CLI changes (+2) + Added options (+1) = +3
Final PATCH: 3 + 3 = 6

Result: 9.3.0 → 9.3.6 (patch)
```

#### Large Change (2000 LOC) with Breaking Changes
```bash
Base MAJOR: 10 * (1 + 2000/1000) = 30
Bonus: Breaking CLI (+2) + API breaking (+3) + Removed options (+2) = +7
Final MAJOR: 30 + 7 = 37

Result: 9.3.0 → 9.3.37 (major)
```

#### Security Fix (100 LOC) with Security Keywords
```bash
Base PATCH: 1 * (1 + 100/250) = 1.4 → 1
Bonus: Security keywords (3 × +2) = +6
Final PATCH: 1 + 6 = 7

Result: 9.3.0 → 9.3.7 (patch)
```

#### Rollover Examples
```bash
# Patch rollover
9.3.95 + 6 = 9.4.1

# Minor rollover  
9.99.95 + 6 = 10.0.1

# Double rollover
9.99.99 + 1 = 10.0.0
```

## Configuration

### Environment Variables
```bash
# Enable the new versioning system
VERSION_USE_LOC_DELTA=true

# Delta formulas
VERSION_PATCH_DELTA="1*(1+LOC/250)"
VERSION_MINOR_DELTA="5*(1+LOC/500)"
VERSION_MAJOR_DELTA="10*(1+LOC/1000)"

# Rollover limits
VERSION_PATCH_LIMIT=100
VERSION_MINOR_LIMIT=100

# Bonus values
VERSION_BREAKING_CLI_BONUS=2
VERSION_API_BREAKING_BONUS=3
VERSION_REMOVED_OPTION_BONUS=1
VERSION_CLI_CHANGES_BONUS=2
VERSION_MANUAL_CLI_BONUS=1
VERSION_NEW_SOURCE_BONUS=1
VERSION_NEW_TEST_BONUS=1
VERSION_NEW_DOC_BONUS=1
VERSION_ADDED_OPTION_BONUS=1
VERSION_SECURITY_BONUS=2
```

### Default Values
- `VERSION_USE_LOC_DELTA=true` (enabled by default)
- `VERSION_PATCH_LIMIT=100`
- `VERSION_MINOR_LIMIT=100`
- `VERSION_PATCH_DELTA="1*(1+LOC/250)"`
- `VERSION_MINOR_DELTA="5*(1+LOC/500)"`
- `VERSION_MAJOR_DELTA="10*(1+LOC/1000)"`
- `VERSION_BREAKING_CLI_BONUS=2`
- `VERSION_API_BREAKING_BONUS=3`
- `VERSION_REMOVED_OPTION_BONUS=1`
- `VERSION_CLI_CHANGES_BONUS=2`
- `VERSION_MANUAL_CLI_BONUS=1`
- `VERSION_NEW_SOURCE_BONUS=1`
- `VERSION_NEW_TEST_BONUS=1`
- `VERSION_NEW_DOC_BONUS=1`
- `VERSION_ADDED_OPTION_BONUS=1`
- `VERSION_SECURITY_BONUS=2`

## Usage

### Enable the System
```bash
export VERSION_USE_LOC_DELTA=true
```

### Normal Version Bumping
```bash
# The system automatically calculates deltas based on LOC
# All bumps now increment only the patch version with calculated delta
./dev-bin/bump-version patch --commit
./dev-bin/bump-version minor --commit
./dev-bin/bump-version major --commit
```

### View Delta Calculations
```bash
# See calculated deltas in verbose mode
./dev-bin/semantic-version-analyzer --verbose

# Get JSON output with delta information
./dev-bin/semantic-version-analyzer --json
```

### Custom Formulas
```bash
# Use different scaling factors
export VERSION_PATCH_DELTA="1*(1+LOC/100)"   # More aggressive
export VERSION_MINOR_DELTA="3*(1+LOC/300)"   # Less aggressive
export VERSION_MAJOR_DELTA="5*(1+LOC/500)"   # Conservative
```

## Integration with Semantic Analyzer

The system integrates seamlessly with the existing semantic version analyzer:

### What It Detects
- **Breaking changes**: API changes, CLI removals, signature changes
- **Feature additions**: New CLI options, new files, new functionality
- **Change magnitude**: Lines of code changed, file counts
- **Security issues**: Security-related keywords and patterns

### Enhanced Analysis
When enabled, the analyzer provides:
- LOC-based delta calculations
- Rollover warnings
- Detailed change analysis
- JSON output with delta information
- Enhanced reason format with LOC and version type

## Benefits

### For Rapid Iteration
- **Proportional versioning**: Bigger changes = bigger version jumps
- **Prevents inflation**: Version numbers stay manageable
- **Predictable progression**: Clear rollover rules with mod 100
- **Maintains semantics**: Still follows semver principles
- **Always increases patch**: Consistent behavior across all change types

### For Different Project Sizes
- **Small projects**: Small changes get small increments
- **Large projects**: Large changes get appropriate increments
- **Configurable**: Can be tuned per project needs
- **Rollover protection**: Prevents version number overflow

## Testing

Run the comprehensive test suite to see the system in action:

```bash
# Test the new versioning system
./test-workflows/core-tests/test_new_version_system.sh

# Test rollover logic
./test-workflows/core-tests/test_rollover_logic.sh

# Test LOC delta system
./test-workflows/core-tests/test_loc_delta_system.sh

# Test bump-version integration
./test-workflows/core-tests/test_bump_version_loc_delta.sh
```

This demonstrates:
- Small, medium, and large changes
- Delta calculations with new formulas
- Rollover scenarios with mod 100 logic
- Configuration options
- Enhanced reason format
- Integration with semantic analyzer

## Migration

### From Traditional Versioning
1. Enable the system: `export VERSION_USE_LOC_DELTA=true`
2. Continue using normal bump commands
3. The system automatically calculates appropriate deltas
4. All changes now increment only the patch version

### Backward Compatibility
- The system is enabled by default
- Traditional versioning still works when disabled
- Can be enabled/disabled per project
- Existing workflows continue to function

## Advanced Configuration

### Custom Scaling
```bash
# Logarithmic scaling
VERSION_PATCH_DELTA="1 + log(1+LOC/50)"

# Exponential scaling (for very large changes)
VERSION_MAJOR_DELTA="10 * (1 + LOC/1000)^0.5"

# Different limits for different project types
VERSION_PATCH_LIMIT=50   # For small projects
VERSION_MINOR_LIMIT=25   # For rapid iteration
```

### Impact-Based Weighting
```bash
# Weight different types of changes
VERSION_SOURCE_WEIGHT=1.0    # Source code changes
VERSION_TEST_WEIGHT=0.5      # Test changes
VERSION_DOC_WEIGHT=0.3       # Documentation changes
```

## Troubleshooting

### Common Issues

#### Delta Not Calculating
- Ensure `VERSION_USE_LOC_DELTA=true`
- Check that semantic analyzer is executable
- Verify LOC data is available

#### Unexpected Rollovers
- Check current version numbers
- Review LOC calculations
- Adjust limits if needed
- Remember: all changes increment only patch version

#### Formula Errors
- Ensure formulas use valid syntax
- Check for division by zero
- Validate numeric inputs

### Debug Mode
```bash
# Enable verbose output
./dev-bin/semantic-version-analyzer --verbose

# Check JSON output
./dev-bin/semantic-version-analyzer --json | jq '.loc_delta'

# Test rollover logic directly
./test-workflows/core-tests/test_rollover_logic.sh
```

## Future Enhancements

### Planned Features
- **Impact-based weighting**: Different weights for different change types
- **Time-based factors**: Consider time since last release
- **Complexity metrics**: Beyond just LOC
- **Project-specific tuning**: Automatic configuration based on project size
- **Enhanced rollover visualization**: Better display of rollover scenarios

### Contributing
The system is designed to be extensible. New delta formulas and detection methods can be easily added. The new versioning system maintains backward compatibility while providing enhanced functionality. 