# Advanced Usage and Customization

This guide delves into the advanced features and customization options of `vglog-filter`, allowing you to fine-tune its behavior for specific use cases and integrate it more deeply into your development workflow.

## Table of Contents

- [Custom Filtering Rules](#custom-filtering-rules)
- [Integration with CI/CD Pipelines](#integration-with-cicd-pipelines)
- [Performance Tuning](#performance-tuning)
- [Debugging and Troubleshooting](#debugging-and-troubleshooting)
- [Extending vglog-filter](#extending-vglog-filter)

## Custom Filtering Rules

`vglog-filter` provides a default set of rules to clean up common Valgrind noise. Future versions may support external configuration files for custom rules.

For developers looking to implement custom filtering logic now, this can be done by modifying the log processing sections in the source code (e.g., `src/log_processor.cpp`) and recompiling the project.

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

jobs:
  valgrind-check:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Install dependencies
        run: | # Replace with your project's actual dependencies
          sudo apt-get update
          sudo apt-get install build-essential cmake valgrind

      - name: Build project
        run: ./build.sh

      - name: Run Valgrind and Filter Logs
        run: |
          # Run your application with Valgrind and pipe output to vglog-filter
          valgrind --leak-check=full --show-leak-kinds=all ./build/bin/your_application 2>&1 \
            | ./build/bin/vglog-filter --progress --monitor-memory > valgrind_filtered.log

          # Check if the filtered log contains any errors (e.g., by checking file size or specific keywords)
          if [ -s valgrind_filtered.log ]; then
            echo "Valgrind detected issues. See valgrind_filtered.log:"
            cat valgrind_filtered.log
            exit 1 # Fail the CI job if issues are found
          else
            echo "Valgrind analysis completed with no new issues detected."
          fi
```

This example demonstrates how to:
1.  Set up the build environment.
2.  Build `vglog-filter` and your application.
3.  Run your application under Valgrind, piping its output directly to `vglog-filter`.
4.  Save the filtered output to a file.
5.  Implement a basic check to fail the CI job if the filtered log is not empty, indicating potential issues.

For more details on the project's CI/CD setup, refer to the [CI/CD Guide](doc/CI_CD_GUIDE.md).

[↑ Back to top](#advanced-usage-and-customization)

## Performance Tuning

`vglog-filter` is optimized for performance, especially when handling large log files. Here are some considerations for maximizing its efficiency:

-   **Stream Processing (`-s` / `--stream`)**: For very large files or continuous input streams, forcing stream processing mode can be beneficial. While `vglog-filter` automatically switches to this mode for inputs over 5MB, explicitly using `-s` ensures consistent behavior.

    ```sh
    ./build/bin/vglog-filter -s large_log.log > filtered.log
    ```

-   **Input/Output Redirection**: Piping Valgrind output directly to `vglog-filter` (as shown in [Usage](#usage)) is generally more efficient than writing to an intermediate file and then reading it. This reduces disk I/O.

    ```sh
    valgrind ... | ./build/bin/vglog-filter > filtered.log
    ```

-   **System Resources**: Ensure your system has sufficient CPU and memory. While `vglog-filter` is memory-efficient, very large logs still require some resources. The `--monitor-memory` option can help you assess memory usage.

[↑ Back to top](#advanced-usage-and-customization)

## Debugging and Troubleshooting

If `vglog-filter` is not producing the expected output or if you encounter issues, consider the following:

-   **Verify Valgrind Output**: First, inspect the raw Valgrind output (before filtering) to ensure it contains the patterns you expect `vglog-filter` to process. You can save raw output to a file:

    ```sh
    valgrind --leak-check=full ./your_program 2> raw_valgrind.log
    ```

-   **Check Command-Line Options**: Double-check that you are using the correct command-line options. For example, ensure `-s` is used if you intend to force stream processing.

-   **Examine Filtered Output**: Compare the raw Valgrind log with the filtered output. This can help identify if specific patterns are being missed or incorrectly filtered.

-   **Memory Monitoring (`-M` / `--monitor-memory`)**: If you suspect memory-related issues or performance bottlenecks, use the memory monitoring option:

    ```sh
    ./build/bin/vglog-filter -M your_log.log
    ```
    This will report the peak memory usage, which can be helpful for diagnosing resource-related problems.

-   **Build in Debug Mode**: If you are modifying `vglog-filter`'s source code, build it in debug mode for more detailed error messages and easier debugging with tools like GDB. Refer to the [Build Guide](doc/BUILD.md) for instructions on debug builds.

[↑ Back to top](#advanced-usage-and-customization)

## Extending vglog-filter

For developers interested in extending `vglog-filter`'s capabilities, consider the following areas:

-   **Adding New Filtering Logic**: Implement new C++ code within `src/log_processor.cpp` to handle novel Valgrind output patterns or introduce more sophisticated filtering algorithms.

-   **External Configuration**: Future enhancements could include support for external configuration files (e.g., JSON, YAML) to define filtering rules without recompiling the source code. This would make `vglog-filter` more flexible for end-users.

-   **New Output Formats**: Currently, `vglog-filter` outputs plain text. You could extend it to support other output formats (e.g., XML, JSON) for easier machine parsing and integration with other analysis tools.

-   **Performance Improvements**: Explore further optimizations, such as parallel processing for multi-core systems (if applicable to the log structure) or more advanced string matching algorithms.

Refer to the [Developer Guide](doc/DEVELOPER_GUIDE.md) for general guidelines on contributing to the project.

[↑ Back to top](#advanced-usage-and-customization)
