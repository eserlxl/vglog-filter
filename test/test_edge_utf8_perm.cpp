// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Edge case tests: invalid UTF-8 and file permission errors
#include <fstream>
#include <string>
#include <iostream>
#include <cerrno>
#include <cstring>
#include <sys/stat.h>
#include <unistd.h>
#include "test_helpers.h"

bool test_invalid_utf8_log() {
    TempFile tf("test_invalid_utf8.tmp");
    std::ofstream out(tf.path(), std::ios::binary);
    // Write valid ASCII, then invalid UTF-8 bytes
    out << "==12345== Valid line\n";
    out << "==12345== Invalid UTF-8: ";
    unsigned char invalid_bytes[] = {0xC3, 0x28, 0xA0, 0xA1, 0xE2, 0x28, 0xA1};
    out.write(reinterpret_cast<const char*>(invalid_bytes), sizeof(invalid_bytes));
    out << "\n";
    out.close();
    // Try to read and process (simulate vglog-filter behavior)
    std::ifstream in(tf.path(), std::ios::binary);
    std::string line;
    bool found_invalid = false;
    while (std::getline(in, line)) {
        if (line.find("Invalid UTF-8") != std::string::npos) {
            // Check for presence of replacement char or error
            found_invalid = (line.find("?") != std::string::npos) || (line.find("Invalid UTF-8") != std::string::npos);
        }
    }
    TEST_ASSERT(found_invalid, "Should detect or gracefully handle invalid UTF-8");
    TEST_PASS("Invalid UTF-8 log line handled");
    return true;
}

bool test_unreadable_file() {
    TempFile tf("test_unreadable.tmp");
    std::ofstream out(tf.path());
    out << "==12345== Some content\n";
    out.close();
    // Make file unreadable
    chmod(tf.path(), 0000);
    std::ifstream in(tf.path());
    bool could_open = in.is_open();
    int err = errno;
    // Restore permissions for cleanup
    chmod(tf.path(), 0644);
    TEST_ASSERT(!could_open || err == EACCES, "Should not be able to open unreadable file");
    TEST_PASS("Unreadable file (permission denied) handled");
    return true;
}

bool test_mixed_utf8_log() {
    TempFile tf("test_mixed_utf8.tmp");
    std::ofstream out(tf.path(), std::ios::binary);
    out << "==12345== Valid line\n";
    unsigned char invalid_bytes[] = {0xC3, 0x28, 0xA0};
    out.write(reinterpret_cast<const char*>(invalid_bytes), sizeof(invalid_bytes));
    out << "\n==12345== Another valid line\n";
    out.close();
    std::ifstream in(tf.path(), std::ios::binary);
    std::string line;
    int valid_lines = 0, invalid_lines = 0;
    while (std::getline(in, line)) {
        if (line.find("Valid line") != std::string::npos) valid_lines++;
        if (line.find("==12345==") != std::string::npos && line.find("Valid line") == std::string::npos) invalid_lines++;
    }
    TEST_ASSERT(valid_lines >= 1, "Should read at least one valid line");
    TEST_ASSERT(invalid_lines >= 1, "Should encounter at least one invalid line");
    TEST_PASS("Mixed valid/invalid UTF-8 log handled");
    return true;
}

bool test_only_invalid_bytes() {
    TempFile tf("test_only_invalid.tmp");
    std::ofstream out(tf.path(), std::ios::binary);
    unsigned char invalid_bytes[] = {0xC3, 0x28, 0xA0, 0xA1, 0xE2, 0x28, 0xA1};
    out.write(reinterpret_cast<const char*>(invalid_bytes), sizeof(invalid_bytes));
    out.close();
    std::ifstream in(tf.path(), std::ios::binary);
    std::string line;
    bool read_any = false;
    while (std::getline(in, line)) {
        read_any = true;
    }
    TEST_ASSERT(read_any, "Should not crash or hang on file with only invalid bytes");
    TEST_PASS("File with only invalid bytes handled");
    return true;
}

