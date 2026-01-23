#include "config_loader.h"
#include <cstdio>
#include <fstream>
#include <regex>
#include <sstream>

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

  // Simple regex for string/bool/number values
  // Matches "key": "value" OR "key": value
  std::regex key_val(R"rx("(\w+)"\s*:\s*("([^"]*)"|true|false|\d+))rx");
  auto search_start = content.cbegin();
  std::smatch match;
  while (std::regex_search(search_start, content.cend(), match, key_val)) {
    std::string key = match[1];
    std::string val_raw = match[2];
    std::string val_str;

    // Remove quotes if present
    if (val_raw.size() >= 2 && val_raw.front() == '"' && val_raw.back() == '"') {
      val_str = val_raw.substr(1, val_raw.size() - 2);
    } else {
      val_str = val_raw;
    }

    // Apply if default
    if (key == "color") {
      if (val_str == "true")
        opt.color = true;
      // else opt.color = false; // Don't disable if enabled by CLI
    } else if (key == "timeAfter") {
      if (opt.timeAfter.empty())
        opt.timeAfter = val_str;
    } else if (key == "timeBefore") {
      if (opt.timeBefore.empty())
        opt.timeBefore = val_str;
    } else if (key == "statsFile") {
      if (opt.statsFile.empty())
        opt.statsFile = val_str;
    }
    // ... extend for other options as needed

    search_start = match.suffix().first;
  }
}
