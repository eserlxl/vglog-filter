#include "config_loader.h"
#include "options.h"
#include "test_helpers.h"
#include <fstream>
#include <iostream>
#include <cstdio>

bool test_config_loading_json() {
  std::string filename = "test_config.json";
  {
      std::ofstream f(filename);
      f << R"({
          "sanitizer": "asan",
          "jobs": 4,
          "exclude": {
              "types": ["T1", "T2"], 
              "functions": ["f1"]
          },
          "include": {
              "pids": [100, 200]
          },
          "verbose": true
      })";
  }
  
  Options opt;
  opt.configFile = filename;
  // Pre-set some defaults to ensure config overwrites or not
  opt.sanitizerType = SanitizerType::Auto;
  
  ConfigLoader::load(opt);
  
  std::remove(filename.c_str());
  
  // Verification
  TEST_ASSERT(opt.sanitizerType == SanitizerType::Asan, "Sanitizer from config");
  TEST_ASSERT(opt.jobs == 4, "Jobs from config");
  TEST_ASSERT(opt.verbose == true, "Verbose from config");
  
  TEST_ASSERT(opt.filter.excludeTypes.size() == 2, "Exclude types count");
  TEST_ASSERT(opt.filter.excludeTypes[0] == "T1", "Exclude type 1");
  
  TEST_ASSERT(opt.filter.includePids.size() == 2, "Include PIDs count");
  TEST_ASSERT(opt.filter.includePids[0] == 100, "Include PID 1");
  
  TEST_PASS("Config Loading JSON");
  return true;
}

int main() {
  if (test_config_loading_json()) {
      std::cout << "Config Loader Test Passed" << std::endl;
      return 0;
  }
  return 1;
}
