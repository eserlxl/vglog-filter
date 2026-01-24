#include "parsers/suppression_parser.h"
#include "file_utils.h"
#include <iostream>
#include <sstream>
#include <fstream>
#include <algorithm>

void SuppressionParser::parseFile(const std::string& path, FilterConfig& config) {
    if (path.empty()) return;
    
    try {
        // Read file content using existing util or standard way
        // We don't have a "readFileContent" helper exposed easily in file_utils.h?
        // Let's implement a simple read here or use std::ifstream.
        std::ifstream fs(path);
        if (!fs) {
            std::cerr << "Warning: Could not open suppression file: " << path << "\n";
            return;
        }
        std::string content((std::istreambuf_iterator<char>(fs)), std::istreambuf_iterator<char>());
        parseContent(content, config);
    } catch (const std::exception& e) {
        std::cerr << "Error parsing suppression file " << path << ": " << e.what() << "\n";
    }
}

void SuppressionParser::parseContent(std::string_view content, FilterConfig& config) {
    std::istringstream stream(std::string{content});
    std::string line;
    bool inSuppression = false;
    
    while (std::getline(stream, line)) {
        // Trim line
        auto start = line.find_first_not_of(" \t\r");
        if (start == std::string::npos) continue; // empty
        auto end = line.find_last_not_of(" \t\r");
        std::string_view trimmed = std::string_view(line).substr(start, end - start + 1);
        
        if (trimmed == "{") {
            inSuppression = true;
            continue;
        }
        if (trimmed == "}") {
            inSuppression = false;
            continue;
        }
        
        if (inSuppression) {
            // Check for prefixes
            if (trimmed.starts_with("fun:")) {
                std::string funcName = std::string(trimmed.substr(4));
                config.excludeFunctions.push_back(funcName);
            } else if (trimmed.starts_with("Memcheck:")) {
                // Valgrind error types like Memcheck:Leak, Memcheck:Value8, etc.
                // We map these to our error types.
                // Log parser often outputs "Invalid read...", "Leak_DefinitelyLost"
                // We might just add the suffix directly or map widely.
                // For iteration 2, we'll try to add partial matches to regex if possible, 
                // or just add exact strings if our matching logic supports partials.
                // Our current "excludeTypes" does sub-string search? 
                // LogFilter::shouldKeep calls matchesErrorType which does `type.find(exclude) != npos`.
                // So "Leak" will match "Memcheck:Leak" line log? No log lines are like "Invalid read".
                // We need to map "Memcheck:Leak" -> "Leak".
                // "Memcheck:Value8" -> "Uninitialised"?
                
                std::string val = std::string(trimmed.substr(9)); // After Memcheck:
                // Heuristics
                if (val == "Leak") config.excludeTypes.push_back("Leak");
                else if (val == "Value8" || val == "Value4") config.excludeTypes.push_back("Uninitialised");
                else if (val == "Cond") config.excludeTypes.push_back("Conditional jump");
                else if (val == "Addr8" || val == "Addr4") config.excludeTypes.push_back("Invalid read"); // Or write
                else config.excludeTypes.push_back(val); // Fallback
            } else if (trimmed.starts_with("obj:")) {
                // Ignore for now or handle obj?
                // config.excludeSourcePaths.push_back(std::string(trimmed.substr(4)));
            }
        }
    }
}
