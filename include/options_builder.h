// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

#pragma once

#include "options.h"
#include <string>
#include <vector>

/**
 * @brief Fluent builder for Options struct.
 */
class OptionsBuilder {
public:
  OptionsBuilder() = default;

  OptionsBuilder& setOutput(const std::string& path) {
    opts.outputFile = path;
    return *this;
  }

  OptionsBuilder& setJson(bool enabled = true) {
    opts.jsonOutput = enabled;
    return *this;
  }

  OptionsBuilder& setDetailedJson(bool enabled = true) {
    opts.detailedJson = enabled;
    if (enabled)
      opts.jsonOutput = true;
    return *this;
  }

  OptionsBuilder& setDetailedStats(bool enabled = true) {
    opts.detailedStats = enabled;
    return *this;
  }

  OptionsBuilder& addExcludePid(int32_t pid) {
    opts.filter.excludePids.push_back(pid);
    return *this;
  }

  OptionsBuilder& addIncludePid(int32_t pid) {
    opts.filter.includePids.push_back(pid);
    return *this;
  }

  OptionsBuilder& addIncludeThread(int32_t tid) {
    opts.filter.includeThreads.push_back(tid);
    return *this;
  }

  OptionsBuilder& addIncludeType(const std::string& type) {
    opts.filter.includeTypes.push_back(type);
    return *this;
  }

  OptionsBuilder& addExcludeFunction(const std::string& func) {
    opts.filter.excludeFunctions.push_back(func);
    return *this;
  }

  OptionsBuilder& setVerbose(bool enabled = true) {
    opts.verbose = enabled;
    opts.scrubRaw = !enabled; // Consistency
    return *this;
  }

  OptionsBuilder& setStrictMode(bool enabled = true) {
    opts.strictMode = enabled;
    return *this;
  }

    OptionsBuilder& addMarker(const std::string& marker) {
    opts.markers.push_back(marker);
    return *this;
  }

  // Iteration 2 Extensions
  OptionsBuilder& setTimeAfter(const std::string& time) {
    opts.timeAfter = time;
    return *this;
  }

  OptionsBuilder& setTimeBefore(const std::string& time) {
    opts.timeBefore = time;
    return *this;
  }

  OptionsBuilder& addIncludeStackPattern(const std::string& pattern) {
    opts.filter.includeStackPatterns.push_back(pattern);
    return *this;
  }

  // Note: addExcludeStackPattern existed in config but not builder? 
  // Config had excludeStackPatterns.
  OptionsBuilder& addExcludeStackPattern(const std::string& pattern) {
      opts.filter.excludeStackPatterns.push_back(pattern);
      return *this;
  }

  OptionsBuilder& addExcludeTypeRegex(const std::string& regex) {
    opts.filter.excludeTypesRegex.push_back(regex);
    return *this;
  }

  OptionsBuilder& addIncludeTypeRegex(const std::string& regex) {
    opts.filter.includeTypesRegex.push_back(regex);
    return *this;
  }

  OptionsBuilder& addExcludeFunctionRegex(const std::string& regex) {
    opts.filter.excludeFunctionsRegex.push_back(regex);
    return *this;
  }

  OptionsBuilder& addIncludeFunctionRegex(const std::string& regex) {
      opts.filter.includeFunctionsRegex.push_back(regex);
      return *this;
  }

  [[nodiscard]] Options build() const {
    return opts;
  }

private:
  Options opts;
};
