# vglog-filter Usage Guide

`vglog-filter` is a command-line tool for deduplicating and filtering Valgrind log files, making it easier to identify unique memory errors and issues.

## Basic Usage

```sh
vglog-filter [options] <valgrind_log>
```

- `<valgrind_log>`: Path to the Valgrind log file to process.

## Options

| Option | Long Option         | Description |
|--------|---------------------|-------------|
| `-k`   | `--keep-debug-info` | Keep everything; do not trim above last debug marker. |
| `-v`   | `--verbose`         | Show completely raw blocks (no address / `at:` scrub). |
| `-d N` | `--depth N`         | Signature depth (default: 1, 0 = unlimited). |
| `-m S` | `--marker S`        | Marker string (default: "Successfully downloaded debug"). |
| `-V`   | `--version`         | Show version information. |
| `-h`   | `--help`            | Show help message. |

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

## Example

```sh
vglog-filter -d 2 -k valgrind.log > filtered.log
```
- This keeps all debug info and uses a signature depth of 2.

## How It Works
- By default, only log entries after the last occurrence of the marker string (default: "Successfully downloaded debug") are processed. Use `-k` to keep all entries.
- The tool deduplicates error blocks based on a canonicalized signature, with configurable depth.
- Address and line numbers are scrubbed unless `-v` is used.

---
For more details, see the [FAQ](FAQ.md) and [Advanced Filtering](ADVANCED.md). 