# VGLOG-FILTER C++ Test Suite

This directory contains the C++ unit tests for the vglog-filter project.

**For comprehensive testing documentation, see [TEST_SUITE.md](../doc/TEST_SUITE.md)**

## Quick Reference

### Test Files

- `test_basic.cpp` - Basic functionality tests
- `test_comprehensive.cpp` - Comprehensive feature tests
- `test_edge_cases.cpp` - Edge case and boundary condition tests
- `test_integration.cpp` - Integration tests
- `test_memory_leaks.cpp` - Memory leak detection tests

### Running Tests

```bash
# Run all tests (C++ + test-workflows)
./run_tests.sh

# Run only C++ tests
./test/run_all_tests.sh

# Manual build and run
mkdir -p build-test && cd build-test
cmake .. -DBUILD_TESTING=ON -DCMAKE_BUILD_TYPE=Debug
make -j20
ctest --output-on-failure
```

### Adding New Tests

1. Create a new `.cpp` file following the naming convention: `test_*.cpp`
2. The test will be automatically picked up by CMake
3. Use standard C++ testing practices (assertions, etc.)

For detailed information about test configuration, debugging, and CI/CD integration, see the [Test Suite Documentation](../doc/TEST_SUITE.md). 