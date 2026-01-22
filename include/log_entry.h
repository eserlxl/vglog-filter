#pragma once

#include <cstdint>
#include <string>
#include <vector>

/**
 * @brief Represents a single parsed Valgrind error entry.
 *
 * This structure holds both the raw content for faithful reproduction
 * and structured metadata for advanced filtering and analysis.
 */
struct LogEntry {
  /// Full original text block (including header and stack traces)
  std::string raw_content;

  /// Deduplication signature (usually based on stack semantics)
  std::string signature;

  /// The type of error (e.g., "Invalid read of size 4")
  std::string error_type;

  /// Process ID extracted from the Valgrind marker "==PID=="
  std::string pid;

  /// Individual stack frames extracted from the block
  std::vector<std::string> stack_trace;

  /// Source line number where this block started in the input stream
  size_t line_number = 0;
};
