#pragma once

#include "filter_config.h"
#include <string>
#include <string_view>

class SuppressionParser {
public:
    /**
     * @brief Parses a Valgrind suppression file and updates the FilterConfig.
     * 
     * Reads the file line by line.
     * - "type:value" lines are extracted.
     * - "fun:<name>" -> added to filter.excludeFunctions
     * - "Memcheck:<Type>" -> added to filter.excludeTypes (mapped if necessary)
     * - "obj:<path>" -> optionally added to excluded sets or ignored for now.
     * 
     * @param path Path to the suppression file.
     * @param config The FilterConfig object to update.
     */
    static void parseFile(const std::string& path, FilterConfig& config);

    /**
     * @brief Parses a raw string content of a suppression file.
     */
    static void parseContent(std::string_view content, FilterConfig& config);
};
