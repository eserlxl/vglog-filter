# Usage Guide: vglog-filter

This guide provides comprehensive instructions on how to use `vglog-filter` to process Valgrind log files. Valgrind is an instrumentation framework for building dynamic analysis tools. It is commonly used for memory debugging, detecting memory leaks, and profiling. `vglog-filter` enhances Valgrind's utility by cleaning and normalizing its often verbose and inconsistent output.

It covers installation, basic usage, command-line options, and practical examples to help you effectively clean and analyze your Valgrind output.

## Table of Contents

- [Key Features](#key-features)
- [Installation](#installation)
  - [Prerequisites](#prerequisites)
  - [Building from Source](#building-from-source)
- [Basic Usage](#basic-usage)
- [Input and Output](#input-and-output)
- [Command-Line Options](#command-line-options)
  - [Filtering and Deduplication Options](#filtering-and-deduplication-options)
  - [Processing Mode Options](#processing-mode-options)
  - [Monitoring and Information Options](#monitoring-and-information-options)
- [Practical Examples](#practical-examples)
  - [Filtering a Log File](#filtering-a-log-file)
  - [Piping Valgrind Output Directly](#piping-valgrind-output-directly)
  - [Forcing Stream Processing](#forcing-stream-processing)
  - [Monitoring Progress and Memory](#monitoring-progress-and-memory)
  - [Keeping All Log Entries](#keeping-all-log-entries)
  - [Using a Custom Marker](#using-a-custom-marker)
  - [Adjusting Deduplication Depth](#adjusting-deduplication-depth)
  - [Viewing Raw (Unscrubbed) Output](#viewing-raw-unscrubbed-output)
  - [Combining Multiple Options](#combining-multiple-options)
  - [Processing Multiple Files](#processing-multiple-files)
- [Exit Codes](#exit-codes)
- [Troubleshooting Common Usage Issues](#troubleshooting-common-usage-issues)

## Key Features

`vglog-filter` is a powerful command-line utility designed to streamline the analysis of Valgrind memory error logs. By processing raw Valgrind output, it transforms verbose and often inconsistent logs into a clean, concise, and actionable format. Its key features include:

-   **Automated Deduplication**: Intelligently identifies and removes duplicate stack traces and error reports. This significantly reduces log file size, eliminates redundant information, and improves readability, allowing developers to focus on unique issues.
-   **Dynamic Data Normalization**: Scrubs non-deterministic elements such as memory addresses, process IDs, and `at:` line numbers. This crucial step makes log comparisons consistent and reliable across different Valgrind runs, facilitating automated analysis and regression testing.
-   **Flexible Input/Output**: Supports processing logs from specified files or directly from standard input (stdin). This flexibility allows for seamless integration into CI/CD pipelines, automated scripting workflows, and real-time analysis of Valgrind output.
-   **Customizable Filtering**: Allows users to define a custom marker string to delineate the relevant section of a log file for processing. This is particularly useful for large logs that contain setup or teardown information, ensuring only the critical error reports are analyzed. Alternatively, the entire log can be processed.
-   **Performance Monitoring**: Provides options to monitor real-time processing progress and report peak memory usage. These metrics are invaluable for handling very large Valgrind outputs, helping users understand resource consumption and optimize their analysis workflows.
-   **Memory-Efficient Stream Processing**: Automatically switches to a memory-efficient stream processing mode for large input files (typically over 5MB) or can be explicitly forced for continuous streams. This ensures `vglog-filter` can handle extremely large logs without exhausting system memory.

## Installation

To use `vglog-filter`, you need to build it from its source code. For detailed instructions, refer to the [Build Guide](BUILD.md).

### Prerequisites

Before building `vglog-filter`, ensure you have the following tools installed on your system:

- **C++ Compiler**: GCC 10+ or Clang 12+ with C++20 support
- **CMake**: Version 3.16 or higher
- **Make**: GNU Make or Ninja build system
- **Git**: For cloning the repository (optional, for development)

On most Linux distributions, you can install these prerequisites with:

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install build-essential cmake git

# CentOS/RHEL/Fedora
sudo dnf install gcc-c++ cmake make git

# Arch Linux
sudo pacman -S base-devel cmake git
```

### Building from Source

The project includes a convenient `build.sh` script that handles the CMake configuration and compilation process.

```bash
./build.sh --help
```

```
vglog-filter build script

Usage:
  build.sh [performance] [warnings] [debug] [clean] [tests] [-j N] [--build-dir DIR]
  build.sh --help

Options/Modes:
  performance        Enable performance optimizations (mutually exclusive with debug)
  warnings           Enable extra compiler warnings
  debug              Enable debug mode (mutually exclusive with performance)
  clean              Remove the build directory and reconfigure
  tests              Build and run tests (ctest if available)
  -j, --jobs N       Parallel build jobs (default: 8)
  --build-dir DIR    Build directory (default: build)
  -h, --help         Show this help

Environment overrides:
  BUILD_DIR=/path/to/build   Set build directory
  JOBS=N                     Set parallel build jobs
```

**Quick Start:**
```bash
# Clone the repository (if not already done)
git clone https://github.com/your-username/vglog-filter.git
cd vglog-filter

# Build with performance optimizations
./build.sh performance

# The executable will be available at build/bin/vglog-filter
```

[↑ Back to top](#usage-guide)

## Basic Usage

`vglog-filter` is a command-line tool that takes Valgrind log data as input and outputs a cleaned, deduplicated version. It can read from a specified file or directly from standard input (stdin).

The general syntax is:

```bash
vglog-filter [OPTIONS] [INPUT_FILE]
```

-   `[OPTIONS]`: Optional flags to control `vglog-filter`'s behavior (e.g., `-p` for progress, `-M` for memory monitoring).
-   `[INPUT_FILE]`: The path to the Valgrind log file you want to process. If omitted, `vglog-filter` will read from standard input.

By default, `vglog-filter` processes log entries after the last occurrence of the marker `Successfully downloaded debug`. It then deduplicates identical stack traces and normalizes dynamic data (like memory addresses) to make logs comparable.

[↑ Back to top](#usage-guide)

## Input and Output

`vglog-filter` is designed to be flexible with its input and output streams.

### Input Sources

1.  **From a File**: Provide the path to your Valgrind log file as an argument:
    ```bash
    vglog-filter my_valgrind_log.txt > filtered_output.txt
    ```
2.  **From Standard Input (Stdin)**: If no `INPUT_FILE` is specified, `vglog-filter` will read from stdin. This is ideal for piping output directly from `valgrind` or other tools.
    ```bash
    valgrind --leak-check=full ./my_program 2>&1 | vglog-filter > filtered_output.txt
    ```
    *Note: `2>&1` redirects Valgrind's stderr (where it typically writes logs) to stdout, so it can be piped.*

### Output Destination

`vglog-filter` writes its processed output to standard output (stdout). You can redirect this output to a file, pipe it to another command, or display it directly on the console.

```bash
# Redirect to a file
vglog-filter input.log > output.log

# Display directly on console
vglog-filter input.log

# Pipe to another command (e.g., less for pagination)
vglog-filter input.log | less
```

[↑ Back to top](#usage-guide)

## Command-Line Options

`vglog-filter` provides several command-line options to customize its behavior. These options can be combined to achieve specific filtering and processing outcomes.

### Filtering and Deduplication Options

-   `-k, --keep-debug-info`
    -   **Purpose**: Processes the entire log file from start to finish, ignoring the default or custom marker. By default, `vglog-filter` only processes content after the last occurrence of the marker `Successfully downloaded debug`.
    -   **Use Case**: When you want to analyze the complete log, including setup and initialization information.
    -   **Example**: `vglog-filter -k full_log.log`

-   `-d N, --depth N`
    -   **Purpose**: Controls the number of lines (`N`) used to generate the unique signature for deduplication. A higher depth considers more context, leading to more precise (but potentially fewer) deduplications. This parameter helps fine-tune the balance between aggressive deduplication and preserving distinct error patterns.
    -   **`N=0`**: Uses unlimited depth, meaning the entire error block is considered for the signature, providing the most precise deduplication.
    -   **Default**: If not specified, a default depth of 1 is used, which typically offers a good balance for common Valgrind outputs.
    -   **Range**: Valid values are 0 to 1000. Values outside this range will result in an error.
    -   **Performance Impact**: Higher depth values may increase processing time but provide more accurate deduplication.
    -   **Example**: `vglog-filter -d 5 raw.log` (uses first 5 lines for signature)

-   `-m S, --marker S`
    -   **Purpose**: Specifies a custom marker string (`S`) to delineate the relevant section of the log. Only log entries *after* the last occurrence of this custom marker will be processed (unless `-k` is used). This is useful for logs that contain preamble or postamble information you wish to ignore.
    -   **Default**: `Successfully downloaded debug`
    -   **Limit**: Maximum length of 1024 characters. Longer markers will result in an error.
    -   **Use Case**: When your application uses a different marker or when you want to focus on a specific section of the log.
    -   **Example**: `vglog-filter -m "--- TEST START ---" my_log.log`

-   `-v, --verbose`
    -   **Purpose**: Disables the scrubbing (normalization) of non-deterministic elements like memory addresses, process IDs, and `at:` line numbers. The output will be the raw Valgrind log, but still filtered and deduplicated based on other options. Use this if you need to inspect the exact memory addresses or other dynamic data.
    -   **Use Case**: Debugging specific memory issues where exact addresses are needed, or when comparing logs from the same run.
    -   **Example**: `vglog-filter -v raw.log`

### Processing Mode Options

-   `-s, --stream`
    -   **Purpose**: Forces `vglog-filter` to use memory-efficient stream processing mode, regardless of the input file size. By default, the tool automatically switches to stream mode for files larger than 5MB. This option is crucial for processing continuous streams or extremely large files where loading the entire content into memory is not feasible.
    -   **Use Case**: Processing very large files, continuous data streams, or when memory is limited.
    -   **Performance**: May be slightly slower than in-memory processing but uses significantly less memory.
    -   **Example**: `vglog-filter -s small_file.log`

### Monitoring and Information Options

-   `-p, --progress`
    -   **Purpose**: Displays a real-time progress bar during processing. This is particularly useful for large log files to track the tool's progress and estimate completion time.
    -   **Use Case**: Processing large files where you want to monitor progress and estimate remaining time.
    -   **Output**: Shows percentage complete, processed size, and total size.
    -   **Example**: `vglog-filter -p large_log.log`

-   `-M, --monitor-memory`
    -   **Purpose**: Monitors and reports peak memory usage at different stages of the processing. This helps in understanding the tool's resource consumption and identifying potential memory bottlenecks, especially with very large inputs.
    -   **Use Case**: Performance analysis, debugging memory issues, or optimizing processing workflows.
    -   **Output**: Reports peak memory usage in MB at the end of processing.
    -   **Example**: `vglog-filter -M my_log.log`

-   `-V, --version`
    -   **Purpose**: Displays the current version of `vglog-filter`.
    -   **Use Case**: Verifying the installed version or checking for updates.
    -   **Example**: `vglog-filter --version`

-   `-h, --help`
    -   **Purpose**: Displays a brief help message with available command-line options and their usage.
    -   **Use Case**: Quick reference for available options and syntax.
    -   **Example**: `vglog-filter --help`

[↑ Back to top](#usage-guide)

## Practical Examples

Here are several practical examples demonstrating how to use `vglog-filter` in various scenarios.

### Filtering a Log File

To process a Valgrind log file and save the cleaned output to another file:

```bash
# 1. Generate a raw Valgrind log (redirect stderr to a file)
valgrind --leak-check=full ./your_program 2> raw_valgrind.log

# 2. Filter the log and save the cleaned output
vglog-filter raw_valgrind.log > filtered_valgrind.log
```

### Piping Valgrind Output Directly

This is the recommended and most efficient way to use `vglog-filter`, as it avoids intermediate file I/O:

```bash
valgrind --leak-check=full --show-leak-kinds=all ./your_program 2>&1 | vglog-filter
```

To save the piped and filtered output to a file:

```bash
valgrind --leak-check=full --show-leak-kinds=all ./your_program 2>&1 | vglog-filter > filtered_output.log
```

### Forcing Stream Processing

Forcing stream processing can be useful for very large files or when processing continuous streams, even if they are initially small:

```bash
vglog-filter --stream my_large_log.log > output.log
```

### Monitoring Progress and Memory

When dealing with extremely large log files, monitoring progress and memory usage provides valuable feedback:

```bash
vglog-filter --progress --monitor-memory very_large_valgrind.log > filtered.log
```

This command will display a progress bar and report peak memory usage at the end of processing.

### Keeping All Log Entries

If you want `vglog-filter` to process the entire log file without skipping content before the marker:

```bash
vglog-filter --keep-debug-info my_full_log.log > processed_full_log.log
```

### Using a Custom Marker

If your Valgrind logs include a custom string to mark the start of relevant output:

```bash
vglog-filter --marker "=== START OF VALGRIND REPORT ===" my_custom_log.log > cleaned_log.log
```

### Adjusting Deduplication Depth

To control how many lines are considered for deduplication signatures:

```bash
# Use only the first 3 lines of each error block for deduplication
vglog-filter --depth 3 raw.log > deduplicated_by_3_lines.log

# Use the entire error block for deduplication (most precise)
vglog-filter --depth 0 raw.log > fully_deduplicated.log
```

### Viewing Raw (Unscrubbed) Output

If you need to see the Valgrind output with memory addresses and other dynamic data intact (but still filtered and deduplicated):

```bash
vglog-filter --verbose raw.log > unscrubbed_filtered.log
```

### Combining Multiple Options

You can combine multiple options for sophisticated processing:

```bash
# Process entire file with custom marker, high deduplication depth, and monitoring
vglog-filter -k -m "TEST_START" -d 5 -p -M complex_log.log > processed.log

# Stream processing with progress monitoring for very large files
vglog-filter -s -p -M huge_log.log > filtered.log
```

### Processing Multiple Files

To process multiple Valgrind log files:

```bash
# Process each file individually
for logfile in logs/*.log; do
    vglog-filter "$logfile" > "filtered_$(basename "$logfile")"
done

# Or concatenate and process together
cat logs/*.log | vglog-filter > combined_filtered.log
```

[↑ Back to top](#usage-guide)

## Exit Codes

`vglog-filter` uses standard exit codes to indicate the outcome of its execution:

-   **`0` (Success)**: The program executed successfully. This includes cases where the input file was empty (a warning is issued, but it's not considered an error).
-   **Non-zero (Error)**: The program encountered an error. This could be due to:
    -   Invalid command-line arguments.
    -   Inability to open or read the input file.
    -   Other internal processing errors.

Always check the exit code in scripts to ensure `vglog-filter` completed as expected.

[↑ Back to top](#usage-guide)

## Troubleshooting Common Usage Issues

If you encounter problems while using `vglog-filter`, consider the following:

1.  **No Output or Unexpected Output**:
    -   **Check Input**: Ensure the `INPUT_FILE` path is correct and the file exists and is readable. If piping, verify that the upstream command (e.g., `valgrind`) is correctly redirecting its output to stdout.
    -   **Marker Issue**: If you're not seeing expected output, it might be because the default marker (`Successfully downloaded debug`) is not present, or your custom marker (`-m`) is incorrect. Try using `--keep-debug-info` (`-k`) to process the entire file.
    -   **Empty Input**: If the input file is empty, `vglog-filter` will issue a warning and exit successfully. Check if your input source is indeed providing data.

2.  **"File not found" or "Permission denied" Errors**:
    -   **Path**: Double-check the absolute or relative path to your input file.
    -   **Permissions**: Ensure you have read permissions for the input file and write permissions for the output directory if you're redirecting output to a new file.

3.  **Invalid Option Errors**:
    -   **Syntax**: Verify that you are using the correct option syntax (e.g., `-d N` requires a number, `-m S` requires a string).
    -   **Typos**: Check for typos in option names (e.g., `--progess` instead of `--progress`).

4.  **Performance Issues / High Memory Usage**:
    -   **Large Files**: For very large files, ensure `vglog-filter` is operating in stream processing mode. It should switch automatically, but you can force it with `-s`.
    -   **Monitor**: Use `--monitor-memory` (`-M`) to get insights into memory consumption and `--progress` (`-p`) to see if processing is stuck.

5.  **Output Still Contains Dynamic Data**:
    -   If you expect memory addresses or other dynamic elements to be scrubbed but they are still present, ensure you are *not* using the `--verbose` (`-v`) option, as this disables scrubbing.

6.  **Build Issues**:
    -   If you encounter problems during the build process, refer to the `build.sh` script's help message (`./build.sh --help`) and ensure all [Prerequisites](#prerequisites) are met.

7.  **Deduplication Issues**:
    -   **Too Much Deduplication**: If you're losing important information due to aggressive deduplication, try increasing the `--depth` parameter.
    -   **Not Enough Deduplication**: If you're seeing too many duplicates, try decreasing the `--depth` parameter or use `--depth 0` for maximum precision.

If you're still facing issues, refer to the [FAQ](FAQ.md) or [Developer Guide](DEVELOPER_GUIDE.md) for more in-depth troubleshooting and development information.

[↑ Back to top](#usage-guide)

## Contributing

We welcome contributions to `vglog-filter`! If you're interested in improving this tool, please refer to our [Contributing Guide](../../.github/CONTRIBUTING.md) for detailed instructions on how to set up your development environment, propose changes, and submit pull requests.

Your contributions help make `vglog-filter` better for everyone.

[↑ Back to top](#usage-guide)