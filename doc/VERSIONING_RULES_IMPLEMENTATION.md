# Versioning System Rules Implementation

This document explains how the vglog-filter versioning system implements the specified mathematical rules for version calculation.

## Core Rules Implemented

### 1. LOC-Based Delta Formulas

The system uses the following formulas for calculating base deltas:

- **PATCH**: `VERSION_PATCH_DELTA = 1 * (1 + LOC/250)`
- **MINOR**: `VERSION_MINOR_DELTA = 5 * (1 + LOC/500)`  
- **MAJOR**: `VERSION_MAJOR_DELTA = 10 * (1 + LOC/1000)`

### 2. Bonus Multiplication with LOC Gain

Bonus additions are multiplied by LOC gain using the formula: `(1 + LOC/L)`

Where `L` is the divisor based on version change type:
- **PATCH**: L = 250
- **MINOR**: L = 500
- **MAJOR**: L = 1000

### 3. Mathematical Rollover System

The system uses `MAIN_VERSION_MOD = 1000` for all version components and implements the following rollover logic:

For version `x.y.z` and total delta `delta_z`:

```
z_new = (z + delta_z) % MAIN_VERSION_MOD
delta_y = ((z + delta_z) - (z + delta_z) % MAIN_VERSION_MOD) / MAIN_VERSION_MOD
y_new = (y + delta_y) % MAIN_VERSION_MOD
delta_x = ((y + delta_y) - (y + delta_y) % MAIN_VERSION_MOD) / MAIN_VERSION_MOD
x_new = x + delta_x
```

## Implementation Details

### Version Calculator (`dev-bin/version-calculator.sh`)

The version calculator has been completely rewritten to implement these rules:

1. **Base Delta Calculation**: Uses the specified formulas based on bump type and LOC
2. **Bonus Multiplier**: Calculates `(1 + LOC/L)` where L depends on bump type
3. **Total Delta**: `base_delta + (bonus * bonus_multiplier)`
4. **Mathematical Rollover**: Implements the exact rollover formula specified

### Semantic Version Analyzer (`dev-bin/semantic-version-analyzer.sh`)

The semantic version analyzer correctly:
- Uses **only** the bonus mechanism to determine version bump types
- Does **not** interfere with LOC + bonus logic
- Calculates total bonus points from various sources (CLI changes, security keywords, etc.)
- Uses bonus thresholds to determine suggestion (major/minor/patch)
- Passes the calculated bonus to the version calculator

## Key Features

### 1. Pure Mathematical Logic

- No arbitrary rules or conditions
- All version calculations follow the specified mathematical formulas
- Bonus system is the **only** mechanism for determining bump types
- LOC + bonus logic cannot be prevented by any rules

### 2. Reason Tracking

The system provides detailed reasoning for all calculations:
```
Reason: LOC=100, PATCH update, base_delta=1, bonus=5*1.40=7, total_delta=8
```

This includes:
- LOC value
- Version update type (MAJOR/MINOR/PATCH)
- Base delta calculation
- Bonus multiplication
- Total delta

### 3. Comprehensive Testing

A comprehensive test suite (`test-workflows/core-tests/test_versioning_rules.sh`) verifies:
- All delta formulas work correctly
- Bonus multiplication follows the specified rules
- Rollover logic handles edge cases properly
- Large numbers and multiple rollovers work correctly

## Example Calculations

### Example 1: Basic Patch
- Current: 1.2.3
- LOC: 100, Bonus: 5, Type: patch
- Base delta: 1 * (1 + 100/250) = 1.4 ≈ 1
- Multiplier: 1 + 100/250 = 1.4
- Total bonus: 5 * 1.4 = 7
- Total delta: 1 + 7 = 8
- Result: 1.2.11

### Example 2: Minor with Large LOC
- Current: 1.2.3
- LOC: 500, Bonus: 10, Type: minor
- Base delta: 5 * (1 + 500/500) = 10
- Multiplier: 1 + 500/500 = 2.0
- Total bonus: 10 * 2.0 = 20
- Total delta: 10 + 20 = 30
- Result: 1.2.33

### Example 3: Rollover
- Current: 1.2.995
- LOC: 100, Bonus: 10, Type: patch
- Base delta: 1 * (1 + 100/250) = 1.4 ≈ 1
- Multiplier: 1 + 100/250 = 1.4
- Total bonus: 10 * 1.4 = 14
- Total delta: 1 + 14 = 15
- New patch: 995 + 15 = 1010
- Rollover: 1010 → 1.3.10

## Verification

The system has been thoroughly tested and verified to follow all specified rules:

1. ✅ LOC-based delta formulas implemented correctly
2. ✅ Bonus multiplication with LOC gain implemented
3. ✅ Mathematical rollover system with MAIN_VERSION_MOD=1000
4. ✅ Bonus mechanism is the only way to determine bump types
5. ✅ No rules can prevent LOC + bonus logic
6. ✅ Reason tracking includes all required information
7. ✅ All edge cases and large numbers handled correctly

The versioning system now fully implements the specified mathematical rules and provides a robust, predictable version calculation mechanism. 