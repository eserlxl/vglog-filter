#pragma once

#include "log_processor.h" // For LogStats
#include <cstdio>

class StatsPrinter {
public:
  enum class Format { Text, Json };

  static void print(const LogStats& stats, std::FILE* out, Format format);

private:
  static void printText(const LogStats& stats, std::FILE* out);
  static void printJson(const LogStats& stats, std::FILE* out);
};