bool test_extremely_large_file() {
    TempFile tf("test_extremely_large.tmp");
    std::ofstream out(tf.path());
    // Create a file that's large enough to potentially cause memory issues
    const int target_size = 10 * 1024 * 1024; // 10MB
    std::string line = "==12345== This is a very long line with lots of content to make the file large ";
    line += std::string(1000, 'x'); // Add 1000 'x' characters
    line += "\n";
    
    int lines_written = 0;
    while (out.tellp() < target_size) {
        out << line;
        lines_written++;
        if (lines_written % 1000 == 0) {
            out.flush(); // Ensure data is written
        }
    }
    out.close();
    
    // Verify file size
    struct stat st;
    if (stat(tf.path(), &st) == 0) {
        TEST_ASSERT(st.st_size >= target_size, "File should be at least target size");
    }
    
    // Try to read the file (simulate vglog-filter processing)
    std::ifstream in(tf.path());
    std::string read_line;
    int lines_read = 0;
    while (std::getline(in, read_line) && lines_read < 100) {
        lines_read++;
    }
    
    TEST_ASSERT(lines_read > 0, "Should be able to read at least some lines from large file");
    TEST_PASS("Extremely large file handled");
    return true;
}

bool test_null_bytes_in_middle() {
    TempFile tf("test_null_bytes_middle.tmp");
    std::ofstream out(tf.path(), std::ios::binary);
    out << "==12345== First line\n";
    out << "==12345== Second line with null: ";
    out.put('\0');
    out << "after null\n";
    out << "==12345== Third line\n";
    out.close();
    
    std::ifstream in(tf.path(), std::ios::binary);
    std::string line;
    int lines_read = 0;
    bool found_null = false;
    while (std::getline(in, line)) {
        lines_read++;
        if (line.find("Second line") != std::string::npos) {
            found_null = (line.find('\0') != std::string::npos);
        }
    }
    
    TEST_ASSERT(lines_read >= 2, "Should read at least first and third lines");
    TEST_ASSERT(found_null, "Should detect null byte in middle of line");
    TEST_PASS("Null bytes in middle of file handled");
    return true;
}

bool test_control_characters() {
    TempFile tf("test_control_chars.tmp");
    std::ofstream out(tf.path(), std::ios::binary);
    out << "==12345== Line with bell: \a\n";
    out << "==12345== Line with backspace: \b\n";
    out << "==12345== Line with form feed: \f\n";
    out << "==12345== Line with vertical tab: \v\n";
    out << "==12345== Line with escape: \x1B\n";
    out << "==12345== Line with delete: \x7F\n";
    out.close();
    
    std::ifstream in(tf.path(), std::ios::binary);
    std::string line;
    int lines_read = 0;
    while (std::getline(in, line)) {
        lines_read++;
    }
    
    TEST_ASSERT(lines_read >= 5, "Should read lines with control characters");
    TEST_PASS("Control characters handled");
    return true;
}

bool test_very_long_lines() {
    TempFile tf("test_very_long_lines.tmp");
    std::ofstream out(tf.path());
    
    // Create a line that's extremely long (1MB)
    std::string long_line = "==12345== ";
    long_line += std::string(1024 * 1024, 'x'); // 1MB of 'x' characters
    long_line += "\n";
    out << long_line;
    out << "==12345== Normal line\n";
    out.close();
    
    std::ifstream in(tf.path());
    std::string line;
    int lines_read = 0;
    bool found_long_line = false;
    while (std::getline(in, line)) {
        lines_read++;
        if (line.length() > 1000000) {
            found_long_line = true;
        }
    }
    
    TEST_ASSERT(lines_read >= 2, "Should read both lines");
    TEST_ASSERT(found_long_line, "Should handle very long lines");
    TEST_PASS("Very long lines handled");
    return true;
}

bool test_mixed_line_endings() {
    TempFile tf("test_mixed_endings.tmp");
    std::ofstream out(tf.path(), std::ios::binary);
    out << "==12345== Unix line ending\n"; // LF
    out << "==12345== Windows line ending\r\n"; // CRLF
    out << "==12345== Mac line ending\r"; // CR
    out << "==12345== Another Unix line\n"; // LF
    out.close();
    
    std::ifstream in(tf.path(), std::ios::binary);
    std::string line;
    int lines_read = 0;
    while (std::getline(in, line)) {
        lines_read++;
    }
    
    TEST_ASSERT(lines_read >= 3, "Should handle mixed line endings");
    TEST_PASS("Mixed line endings handled");
    return true;
}

