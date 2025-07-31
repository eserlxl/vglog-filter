# Usage Guide: vglog-filter

This guide provides comprehensive instructions on how to use `vglog-filter` to process Valgrind log files. It covers installation, basic usage, command-line options, and practical examples to help you effectively clean and analyze your Valgrind output.

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
- [Exit Codes](#exit-codes)
- [Troubleshooting Common Usage Issues](#troubleshooting-common-usage-issues)

## Key Features

`vglog-filter` is a powerful command-line utility designed to streamline the analysis of Valgrind memory error logs. Its key features include:

-   **Automated Deduplication**: Intelligently identifies and removes duplicate stack traces, significantly reducing log file size and improving readability.
-   **Dynamic Data Normalization**: Scrubs non-deterministic elements like memory addresses and `at:` line numbers, making log comparisons consistent across different runs.
-   **Flexible Input/Output**: Supports processing logs from files or directly from standard input, allowing seamless integration into CI/CD pipelines or scripting workflows.
-   **Customizable Filtering**: Allows users to define a custom marker to specify the relevant section of a log file for processing, or to process the entire log.
-   **Performance Monitoring**: Provides options to monitor real-time progress and peak memory usage, crucial for handling very large Valgrind outputs.
-   **Stream Processing**: Automatically switches to a memory-efficient stream processing mode for large files (over 5MB) or can be forced for continuous streams.

## Installation

To use `vglog-filter`, you need to build it from its source code.

### Prerequisites

Before building, ensure you have the following installed on your system:

-   **CMake**: Version 3.16 or higher.
-   **C++ Compiler**: A C++20 compliant compiler (e.g., GCC, Clang, MSVC).

### Building from Source

Follow these steps to build `vglog-filter`:

1.  **Clone the Repository**:
    If you haven't already, clone the `vglog-filter` repository to your local machine:
    ```bash
    git clone https://github.com/your-username/vglog-filter.git
    cd vglog-filter
    ```
    *(Note: Replace `https://github.com/your-username/vglog-filter.git` with the actual repository URL if different.)*

2.  **Build the Project**:
    The project includes a convenient `build.sh` script that handles the CMake configuration and compilation process.

    To perform a standard build (optimized for performance by default):
    ```bash
    ./build.sh
    ```

    You can also specify different build modes:
    -   **Debug Build**: For development and debugging, enabling debug symbols and disabling optimizations.
        ```bash
        ./build.sh debug
        ```
    -   **Build with Warnings**: To enable additional compiler warnings.
        ```bash
        ./build.sh warnings
        ```
    -   **Clean Build**: To remove the existing build directory before recompiling.
        ```bash
        ./build.sh clean
        ```
    -   **Build and Run Tests**: To compile the project and then execute its test suite.
        ```bash
        ./build.sh tests
        ```

    For more options, including parallel jobs (`-j N`) and custom build directories (`--build-dir DIR`), run:
    ```bash
    ./build.sh --help
    ```

3.  **Executable Location**:
    After a successful build, the `vglog-filter` executable will be located in the `build/bin/` directory (or `build/bin/<Config>` for multi-config generators like Visual Studio). You can then run it directly from there or add it to your system's PATH for easier access.

    Example:
    ```bash
    ./build/bin/vglog-filter --version
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

`vglog-filter` provides several command-line options to customize its behavior.

### Filtering and Deduplication Options

-   `-k, --keep-debug-info`
    -   **Purpose**: Processes the entire log file from start to finish, ignoring the default or custom marker. By default, `vglog-filter` only processes content after the last occurrence of the marker `Successfully downloaded debug`.
    -   **Example**: `vglog-filter -k full_log.log`

-   `-d N, --depth N`
    -   **Purpose**: Controls the number of lines (`N`) used to generate the unique signature for deduplication. A higher depth considers more context, leading to more precise (but potentially fewer) deduplications.
    -   **`N=0`**: Uses unlimited depth, meaning the entire error block is considered for the signature.
    -   **Default**: A sensible default is used if not specified.
    -   **Example**: `vglog-filter -d 5 raw.log` (uses first 5 lines for signature)

-   `-m S, --marker S`
    -   **Purpose**: Specifies a custom marker string (`S`) to delineate the relevant section of the log. Only log entries after the last occurrence of this custom marker will be processed (unless `-k` is used).
    -   **Default**: `Successfully downloaded debug`
    -   **Example**: `vglog-filter -m "--- TEST START ---" my_log.log`

-   `-v, --verbose`
    -   **Purpose**: Disables the scrubbing (normalization) of non-deterministic elements like memory addresses and `at:` line numbers. The output will be the raw Valgrind log, but still filtered and deduplicated based on other options.
    -   **Example**: `vglog-filter -v raw.log`

### Processing Mode Options

-   `-s, --stream`
    -   **Purpose**: Forces `vglog-filter` to use memory-efficient stream processing mode, regardless of the input file size. By default, the tool automatically switches to stream mode for files larger than 5MB.
    -   **Example**: `vglog-filter -s small_file.log`

### Monitoring and Information Options

-   `-p, --progress`
    -   **Purpose**: Displays a real-time progress bar during processing. This is particularly useful for large log files to track the tool's progress.
    -   **Example**: `vglog-filter -p large_log.log`

-   `-M, --monitor-memory`
    -   **Purpose**: Monitors and reports peak memory usage at different stages of the processing. This helps in understanding the tool's resource consumption.
    -   **Example**: `vglog-filter -M my_log.log`

-   `-V, --version`
    -   **Purpose**: Displays the current version of `vglog-filter`.
    -   **Example**: `vglog-filter --version`

-   `-h, --help`
    -   **Purpose**: Displays a brief help message with available command-line options.
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

If you're still facing issues, refer to the [FAQ](FAQ.md) or [Developer Guide](DEVELOPER_GUIDE.md) for more in-depth troubleshooting and development information.

[↑ Back to top](#usage-guide)
