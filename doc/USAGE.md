# vglog-filter Usage Guide

`vglog-filter` is a command-line tool for deduplicating and filtering Valgrind log files, making it easier to identify unique memory errors and issues.

## Basic Usage

```sh
vglog-filter [options] [valgrind_log]
```

- `[valgrind_log]`: Path to the Valgrind log file to process (optional, defaults to stdin if omitted)
- `-`: Explicitly read from stdin

## Options

| Option | Long Option         | Description |
|--------|---------------------|-------------|
| `-k`   | `--keep-debug-info` | Keep everything; do not trim above last debug marker. |
| `-v`   | `--verbose`         | Show completely raw blocks (no address / `at:` scrub). |
| `-d N` | `--depth N`         | Signature depth (default: 1, 0 = unlimited). |
| `-m S` | `--marker S`        | Marker string (default: "Successfully downloaded debug"). |
| `-s`   | `--stream`          | Force stream processing mode (auto-detected for files >5MB). |
| `-V`   | `--version`         | Show version information. |
| `-h`   | `--help`            | Show this help message. |

## Typical Workflow

1. Run your program with Valgrind, saving the output to a file:
   ```sh
   valgrind --leak-check=full ./your_program > valgrind.log 2>&1
   ```
2. Filter and deduplicate the log:
   ```sh
   vglog-filter valgrind.log > filtered.log
   ```
3. Review `filtered.log` for unique issues.

## Examples

```sh
# Basic usage with automatic large file detection
vglog-filter valgrind.log > filtered.log

# Keep all debug info and use signature depth of 2
vglog-filter -d 2 -k valgrind.log > filtered.log

# Force stream processing mode regardless of file size
vglog-filter -s large_valgrind.log > filtered.log

# Process from stdin (new feature)
cat valgrind.log | vglog-filter > filtered.log

# Direct pipe from valgrind (new feature)
valgrind --leak-check=full ./your_program 2>&1 | vglog-filter > filtered.log

# Explicit stdin usage
vglog-filter - < valgrind.log > filtered.log
```

## How It Works
- By default, only log entries after the last occurrence of the marker string (default: "Successfully downloaded debug") are processed. Use `-k` to keep all entries.
- The tool deduplicates error blocks based on a canonicalized signature, with configurable depth.
- Address and line numbers are scrubbed unless `-v` is used.
- **Automatic large file detection**: Files larger than 5MB automatically use stream processing for memory efficiency.
- Empty input files are handled gracefully with appropriate warnings.
- Comprehensive error messages provide helpful guidance for common issues.

## Error Handling
- **Invalid depth values**: Clear error messages with expected format
- **Missing input files**: Helpful suggestions for file access issues
- **Empty files**: Warning messages for empty input files
- **File access errors**: Descriptive error messages with troubleshooting hints

---
For more details, see the [FAQ](FAQ.md) and [Advanced Filtering](ADVANCED.md). 