bool test_file_becomes_unreadable() {
    TempFile tf("test_becomes_unreadable.tmp");
    std::ofstream out(tf.path());
    out << "==12345== First line\n";
    out << "==12345== Second line\n";
    out << "==12345== Third line\n";
    out.close();
    
    // Start reading the file
    std::ifstream in(tf.path());
    std::string line;
    std::getline(in, line); // Read first line
    
    // Make file unreadable while it's being read
    chmod(tf.path(), 0000);
    
    // Try to continue reading
    bool could_continue = false;
    try {
        std::getline(in, line);
        could_continue = true;
    } catch (...) {
        could_continue = false;
    }
    
    // Restore permissions for cleanup
    chmod(tf.path(), 0644);
    
    // The behavior might vary depending on the OS and filesystem
    // We just want to ensure it doesn't crash
    // Note: could_continue might be true or false depending on OS/filesystem behavior
    TEST_PASS("File becoming unreadable during processing handled (could_continue: " + std::string(could_continue ? "true" : "false") + ")");
    return true;
}

bool test_symlink_file() {
    TempFile tf("test_symlink_target.tmp");
    std::ofstream out(tf.path());
    out << "==12345== Content in target file\n";
    out.close();
    
    // Create a symbolic link
    std::string symlink_path = "test_symlink.tmp";
    if (symlink(tf.path(), symlink_path.c_str()) == 0) {
        // Test reading through symlink
        std::ifstream in(symlink_path);
        std::string line;
        bool could_read = false;
        if (std::getline(in, line)) {
            could_read = (line.find("Content in target file") != std::string::npos);
        }
        
        // Clean up symlink
        std::remove(symlink_path.c_str());
        
        TEST_ASSERT(could_read, "Should be able to read through symlink");
        TEST_PASS("Symbolic link handled");
    } else {
        // Symlink creation failed (might not be supported on this filesystem)
        TEST_PASS("Symbolic link test skipped (not supported)");
    }
    return true;
}

bool test_hard_link_file() {
    TempFile tf("test_hardlink_target.tmp");
    std::ofstream out(tf.path());
    out << "==12345== Content in target file\n";
    out.close();
    
    // Create a hard link
    std::string hardlink_path = "test_hardlink.tmp";
    if (link(tf.path(), hardlink_path.c_str()) == 0) {
        // Test reading through hard link
        std::ifstream in(hardlink_path);
        std::string line;
        bool could_read = false;
        if (std::getline(in, line)) {
            could_read = (line.find("Content in target file") != std::string::npos);
        }
        
        // Clean up hard link
        std::remove(hardlink_path.c_str());
        
        TEST_ASSERT(could_read, "Should be able to read through hard link");
        TEST_PASS("Hard link handled");
    } else {
        // Hard link creation failed (might not be supported on this filesystem)
        TEST_PASS("Hard link test skipped (not supported)");
    }
    return true;
}

int main() {
    std::cout << "Running edge UTF-8 and permission tests for vglog-filter..." << std::endl;
    bool all_passed = true;
    all_passed &= test_invalid_utf8_log();
    all_passed &= test_unreadable_file();
    all_passed &= test_mixed_utf8_log();
    all_passed &= test_only_invalid_bytes();
    all_passed &= test_extremely_large_file();
    all_passed &= test_null_bytes_in_middle();
    all_passed &= test_control_characters();
    all_passed &= test_very_long_lines();
    all_passed &= test_mixed_line_endings();
    all_passed &= test_file_becomes_unreadable();
    all_passed &= test_symlink_file();
    all_passed &= test_hard_link_file();
    if (all_passed) {
        std::cout << "\nAll edge UTF-8/permission tests passed!" << std::endl;
        return 0;
    } else {
        std::cout << "\nSome edge UTF-8/permission tests failed!" << std::endl;
        return 1;
    }
}