# Backup Files

This directory contains alternative implementations that were created during the development of the simple string matching solution to address MemorySanitizer warnings.

## Files

### `log_processor_alternative.cpp`
**Simple String Matching Implementation**
- Complete alternative implementation using simple string matching functions
- Replaces all regex functionality with custom string operations
- No external dependencies, uses only standard C++ library
- **Status**: Reference implementation (not used in production)

### `log_processor_pcre2.cpp`
**PCRE2 Library Implementation**
- Alternative implementation using PCRE2 regex library
- Requires external PCRE2 dependency (pcre2-dev package)
- MSan-clean regex library with better performance than std::regex
- **Status**: Reference implementation (not used in production)

### `log_processor_suppressed.cpp`
**Compiler Suppressions Implementation**
- Implementation using compiler-specific pragmas to suppress MSan warnings
- Keeps std::regex functionality but suppresses warnings
- Not portable across different compilers
- **Status**: Reference implementation (not used in production)

## Why These Are Here

These files were created during the exploration of different approaches to solve the MemorySanitizer warnings in the C++ standard library regex implementation. They serve as:

1. **Reference implementations** for future consideration
2. **Documentation** of alternative approaches
3. **Backup** in case we need to revisit these approaches
4. **Educational** examples of different solutions

## Current Solution

The production code now uses **simple string matching** implemented directly in:
- `src/log_processor.cpp`
- `include/log_processor.h`
- `src/canonicalization.cpp`
- `include/canonicalization.h`

This approach was chosen because it:
- ✅ Eliminates all regex-related MSan warnings
- ✅ Provides better performance for simple patterns
- ✅ Has no external dependencies
- ✅ Is easier to maintain and debug

## Comparison

See `test-workflows/ALTERNATIVE_APPROACHES.md` for a detailed comparison of all approaches.

## Usage

These files are **not compiled** or used in the current build system. They are kept for reference only. If you need to use one of these approaches:

1. Copy the desired file back to `src/`
2. Update the build system if needed
3. Update the main implementation to use the alternative approach

## Last Updated

These files were created during the MSan warning resolution project and moved to this backup directory after the simple string matching solution was successfully implemented. 