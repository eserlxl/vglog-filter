#pragma once

#include <cstdint>
#include <optional>
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
  std::string rawContent;

  /// Deduplication signature (usually based on stack semantics)
  std::string signature;

  /// The type of error (e.g., "Invalid read of size 4")
  std::string errorType;

  /// Process ID extracted from the Valgrind marker "==PID=="
  std::string pid;

  /// Individual stack frames extracted from the block
  std::vector<std::string> stackTrace;

  /// Source line number where this block started in the input stream
  size_t lineNumber = 0;

  /// Thread ID if present (e.g. from "Thread 1:")
  std::optional<int32_t> tid;

  struct StackFrame {
    std::string raw;
    std::string address;
    std::string function;
    std::string location;
  };
  std::vector<StackFrame> stackFrames;

  /**
   * @brief Checks if the error type matches a pattern (substring).
   */
  [[nodiscard]] bool matchesErrorType(std::string_view typePattern) const {
    return errorType.find(typePattern) != std::string::npos;
  }

  /**
   * @brief Checks if any stack frame matches the given patterns.
   * @param functionPattern Substring to find in function name (if non-empty)
   * @param locationPattern Substring to find in location/file (if non-empty)
   * @return true if both patterns (when provided) match in the SAME frame.
   */
  /**
   * @brief Checks if any stack frame satisfies the given predicate.
   * @param predicate A callable that takes a const StackFrame& and returns bool.
   * @return true if predicate returns true for any frame.
   */
  template <typename Predicate>
  [[nodiscard]] bool hasFrame(Predicate predicate) const {
    for (const auto& frame : stackFrames) {
      if (predicate(frame)) {
        return true;
      }
    }
    return false;
  }

  /**
   * @brief Checks if any stack frame matches the given patterns.
   * @param functionPattern Substring to find in function name (if non-empty)
   * @param locationPattern Substring to find in location/file (if non-empty)
   * @return true if both patterns (when provided) match in the SAME frame.
   */
  [[nodiscard]] bool hasFrameMatching(std::string_view functionPattern,
                                      std::string_view locationPattern = "") const {
    return hasFrame([&](const StackFrame& frame) {
      bool funcMatch =
          functionPattern.empty() || frame.function.find(functionPattern) != std::string::npos;
      bool locMatch =
          locationPattern.empty() || frame.location.find(locationPattern) != std::string::npos;
      return funcMatch && locMatch;
    });
  }

  // Iteration 2 Extensions
  [[nodiscard]] bool involvesSourceFile(std::string_view filename) const {
    return hasFrameMatching("", filename);
  }

  [[nodiscard]] std::vector<std::string> getUniqueFiles() const {
    std::vector<std::string> files;
    for (const auto& frame : stackFrames) {
      if (!frame.location.empty()) {
        // extract filename from location if needed, but location usually is "file:line"
        // for now just return the location string
        files.push_back(frame.location);
      }
    }
    return files;
  }
};
