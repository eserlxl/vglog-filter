// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#pragma once

#include "options.h"

#include <cstddef>
#include <iosfwd>
#include <memory> 
#include <span>
#include <string>
#include <string_view>
#include <vector>

// RAII wrapper for FILE*
class FileHandle {
public:
    explicit FileHandle(const char* filename, const char* mode);
    ~FileHandle();
    // Non-copyable
    FileHandle(const FileHandle&) = delete;
    FileHandle& operator=(const FileHandle&) = delete;
    // Moveable
    FileHandle(FileHandle&& other) noexcept;
    FileHandle& operator=(FileHandle&& other) noexcept;

    [[nodiscard]] std::FILE* get() const noexcept;
    explicit operator bool() const noexcept;

private:
    std::FILE* fp = nullptr;
};

// Formatted error text
[[nodiscard]] std::string createErrorMessage(std::string_view operation,
                                               std::string_view filename,
                                               std::string_view details = {}) noexcept;

// Progress helpers
void reportProgress(std::size_t bytesProcessed, std::size_t totalBytes, std::string_view filename);
[[nodiscard]] std::size_t getMemoryUsageMb() noexcept;
void reportMemoryUsage(std::string_view operation, std::string_view filename = {});

// File helpers
[[nodiscard]] std::string readFileContent(std::string_view fname);
[[nodiscard]] std::vector<std::string> readFileLines(std::string_view fname);
[[nodiscard]] bool isLargeFile(std::string_view fname);
[[nodiscard]] std::size_t getFileSizeBytes(std::string_view fname);

// Stream processing wrapper
void processFileStream(std::string_view fname, const Options& opt);

// Opens a file for reading. Handles .gz files transparently.
[[nodiscard]] std::unique_ptr<std::istream> openInputFile(const std::string& path);

// Opens a file for writing. Handles .gz files transparently via pipe.
[[nodiscard]] std::unique_ptr<std::ostream> openOutputFile(const std::string& path);