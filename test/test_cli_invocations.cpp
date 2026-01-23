#include "test_helpers.h"
#include <cstring>
#include <filesystem>
#include <iostream>
#include <sstream>
#include <string>
#include <sys/wait.h>
#include <unistd.h>
#include <vector>

namespace {
constexpr int EXIT_COMMAND_NOT_FOUND = 127;
constexpr int READ_BUFFER_SIZE = 128;
} // namespace

// Helper to run vglog-filter in a subprocess and capture stdout
bool runCliTest(const std::string& testName, const std::vector<std::string>& args,
                const std::string& input, const std::string& expectedFragment) {
  int inputPipe[2];
  int outputPipe[2];

  if (pipe(inputPipe) == -1 || pipe(outputPipe) == -1) {
    perror("pipe");
    return false;
  }

  pid_t pid = fork();
  if (pid == -1) {
    perror("fork");
    return false;
  }

  if (pid == 0) {         // Child
    close(inputPipe[1]);  // Close write end of input
    close(outputPipe[0]); // Close read end of output

    dup2(inputPipe[0], STDIN_FILENO);
    dup2(outputPipe[1], STDOUT_FILENO);

    close(inputPipe[0]);
    close(outputPipe[1]);

    std::vector<const char*> cArgs;
    namespace fs = std::filesystem;
    std::string binPathStr;

    // Check potential locations
    const std::vector<std::string> searchPaths = {
        "./build/bin/vglog-filter", "./vglog-filter", "./bin/vglog-filter",
        "./bin/Debug/vglog-filter",
        "../build-asan/bin/Debug/vglog-filter" // In case we are deep
    };

    bool found = false;
    for (const auto& p : searchPaths) {
      if (fs::exists(p)) {
        binPathStr = fs::absolute(p).string();
        found = true;
        break;
      }
    }

    if (!found) {
      std::cerr << "Child cannot find vglog-filter binary. Checked:\n";
      for (const auto& p : searchPaths) {
        std::cerr << "  " << p << "\n";
      }
      std::cerr << "CWD: " << fs::current_path() << "\n";
      exit(EXIT_COMMAND_NOT_FOUND);
    }

    // std::cerr << "DEBUG: Executing " << binPathStr << "\n";
    cArgs.push_back(binPathStr.c_str());
    for (const auto& arg : args) {
      cArgs.push_back(arg.c_str());
    }
    cArgs.push_back(nullptr);

    execv(cArgs[0], const_cast<char* const*>(cArgs.data()));
    perror("execv");
    exit(EXIT_COMMAND_NOT_FOUND);
  } else { // Parent
    close(inputPipe[0]);
    close(outputPipe[1]);

    // Write input
    ssize_t written = write(inputPipe[1], input.data(), input.size());
    if (written < 0 || static_cast<size_t>(written) != input.size()) {
      perror("write");
      // If we fail to write input, the child might hang or fail.
      _exit(1);
    }
    close(inputPipe[1]); // Close to signal EOF

    // Read output
    std::string actualOutput;
    char buffer[READ_BUFFER_SIZE];
    ssize_t count;
    while ((count = read(outputPipe[0], buffer, sizeof(buffer))) > 0) {
      actualOutput.append(buffer, static_cast<size_t>(count));
    }
    close(outputPipe[0]);

    int status;
    waitpid(pid, &status, 0);

    if (WIFEXITED(status) && WEXITSTATUS(status) == 0) {
      if (actualOutput.find(expectedFragment) != std::string::npos) {
        TEST_PASS(testName);
        return true;
      }
      std::cerr << "FAIL: " << testName << "\n";
      std::cerr << "  Expected substring: " << expectedFragment << "\n";
      std::cerr << "  Actual output: " << actualOutput << "\n";
      return false;
    } else {
      std::cerr << "FAIL: " << testName << " (exited with " << WEXITSTATUS(status) << ")\n";
      return false;
    }
  }
}

int main() {
  bool passed = true;

  // Test 1: Max Errors
  // We send 4 errors, limit to 2.
  std::string inputErr = "==12345== Error\n==12345==    at main (m.c:1)\n";
  std::string input4Errs;
  for (int i = 0; i < 4; ++i)
    input4Errs += inputErr;

  std::string err1 = "==12345== ErrOne\n==12345==    at f (f.c:1)\n";
  std::string err2 = "==12345== ErrTwo\n==12345==    at f (f.c:1)\n";
  std::string err3 = "==12345== ErrThree\n==12345==    at f (f.c:1)\n";

  passed &= runCliTest("CLI Max Errors", {"-k", "--max-errors", "2"}, err1 + err2 + err3, "ErrTwo");

  // Test 2: Include Type
  // Use "Invalid read" to trigger standard block separation, append unique suffix for filtering
  passed &= runCliTest("CLI Include Type", {"-k", "--include-type", "KeepMe"},
                       "==12345== Invalid read KeepMe\n==12345==    at 0x1: f (f.c:1)\n"
                       "==12345== Invalid read DropMe\n==12345==    at 0x1: f (f.c:1)\n",
                       "KeepMe");

  // Test 3: Exclude Function
  passed &= runCliTest("CLI Exclude Function", {"-k", "--exclude-function", "bad"},
                       "==12345== Invalid read E\n==12345==    at 0x1: bad (f.c:1)\n"
                       "==12345== Invalid read E\n==12345==    at 0x1: good (f.c:1)\n",
                       "good");

  if (passed) {
    std::cout << "All CLI invocation tests passed.\n";
    return 0;
  }
  return 1;
}
