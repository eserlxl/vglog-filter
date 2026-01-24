#include "../include/config_loader.h"
#include "../include/options.h"
#include "test_helpers.h"
#include <cassert>
#include <iostream>
#include <fstream>
#include <filesystem>

void test_regex_config_loading() {
    std::string configPath = "test_regex_config.json";
    std::ofstream ofs(configPath);
    ofs << R"({
        "exclude": {
            "typesRegex": ["^Error.*"],
            "functionsRegex": ["^bad_.*"]
        },
        "include": {
            "typesRegex": ["^Important.*"]
        }
    })";
    ofs.close();

    Options opt;
    opt.configFile = configPath;
    ConfigLoader::load(opt);

    assert(opt.filter.excludeTypesRegex.size() == 1);
    assert(opt.filter.excludeTypesRegex[0] == "^Error.*");

    assert(opt.filter.excludeFunctionsRegex.size() == 1);
    assert(opt.filter.excludeFunctionsRegex[0] == "^bad_.*");

    assert(opt.filter.includeTypesRegex.size() == 1);
    assert(opt.filter.includeTypesRegex[0] == "^Important.*");

    std::filesystem::remove(configPath);
    std::cout << "test_regex_config_loading passed\n";
}

int main() {
    test_regex_config_loading();
    return 0;
}
