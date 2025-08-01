// Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This file is part of vglog-filter and is licensed under
// the GNU General Public License v3.0 or later.
// See the LICENSE file in the project root for details.

#include "test_helpers.h"
#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <unistd.h>
#include <sys/wait.h>

bool run_test(const std::string& test_name, const std::vector<std::string>& args, const std::string& expected_output) {
    std::cout << "Running test: " << test_name << std::endl;

    std::vector<const char*> c_args;
    c_args.push_back("./build/bin/vglog-filter");
    for (const auto& arg : args) {
        c_args.push_back(arg.c_str());
    }
    c_args.push_back(nullptr);

    int pipefd[2];
    if (pipe(pipefd) == -1) {
        perror("pipe");
        return false;
    }

    pid_t pid = fork();
    if (pid == -1) {
        perror("fork");
        return false;
    }

    if (pid == 0) { // Child process
        close(pipefd[0]);
        dup2(pipefd[1], STDOUT_FILENO);
        close(pipefd[1]);
        execv(c_args[0], const_cast<char* const*>(c_args.data()));
        perror("execv");
        exit(127);
    } else { // Parent process
        close(pipefd[1]);
        std::string actual_output;
        char buffer[128];
        ssize_t count;
        while ((count = read(pipefd[0], buffer, sizeof(buffer))) > 0) {
            actual_output.append(buffer, count);
        }
        close(pipefd[0]);

        int status;
        waitpid(pid, &status, 0);

        if (WIFEXITED(status) && WEXITSTATUS(status) == 0) {
            if (trim(actual_output) == trim(expected_output)) {
                TEST_PASS(test_name);
                return true;
            } else {
                std::cerr << "FAIL: " << test_name << std::endl;
                std::cerr << "  Expected: " << trim(expected_output) << std::endl;
                std::cerr << "  Actual:   " << trim(actual_output) << std::endl;
                return false;
            }
        } else {
            std::cerr << "FAIL: " << test_name << " (process exited with non-zero status)" << std::endl;
            return false;
        }
    }
}

int main() {
    bool all_passed = true;
    // Add tests here...

    if (all_passed) {
        std::cout << "All CLI option tests passed!" << std::endl;
        return 0;
    } else {
        std::cout << "Some CLI option tests failed." << std::endl;
        return 1;
    }
}
