# Advanced Usage and Customization

This guide delves into the advanced features and customization options of `vglog-filter`, allowing you to fine-tune its behavior for specific use cases and integrate it more deeply into your development workflow.

## Table of Contents

- [Custom Filtering Rules](#custom-filtering-rules)
- [Command-Line Options Reference](#command-line-options-reference)
- [Integration with CI/CD Pipelines](#integration-with-cicd-pipelines)
- [Performance Tuning](#performance-tuning)
- [Debugging and Troubleshooting](#debugging-and-troubleshooting)
- [Extending vglog-filter](#extending-vglog-filter)

## Custom Filtering Rules

`vglog-filter` provides a default set of rules to clean up common Valgrind noise. The tool automatically:

- **Removes duplicate stack traces** based on configurable depth (`--depth`)
- **Normalizes memory addresses** and process IDs for consistent comparison
- **Scrubs `at:` line numbers** to eliminate non-deterministic elements
- **Trims debug information** above the last marker string (default: "Successfully downloaded debug")

For developers looking to implement custom filtering logic, this can be done by modifying the log processing sections in the source code (e.g., `src/log_processor.cpp`) and recompiling the project.

Future versions may support external configuration files for custom rules without requiring recompilation.

[↑ Back to top](#advanced-usage-and-customization)

## Command-Line Options Reference

`vglog-filter` provides several command-line options for fine-tuning its behavior:

### Filtering and Deduplication Options

- **`-k, --keep-debug-info`**: Keep everything; do not trim above the last debug marker
- **`-v, --verbose`**: Show completely raw blocks (no address / "at:" scrub)
- **`-d N, --depth N`**: Signature depth for deduplication (default: 1, 0 = unlimited, max: 1000)
- **`-m S, --marker S`**: Custom marker string (default: "Successfully downloaded debug", max: 1024 chars)

### Processing Mode Options

- **`-s, --stream`**: Force stream processing mode (auto-detected for files >5MB)
- **`-p, --progress`**: Show progress for large files
- **`-M, --memory`**: Monitor memory usage during processing

### Information Options

- **`-V, --version`**: Show version information
- **`-h, --help`**: Show detailed help

### Input Handling

- **File input**: `vglog-filter [options] logfile.txt`
- **Stdin input**: `vglog-filter [options] < logfile.txt` or `vglog-filter [options] - < logfile.txt`
- **Direct pipe**: `valgrind ./program 2>&1 | vglog-filter [options]`

[↑ Back to top](#advanced-usage-and-customization)

## Integration with CI/CD Pipelines

`vglog-filter` is designed to be easily integrated into Continuous Integration/Continuous Deployment (CI/CD) pipelines to automate Valgrind log analysis.

### Example: GitHub Actions

In a GitHub Actions workflow, you can use `vglog-filter` to process Valgrind logs generated during your test runs. This ensures that only relevant errors are reported, making your CI logs cleaner and easier to review.

```yaml
name: Valgrind Analysis
on:
  pull_request:
    branches:
      - main
  push:
    branches:
      - main

jobs:
  valgrind-check:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y build-essential cmake valgrind

      - name: Build vglog-filter
        run: |
          ./build.sh performance clean
          echo "BINARY_PATH=build/bin/vglog-filter" >> $GITHUB_ENV

      - name: Build project
        run: |
          # Replace with your project's actual build commands
          mkdir -p build
          cd build
          cmake ..
          make -j$(nproc)

      - name: Run Valgrind and Filter Logs
        run: |
          # Run your application with Valgrind and pipe output to vglog-filter
          timeout 600 valgrind \
            --leak-check=full \
            --show-leak-kinds=all \
            --track-origins=yes \
            --error-exitcode=1 \
            --log-file=valgrind_raw.log \
            ./build/your_application || true
          
          # Filter the raw log with progress and memory monitoring
          $BINARY_PATH --progress --monitor-memory valgrind_raw.log > valgrind_filtered.log
          
          # Check if the filtered log contains any errors
          if [ -s valgrind_filtered.log ]; then
            echo "❌ Valgrind detected issues. See valgrind_filtered.log:"
            echo "=== Filtered Valgrind Output ==="
            cat valgrind_filtered.log
            echo "=== End Filtered Output ==="
            
            # Optional: Upload artifacts for review
            echo "Uploading Valgrind logs as artifacts..."
            exit 1
          else
            echo "✅ Valgrind analysis completed with no new issues detected."
          fi

      - name: Upload Valgrind logs (on failure)
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: valgrind-logs
          path: |
            valgrind_raw.log
            valgrind_filtered.log
          retention-days: 30
```

This enhanced example demonstrates:
1. **Proper timeout handling**: Prevents CI jobs from hanging indefinitely
2. **Comprehensive Valgrind options**: Uses recommended flags for thorough analysis
3. **Error handling**: Continues processing even if the application crashes
4. **Artifact upload**: Preserves logs for debugging when issues are found
5. **Progress and memory monitoring**: Uses `vglog-filter`'s monitoring features
6. **Clear status reporting**: Provides clear pass/fail indicators

### Example: GitLab CI

```yaml
valgrind_analysis:
  stage: test
  image: ubuntu:22.04
  before_script:
    - apt-get update && apt-get install -y build-essential cmake valgrind
    - ./build.sh performance clean
  script:
    - |
      # Run tests with Valgrind
      valgrind --leak-check=full --show-leak-kinds=all \
        --track-origins=yes --error-exitcode=1 \
        --log-file=valgrind.log ./build/bin/your_tests || true
      
      # Filter and analyze with custom depth and progress monitoring
      ./build/bin/vglog-filter --depth 2 --progress valgrind.log > filtered.log
      
      # Check for issues
      if [ -s filtered.log ]; then
        echo "Memory issues detected:"
        cat filtered.log
        exit 1
      fi
  artifacts:
    when: on_failure
    paths:
      - valgrind.log
      - filtered.log
    expire_in: 1 week
```

### Example: Jenkins Pipeline

```groovy
pipeline {
    agent any
    
    stages {
        stage('Build vglog-filter') {
            steps {
                sh '''
                    ./build.sh performance clean
                    echo "BINARY_PATH=build/bin/vglog-filter" > env.properties
                '''
            }
        }
        
        stage('Run Valgrind Analysis') {
            steps {
                script {
                    def binaryPath = readFile('env.properties').trim().split('=')[1]
                    
                    sh '''
                        # Run your application with Valgrind
                        timeout 600 valgrind --leak-check=full --show-leak-kinds=all \
                            --track-origins=yes --error-exitcode=1 \
                            --log-file=valgrind_raw.log ./build/your_application || true
                        
                        # Filter the log
                        ${BINARY_PATH} --progress --monitor-memory valgrind_raw.log > valgrind_filtered.log
                        
                        # Check for issues
                        if [ -s valgrind_filtered.log ]; then
                            echo "Valgrind issues found:"
                            cat valgrind_filtered.log
                            exit 1
                        fi
                    '''
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'valgrind_*.log', allowEmptyArchive: true
                }
            }
        }
    }
}
```

For more details on the project's CI/CD setup, refer to the [CI/CD Guide](CI_CD_GUIDE.md).

[↑ Back to top](#advanced-usage-and-customization)

## Performance Tuning

`vglog-filter` is optimized for performance, especially when handling large log files. Here are some considerations for maximizing its efficiency:

### Build Optimizations

- **Performance Build**: Use the performance build mode for production use:
  ```sh
  ./build.sh performance clean
  ```
  This enables `-O3` optimizations, Link Time Optimization (LTO), and other performance enhancements.

- **Parallel Compilation**: Leverage multiple CPU cores during compilation:
  ```sh
  ./build.sh performance -j$(nproc)
  ```

- **Debug Builds**: For development and testing, use debug builds:
  ```sh
  ./build.sh debug clean
  ```

### Runtime Optimizations

- **Stream Processing (`-s` / `--stream`)**: For very large files or continuous input streams, forcing stream processing mode can be beneficial. While `vglog-filter` automatically switches to this mode for inputs over 5MB, explicitly using `-s` ensures consistent behavior.

  ```sh
  ./build/bin/vglog-filter -s large_log.log > filtered.log
  ```

- **Input/Output Redirection**: Piping Valgrind output directly to `vglog-filter` is generally more efficient than writing to an intermediate file and then reading it. This reduces disk I/O.

  ```sh
  valgrind --leak-check=full ./your_program 2>&1 | ./build/bin/vglog-filter > filtered.log
  ```

- **Deduplication Depth Tuning**: Adjust the `--depth` parameter based on your specific use case:
  - Use `--depth 0` for maximum precision (entire error blocks)
  - Use `--depth 1-3` for balanced performance and accuracy (default: 1)
  - Use `--depth 5-10` for faster processing with some precision loss
  - Maximum depth is 1000

- **System Resources**: Ensure your system has sufficient CPU and memory. While `vglog-filter` is memory-efficient, very large logs still require some resources. The `--monitor-memory` option can help you assess memory usage.

### Memory Management

- **Large File Threshold**: The automatic stream processing threshold (5MB) can be adjusted by modifying `LARGE_FILE_THRESHOLD_MB` in the source code if needed.
- **Progress Monitoring**: Use `--progress` for large files to monitor processing status and estimate completion time.
- **Memory Monitoring**: Use `--monitor-memory` to track peak memory usage and identify potential bottlenecks.

### Advanced Performance Tips

- **Batch Processing**: For multiple log files, consider processing them in parallel if your system has sufficient resources:
  ```sh
  # Process multiple files in parallel
  parallel './build/bin/vglog-filter {} > {}.filtered' ::: *.log
  ```

- **Custom Markers**: Use specific marker strings to reduce processing time by focusing only on relevant sections:
  ```sh
  ./build/bin/vglog-filter --marker "Test completed" large_log.log
  ```

- **Verbose Mode**: Only use `--verbose` when debugging, as it disables address scrubbing and increases output size.

[↑ Back to top](#advanced-usage-and-customization)

## Debugging and Troubleshooting

If `vglog-filter` is not producing the expected output or if you encounter issues, consider the following systematic approach:

### Diagnostic Steps

1. **Verify Valgrind Output**: First, inspect the raw Valgrind output (before filtering) to ensure it contains the patterns you expect `vglog-filter` to process. You can save raw output to a file:

   ```sh
   valgrind --leak-check=full ./your_program 2> raw_valgrind.log
   ```

2. **Check Command-Line Options**: Double-check that you are using the correct command-line options. For example, ensure `-s` is used if you intend to force stream processing.

3. **Examine Filtered Output**: Compare the raw Valgrind log with the filtered output. This can help identify if specific patterns are being missed or incorrectly filtered.

4. **Memory Monitoring (`-M` / `--monitor-memory`)**: If you suspect memory-related issues or performance bottlenecks, use the memory monitoring option:

   ```sh
   ./build/bin/vglog-filter -M your_log.log
   ```
   This will report the peak memory usage, which can be helpful for diagnosing resource-related problems.

5. **Progress Monitoring (`-p` / `--progress`)**: For large files, use progress monitoring to ensure processing is proceeding as expected:

   ```sh
   ./build/bin/vglog-filter -p large_log.log
   ```

### Debug Builds

If you are modifying `vglog-filter`'s source code, build it in debug mode for more detailed error messages and easier debugging with tools like GDB:

```sh
./build.sh debug clean
```

Debug builds include:
- Symbol information for debugging
- Additional runtime checks
- Verbose error messages
- No optimizations that could interfere with debugging

### Common Issues and Solutions

- **No Output**: 
  - Check if the marker string is present in your log file
  - Use `--keep-debug-info` to process the entire file
  - Verify the input file is not empty or corrupted

- **Unexpected Deduplication**: 
  - Adjust the `--depth` parameter to control deduplication precision
  - Use `--depth 0` for maximum precision
  - Use `--verbose` to see raw output without scrubbing

- **Memory Issues**: 
  - Use `--stream` mode for large files
  - Monitor memory usage with `--monitor-memory`
  - Consider processing files in smaller chunks

- **Performance Problems**: 
  - Use performance builds (`./build.sh performance clean`)
  - Consider adjusting deduplication depth
  - Use stream processing for large files
  - Monitor progress with `--progress`

- **Marker String Issues**:
  - Ensure the marker string is exactly as it appears in the log
  - Check for case sensitivity
  - Verify no extra whitespace or special characters

### Error Messages and Their Meanings

- **"Invalid integer"**: The `--depth` parameter contains non-numeric characters
- **"Integer out of valid range"**: The `--depth` parameter is outside the valid range (0-1000)
- **"Marker string too long"**: The custom marker exceeds 1024 characters
- **"Marker string contains null bytes"**: The marker string contains invalid null characters
- **"Input file is empty"**: The specified input file contains no data

Refer to the [Build Guide](BUILD.md) for instructions on debug builds and the [FAQ](FAQ.md) for more troubleshooting information.

[↑ Back to top](#advanced-usage-and-customization)

## Extending vglog-filter

For developers interested in extending `vglog-filter`'s capabilities, consider the following areas:

### Adding New Filtering Logic

Implement new C++ code within `src/log_processor.cpp` to handle novel Valgrind output patterns or introduce more sophisticated filtering algorithms. The codebase is designed with extensibility in mind, using modern C++20 features.

Key areas for extension:
- **Pattern matching**: Add new regex patterns for different Valgrind output formats
- **Deduplication algorithms**: Implement alternative deduplication strategies
- **Output formatting**: Add support for different output formats (JSON, XML, etc.)
- **Filtering rules**: Create more sophisticated filtering logic

### External Configuration

Future enhancements could include support for external configuration files (e.g., JSON, YAML) to define filtering rules without recompiling the source code. This would make `vglog-filter` more flexible for end-users.

### New Output Formats

Currently, `vglog-filter` outputs plain text. You could extend it to support other output formats (e.g., XML, JSON) for easier machine parsing and integration with other analysis tools.

### Performance Improvements

Explore further optimizations, such as:
- Parallel processing for multi-core systems (if applicable to the log structure)
- More advanced string matching algorithms
- SIMD optimizations for pattern matching
- Improved memory management strategies
- Caching mechanisms for repeated patterns

### Development Workflow

When extending `vglog-filter`:

1. **Use Debug Builds**: Start with debug builds for development and testing
2. **Run Tests**: Ensure all tests pass after making changes
3. **Performance Testing**: Test with large files to ensure performance is maintained
4. **Memory Sanitizer**: Use MemorySanitizer builds to catch memory issues early
5. **Code Style**: Follow the existing code style and conventions
6. **Documentation**: Update relevant documentation files

### Building and Testing

```sh
# Development workflow
./build.sh debug clean          # Build in debug mode
./build.sh debug tests          # Run tests
./build.sh performance clean    # Build optimized version
./build.sh performance tests    # Test optimized version
```

### Contributing Guidelines

When contributing to `vglog-filter`:

1. **Follow the existing code style** and naming conventions
2. **Add tests** for new functionality
3. **Update documentation** for any new features or changes
4. **Use meaningful commit messages** that describe the changes
5. **Test thoroughly** with various input sizes and types
6. **Consider performance implications** of your changes

Refer to the [Developer Guide](DEVELOPER_GUIDE.md) for general guidelines on contributing to the project and the [Test Suite Guide](TEST_SUITE.md) for information on testing your changes.

[↑ Back to top](#advanced-usage-and-customization)
