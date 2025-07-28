# CI/CD and Testing Guide

This guide provides comprehensive information about the Continuous Integration and Continuous Deployment (CI/CD) infrastructure for vglog-filter, including GitHub Actions workflows, testing procedures, and quality assurance processes.

## Table of Contents

- [Overview](#overview)
- [GitHub Actions Workflows](#github-actions-workflows)
- [Build Configurations](#build-configurations)
- [Testing Procedures](#testing-procedures)
- [Quality Assurance](#quality-assurance)
- [Development Workflow](#development-workflow)

## Overview

The vglog-filter project uses a comprehensive CI/CD pipeline built on GitHub Actions to ensure code quality, reliability, and cross-platform compatibility. The pipeline automatically tests all build configurations, performs security analysis, and validates code quality across multiple platforms.

## GitHub Actions Workflows

### Core Testing Workflows

#### 1. Build and Test (`test.yml`)
- **Purpose**: Basic build verification and functionality testing
- **Triggers**: Push to `src/`, `CMakeLists.txt`, `build.sh`, or workflow changes
- **Matrix**: Tests 4 build configurations (default, performance, debug, warnings)
- **Features**:
  - Builds with different optimization levels
  - Tests basic functionality and help output
  - Verifies binary characteristics
  - Tests with sample input data

#### 2. Comprehensive Test (`comprehensive-test.yml`)
- **Purpose**: Complete testing of all build configuration combinations
- **Triggers**: Push to main branch or workflow changes
- **Matrix**: Tests 12 build configuration combinations
- **Features**:
  - All possible combinations of build options
  - Binary characteristic verification
  - Test suite execution when built
  - Performance and debug build validation

#### 3. Debug Build Test (`debug-build-test.yml`)
- **Purpose**: Dedicated testing for debug builds
- **Triggers**: Push to source files or workflow changes
- **Features**:
  - Debug symbol verification
  - GDB integration testing
  - Debug section validation
  - Binary size analysis

### Quality Assurance Workflows

#### 4. Clang-Tidy (`clang-tidy.yml`)
- **Purpose**: Static analysis and code quality checks
- **Features**:
  - Static code analysis
  - Code style validation
  - Potential bug detection
  - Performance suggestions

#### 5. Memory Sanitizer (`memory-sanitizer.yml`)
- **Purpose**: Memory error detection
- **Features**:
  - Memory leak detection
  - Use-after-free detection
  - Buffer overflow detection
  - Memory corruption detection

#### 6. CodeQL (`codeql.yml`)
- **Purpose**: Security analysis and vulnerability detection
- **Features**:
  - Security vulnerability scanning
  - Code injection detection
  - Malicious code detection
  - Security best practices validation

#### 7. ShellCheck (`shellcheck.yml`)
- **Purpose**: Shell script validation
- **Features**:
  - Shell script linting
  - Syntax validation
  - Best practices enforcement
  - Portability checks

### Performance and Compatibility Workflows

#### 8. Performance Benchmark (`performance-benchmark.yml`)
- **Purpose**: Performance testing and optimization verification
- **Triggers**: Push to main, PR, or daily schedule
- **Features**:
  - Performance benchmarking
  - Optimization verification
  - Binary size analysis
  - Memory usage profiling

#### 9. Cross-Platform Test (`cross-platform.yml`)
- **Purpose**: Multi-platform compatibility testing
- **Features**:
  - Ubuntu compatibility
  - Arch Linux compatibility
  - Fedora compatibility
  - Debian compatibility

### Maintenance Workflows

#### 10. Dependency Check (`dependency-check.yml`)
- **Purpose**: Security vulnerability scanning in dependencies
- **Triggers**: Weekly schedule or dependency changes
- **Features**:
  - System package vulnerability scanning
  - Binary dependency analysis
  - Security audit reporting

#### 11. Tag Cleanup (`tag-cleanup.yml`)
- **Purpose**: Automated tag management
- **Features**:
  - Tag cleanup and maintenance
  - Version tag organization
  - Release tag management

#### 12. Version Bump (`version-bump.yml`)
- **Purpose**: Automated semantic versioning
- **Features**:
  - Semantic version bumping
  - Conventional commit parsing
  - Automated release management

## Build Configurations

The CI/CD pipeline tests all possible build configuration combinations:

### Basic Configurations
- **Default**: Standard build with O2 optimizations
- **Performance**: O3 optimizations with LTO and native architecture tuning
- **Debug**: Debug symbols with O0 optimization
- **Warnings**: Extra compiler warnings

### Combined Configurations
- Performance + Warnings
- Debug + Warnings
- Tests (with test suite)
- Performance + Tests
- Debug + Tests
- Warnings + Tests
- Performance + Warnings + Tests
- Debug + Warnings + Tests

### Configuration Details

#### Performance Build
- **Compiler Flags**: `-O3 -march=native -mtune=native`
- **LTO**: Link Time Optimization enabled
- **Defines**: `NDEBUG`
- **Verification**: O3 flags and LTO presence checked

#### Debug Build
- **Compiler Flags**: `-g -O0`
- **Debug Symbols**: Present and verified
- **Defines**: `DEBUG`
- **GDB Integration**: Tested and verified

#### Warnings Build
- **Compiler Flags**: `-Wall -pedantic -Wextra`
- **Code Quality**: Enhanced warning detection
- **Best Practices**: Enforced through warnings

## Testing Procedures

### Automated Testing
1. **Build Verification**: All builds complete successfully
2. **Binary Validation**: Binary characteristics verified
3. **Functionality Testing**: Basic functionality tested
4. **Test Suite Execution**: Tests run when built
5. **Cross-Platform Testing**: Compatibility verified

### Manual Testing
```sh
# Test all build configurations locally
./build.sh performance warnings tests
./build.sh debug warnings tests

# Verify debug builds
./build.sh debug
gdb build/bin/vglog-filter

# Test performance builds
./build.sh performance
# Verify optimizations in binary
```

### Quality Checks
- **Static Analysis**: Clang-Tidy and CodeQL
- **Memory Safety**: Memory Sanitizer
- **Security**: Dependency vulnerability scanning
- **Code Style**: ShellCheck and linting
- **Performance**: Benchmarking and optimization verification

## Quality Assurance

### Code Quality
- **Static Analysis**: Automated code quality checks
- **Memory Safety**: Memory error detection
- **Security**: Vulnerability scanning
- **Style**: Consistent code formatting

### Performance
- **Optimization Verification**: Performance builds tested
- **Benchmarking**: Automated performance testing
- **Memory Usage**: Memory efficiency validation
- **Binary Size**: Size optimization verification

### Compatibility
- **Cross-Platform**: Multiple Linux distributions tested
- **Architecture**: Native architecture optimization
- **Dependencies**: System package compatibility
- **Portability**: Shell script portability

### Reliability
- **Test Coverage**: Comprehensive test suite
- **Error Handling**: Robust error handling tested
- **Edge Cases**: Boundary condition testing
- **Regression Testing**: Automated regression detection

## Development Workflow

### Local Development
1. **Setup**: Clone repository and install dependencies
2. **Build**: Use `./build.sh` with appropriate options
3. **Test**: Run tests with `./build.sh tests`
4. **Quality**: Run local quality checks
5. **Commit**: Use conventional commit messages

### CI/CD Integration
1. **Push**: Push changes to trigger workflows
2. **Automated Testing**: All workflows run automatically
3. **Review**: Check workflow results and logs
4. **Fix**: Address any issues found
5. **Merge**: Merge when all checks pass

### Release Process
1. **Version Bump**: Automated semantic versioning
2. **Tagging**: Automated tag creation
3. **Testing**: Comprehensive testing on all platforms
4. **Validation**: Quality and security checks
5. **Release**: Automated release creation

### Monitoring
- **Workflow Status**: Monitor all workflow results
- **Performance Metrics**: Track performance benchmarks
- **Security Alerts**: Monitor security scan results
- **Quality Metrics**: Track code quality trends

## Troubleshooting

### Common Issues
- **Build Failures**: Check compiler compatibility
- **Test Failures**: Verify test environment
- **Performance Issues**: Check optimization flags
- **Security Issues**: Review dependency updates

### Debugging
- **Workflow Logs**: Check detailed workflow logs
- **Local Reproduction**: Reproduce issues locally
- **Environment Differences**: Check platform differences
- **Dependency Issues**: Verify dependency versions

### Support
- **Documentation**: Check relevant documentation
- **Issues**: Report issues on GitHub
- **Discussions**: Use GitHub Discussions for questions
- **Contributing**: Follow contributing guidelines

---

For more information, see the [Build Guide](BUILD.md), [Developer Guide](DEVELOPER_GUIDE.md), and [FAQ](FAQ.md). 