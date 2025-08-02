# LOC-Based Delta System

## Overview

The LOC-based delta system is an advanced versioning mechanism that adjusts version increments based on the magnitude of code changes. This system prevents version number inflation while maintaining semantic meaning.

## Problem Solved

For projects with rapid iteration cycles, traditional semantic versioning can lead to version number inflation:
- Small bug fixes increment versions unnecessarily
- Large changes get the same increment as small ones
- Version numbers grow too quickly

## How It Works

### Core Concept
The delta (increment amount) is calculated based on Lines of Code (LOC) changed plus bonus additions for specific types of changes:

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

### Rollover System
- **Patch limit**: 100 (x.y.100 → x.(y+1).0)
- **Minor limit**: 100 (x.100.y → (x+1).0.0)

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

Result: 9.3.0 → 10.0.37 (major)
```

#### Security Fix (100 LOC) with Security Keywords
```bash
Base PATCH: 1 * (1 + 100/250) = 1.4 → 1
Bonus: Security keywords (3 × +2) = +6
Final PATCH: 1 + 6 = 7

Result: 9.3.0 → 9.3.7 (patch)
```

#### New Feature (800 LOC) with New Files
```bash
Base MINOR: 5 * (1 + 800/500) = 13
Bonus: New source files (+1) + New test files (+1) + New doc files (+1) = +3
Final MINOR: 13 + 3 = 16

Result: 9.3.0 → 9.4.16 (minor)
```

#### Rollover Example with Bonuses
```bash
Current: 9.3.95
LOC: 1000
Base patch delta: 5
Bonus: Breaking CLI (+2) + API breaking (+3) = +5
Final delta: 5 + 5 = 10

New patch: 9.3.95 + 10 = 9.4.5 (rollover to next minor)
```

## Configuration

### Environment Variables

```bash
# Enable the system
VERSION_USE_LOC_DELTA=true

# Set limits
VERSION_PATCH_LIMIT=100
VERSION_MINOR_LIMIT=100

# Customize formulas
VERSION_PATCH_DELTA="1*(1+LOC/250)"
VERSION_MINOR_DELTA="5*(1+LOC/500)"
VERSION_MAJOR_DELTA="10*(1+LOC/1000)"

# Customize bonus values
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
- `VERSION_USE_LOC_DELTA=false` (enabled by default)
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

## Benefits

### For Rapid Iteration
- **Proportional versioning**: Bigger changes = bigger version jumps
- **Prevents inflation**: Version numbers stay manageable
- **Predictable progression**: Clear rollover rules
- **Maintains semantics**: Still follows semver principles

### For Different Project Sizes
- **Small projects**: Small changes get small increments
- **Large projects**: Large changes get appropriate increments
- **Configurable**: Can be tuned per project needs

## Testing

Run the test script to see the system in action:

```bash
./test-workflows/core-tests/test_loc_delta_system.sh
```

This demonstrates:
- Small, medium, and large changes
- Delta calculations
- Rollover scenarios
- Configuration options

## Migration

### From Traditional Versioning
1. Enable the system: `export VERSION_USE_LOC_DELTA=true`
2. Continue using normal bump commands
3. The system automatically calculates appropriate deltas

### Backward Compatibility
- The system is enabled by default
- Traditional versioning still works when disabled
- Can be enabled/disabled per project

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
```

## Future Enhancements

### Planned Features
- **Impact-based weighting**: Different weights for different change types
- **Time-based factors**: Consider time since last release
- **Complexity metrics**: Beyond just LOC
- **Project-specific tuning**: Automatic configuration based on project size

### Contributing
The system is designed to be extensible. New delta formulas and detection methods can be easily added. 