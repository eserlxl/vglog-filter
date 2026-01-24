#include "config_loader.h"
#include "json/json_parser.h"
#include <cstdio>
#include <fstream>
#include <sstream>
#include <iostream>


void ConfigLoader::load(Options& opt) {
  if (opt.configFile.empty())
    return;
  std::ifstream f(opt.configFile);
  if (!f) {
    std::fprintf(stderr, "Warning: Could not open config file: %s\n", opt.configFile.c_str());
    return;
  }
  std::stringstream buffer;
  buffer << f.rdbuf();
  std::string content = buffer.str();



  auto jsonOpt = json::Parser::parse(content);
  if (!jsonOpt || !jsonOpt->isObject()) {
    std::fprintf(stderr, "Warning: Config file must be a valid JSON object: %s\n", opt.configFile.c_str());
    return;
  }

  const auto& root = jsonOpt->objectVal;

  // Scalar mappings
  auto applyString = [&](const std::string& key, std::string& target) {
    if (root.count(key) && root.at(key).type == json::Value::Type::String) {
      if (target.empty()) target = root.at(key).stringVal;
    }
  };
  
  auto applyBool = [&](const std::string& key, bool& target) {
    if (root.count(key) && root.at(key).type == json::Value::Type::Boolean) {
        target = root.at(key).boolVal;
    }
  };

  applyString("timeAfter", opt.timeAfter);
  applyString("timeBefore", opt.timeBefore);
  applyString("statsFile", opt.statsFile);
  applyBool("color", opt.color);
  applyBool("json", opt.jsonOutput);
  applyBool("verbose", opt.verbose);
  
  // Sanitizer
  if (root.count("sanitizer") && root.at("sanitizer").type == json::Value::Type::String) {
      std::string val = root.at("sanitizer").stringVal;
      if (val == "valgrind" && opt.sanitizerType == SanitizerType::Auto) opt.sanitizerType = SanitizerType::Valgrind;
      else if (val == "asan" && opt.sanitizerType == SanitizerType::Auto) opt.sanitizerType = SanitizerType::Asan;
  }
  
  // Jobs
  if (root.count("jobs") && root.at("jobs").type == json::Value::Type::Number) {
      if (opt.jobs <= 1) { // Only override if default
          opt.jobs = static_cast<size_t>(root.at("jobs").numberVal);
      }
  }

  // Nested Objects (Recursion for complex types)
  if (root.count("exclude") && root.at("exclude").isObject()) {
      const auto& excl = root.at("exclude").objectVal;
      
      auto appendList = [&](const std::string& subKey, std::vector<std::string>& target) {
          if (excl.count(subKey) && excl.at(subKey).isArray()) {
              for (const auto& item : excl.at(subKey).arrayVal) {
                  if (item.type == json::Value::Type::String) {
                      target.push_back(item.stringVal);
                  }
              }
          }
      };
      
      appendList("types", opt.filter.excludeTypes);
      appendList("functions", opt.filter.excludeFunctions);
      appendList("files", opt.filter.excludeSourcePaths);
  }
  
  if (root.count("include") && root.at("include").isObject()) {
      const auto& incl = root.at("include").objectVal;
      
      auto appendList = [&](const std::string& subKey, std::vector<std::string>& target) {
          if (incl.count(subKey) && incl.at(subKey).isArray()) {
              for (const auto& item : incl.at(subKey).arrayVal) {
                  if (item.type == json::Value::Type::String) {
                      target.push_back(item.stringVal);
                  }
              }
          }
      };
      
      appendList("types", opt.filter.includeTypes);
      appendList("functions", opt.filter.includeFunctions);
      appendList("files", opt.filter.includeSourcePaths);
      
      // PIDs (numbers)
      if (incl.count("pids") && incl.at("pids").isArray()) {
          for (const auto& item : incl.at("pids").arrayVal) {
              if (item.type == json::Value::Type::Number) {
                  opt.filter.includePids.push_back(static_cast<int>(item.numberVal));
              }
          }
      }
  }
}

