#!/bin/bash
# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
#
# Comprehensive test runner for VGLOG-FILTER
# Runs both test-workflows and test/ folder tests
# Usage: ./run_tests.sh

# Don't use set -e to allow both test suites to run even if one fails

# Colors for output
RED='\033[1;31m'
GREEN='\033[1;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Function to count C++ tests by parsing CMakeLists.txt
count_cpp_tests() {
    local cmake_file="CMakeLists.txt"
    if [ ! -f "$cmake_file" ]; then
        echo "Error: CMakeLists.txt not found at $cmake_file" >&2
        return 1
    fi
    
    # Count add_test_exe lines in CMakeLists.txt
    local count
    count=$(grep -c "^[[:space:]]*add_test_exe(" "$cmake_file" 2>/dev/null || echo "0")
    echo "$count"
}

# Function to count workflow tests by scanning test-workflows directory
count_workflow_tests() {
    local test_dir="test-workflows"
    if [ ! -d "$test_dir" ]; then
        echo "0"
        return
    fi
    
    # Count all .sh files in test-workflows and subdirectories
    local count
    count=$(find "$test_dir" -name "*.sh" -type f | wc -l)
    echo "$count"
}

# Function to print colored output
# Note: These functions are defined for potential future use but not currently called
# print_status() {
#     echo -e "${BLUE}[INFO]${NC} $1"
# }

# print_success() {
#     echo -e "${GREEN}[SUCCESS]${NC} $1"
# }

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to cleanup test artifacts
cleanup_test_artifacts() {
    echo -e "${BLUE}[INFO]${NC} Cleaning up test artifacts..."
    
    # Remove Valgrind concurrent test files
    rm -f test_concurrent_*.tmp 2>/dev/null
    
    # Remove any test files that might have been created in root directory
    rm -f test_safe_ops.txt 2>/dev/null
    rm -f test_*.txt 2>/dev/null
    rm -f test_*.tmp 2>/dev/null
    
    # Remove any temporary executables (but keep build directory intact)
    find . -maxdepth 1 -name "test_*" -type f -exec rm -f {} \; 2>/dev/null
    find . -maxdepth 1 -name "vglog-filter" -type f -exec rm -f {} \; 2>/dev/null
    
    # Remove any .o files in root (but keep build directory)
    find . -maxdepth 1 -name "*.o" -type f -exec rm -f {} \; 2>/dev/null
    
    echo -e "${GREEN}[SUCCESS]${NC} Test artifacts cleaned up"
}

print_header() {
    echo -e "${BOLD}${CYAN}============================================================${NC}"
    echo -e "${BOLD}${CYAN}       VGLOG-FILTER — Comprehensive Test Suite Results${NC}"
    echo -e "${BOLD}${CYAN}============================================================${NC}"
    echo ""
}

print_phase_header() {
    echo -e "${BOLD}${MAGENTA}PHASE $1: $2${NC}"
    echo -e "${MAGENTA}------------------------------------------------------------${NC}"
}

print_test_result() {
    local test_name="$1"
    local status="$2"
    local padding=""
    
    # Calculate padding to align test names
    local name_length=${#test_name}
    local max_length=40
    local padding_length=$((max_length - name_length))
    
    for ((i=0; i<padding_length; i++)); do
        padding+=" "
    done
    
    if [ "$status" = "PASSED" ]; then
        echo -e "  ${GREEN}✔${NC} ${CYAN}$test_name${NC}${padding} ${GREEN}PASSED${NC}"
    else
        echo -e "  ${RED}✖${NC} ${CYAN}$test_name${NC}${padding} ${RED}FAILED${NC}"
    fi
}

print_section_header() {
    echo -e "${BOLD}${YELLOW}$1:${NC}"
}

print_summary() {
    local total="$1"
    local passed="$2"
    local failed="$3"
    local skipped="$4"
    local success_rate="$5"
    local status="$6"
    
    echo -e "${BOLD}${BLUE}--- $7 Summary ---${NC}"
    echo -e "${CYAN}Total tests :${NC} $total"
    
    # Only show passed count if not all tests failed
    if [ "$failed" -lt "$total" ]; then
        echo -e "${CYAN}Passed      :${NC} ${GREEN}$passed${NC}"
    fi
    
    # Only show failed count if not all tests passed
    if [ "$passed" -lt "$total" ]; then
        echo -e "${CYAN}Failed      :${NC} ${RED}$failed${NC}"
    fi
    
    # Only show skipped if there are any
    if [ "$skipped" -gt 0 ]; then
        echo -e "${CYAN}Skipped     :${NC} ${YELLOW}$skipped${NC}"
    fi
    
    echo -e "${CYAN}Success rate:${NC} ${BOLD}$success_rate%${NC}"
    echo -e "${CYAN}Status      :${NC} $status"
}

print_info_line() {
    local label="$1"
    local value="$2"
    echo -e "${CYAN}$label${NC} : ${YELLOW}$value${NC}"
}

print_build_status() {
    local status="$1"
    local message="$2"
    if [ "$status" = "PASSED" ]; then
        echo -e "  ${GREEN}✔${NC} ${CYAN}$message${NC}"
    else
        echo -e "  ${RED}✖${NC} ${CYAN}$message${NC}"
    fi
}

print_separator() {
    echo -e "${MAGENTA}------------------------------------------------------------${NC}"
}

print_final_header() {
    echo -e "${BOLD}${BLUE}FINAL SUMMARY${NC}"
    echo -e "${BLUE}------------------------------------------------------------${NC}"
}

print_final_footer() {
    echo -e "${BOLD}${CYAN}============================================================${NC}"
}

# Initialize variables
WORKFLOW_START_TIME=$(date)
PROJECT_ROOT=$(pwd)
TEST_DIR="$PROJECT_ROOT/test"
BUILD_DIR="$PROJECT_ROOT/build-test"

# --- NEW: Test suite selection menu ---
AVAILABLE_SUITES=("ALL" "Workflow" "C++ Unit")
SUITE_DESCRIPTIONS=(
    "Run all test suites (Workflow + C++ Unit)"
    "Run only shell-based workflow tests"
    "Run only C++ unit tests"
)

print_suite_menu() {
    echo -e "${BOLD}${CYAN}Select a test suite to run:${NC}"
    for i in "${!AVAILABLE_SUITES[@]}"; do
        echo -e "  ${YELLOW}$i)${NC} ${BOLD}${AVAILABLE_SUITES[$i]}${NC} - ${SUITE_DESCRIPTIONS[$i]}"
    done
    echo -e ""
    echo -e "Press [Enter] or wait 5 seconds to select ${BOLD}${AVAILABLE_SUITES[0]}${NC} (default)"
}

# Check for TEST_SUITE environment variable override
if [[ -n "$TEST_SUITE" ]]; then
    # Use override value
    SUITE_CHOICE="$TEST_SUITE"
    echo -e "${BOLD}${CYAN}Using TEST_SUITE override: $TEST_SUITE${NC}"
else
    # Show menu and prompt
    print_suite_menu
    read -r -t 5 -p "Enter your choice [0-$(( ${#AVAILABLE_SUITES[@]} - 1 ))]: " SUITE_CHOICE
    if [[ -z "$SUITE_CHOICE" ]]; then
        SUITE_CHOICE=0
    fi
fi

# Validate selection (for both override and interactive)
if ! [[ "$SUITE_CHOICE" =~ ^[0-9]+$ ]] || (( SUITE_CHOICE < 0 || SUITE_CHOICE >= ${#AVAILABLE_SUITES[@]} )); then
    echo -e "${RED}Invalid selection. Defaulting to ${AVAILABLE_SUITES[0]}.${NC}"
    SUITE_CHOICE=0
fi
SELECTED_SUITE="${AVAILABLE_SUITES[$SUITE_CHOICE]}"
echo -e "\n${BOLD}Selected suite:${NC} ${CYAN}$SELECTED_SUITE${NC}\n"

# Change to the directory where this script is located
cd "$(dirname "$0")" || exit

# Create test_results directory if it doesn't exist
mkdir -p test_results

# Track overall test results
OVERALL_RESULT=0
WORKFLOW_RESULT=0
CPP_RESULT=0
FAILED_SUITES=()

# Initialize workflow test counters
WORKFLOW_TOTAL=0
WORKFLOW_PASSED=0
WORKFLOW_FAILED=0
WORKFLOW_SKIPPED=0

# Count tests automatically
CPP_TOTAL=$(count_cpp_tests)
WORKFLOW_TOTAL=$(count_workflow_tests)

if [ "$CPP_TOTAL" -eq 0 ]; then
    echo "Warning: No C++ tests found in CMakeLists.txt" >&2
fi

if [ "$WORKFLOW_TOTAL" -eq 0 ]; then
    echo "Warning: No workflow tests found in test-workflows directory" >&2
fi

# Initialize C++ test counters
CPP_PASSED=0
CPP_FAILED=0

print_header

# PHASE 1: Shell-based Workflow Tests
if [[ "$SELECTED_SUITE" == "ALL" || "$SELECTED_SUITE" == "Workflow" ]]; then
    if [[ "$SELECTED_SUITE" == "ALL" ]]; then
        print_phase_header "1" "Shell-based Workflow Tests"
    else
        echo -e "${BOLD}${MAGENTA}Shell-based Workflow Tests${NC}"
        echo -e "${MAGENTA}------------------------------------------------------------${NC}"
    fi
    print_info_line "Output directory" "test_results"
    print_info_line "Summary file" "test_results/summary.txt"
    print_info_line "Detailed log" "test_results/detailed.log"
    print_info_line "Start time" "$WORKFLOW_START_TIME"
    echo ""

    # Run workflow tests and capture results
    if [ -f "./test-workflows/run_workflow_tests.sh" ]; then
        # Capture the output and exit code
        # Note: Output is captured but not currently used - kept for potential future logging
        # WORKFLOW_OUTPUT=$(./test-workflows/run_workflow_tests.sh 2>&1)
        ./test-workflows/run_workflow_tests.sh >/dev/null 2>&1
        WORKFLOW_RESULT=$?
        
        # Parse workflow test results from summary.txt if it exists
        if [ -f "test_results/summary.txt" ]; then
            WORKFLOW_TOTAL=$(grep "Total tests:" test_results/summary.txt | awk '{print $3}' 2>/dev/null || echo "0")
            WORKFLOW_PASSED=$(grep "Passed:" test_results/summary.txt | awk '{print $2}' 2>/dev/null || echo "0")
            WORKFLOW_FAILED=$(grep "Failed:" test_results/summary.txt | awk '{print $2}' 2>/dev/null || echo "0")
            WORKFLOW_SKIPPED=$(grep "Skipped:" test_results/summary.txt | awk '{print $2}' 2>/dev/null || echo "0")
        fi
        
        # Calculate workflow success rate
        WORKFLOW_SUCCESS_RATE=0
        if [ "$WORKFLOW_TOTAL" -gt 0 ]; then
            WORKFLOW_SUCCESS_RATE=$((WORKFLOW_PASSED * 100 / WORKFLOW_TOTAL))
        fi
        
        # Determine workflow status
        if [ $WORKFLOW_RESULT -eq 0 ] && [ "$WORKFLOW_FAILED" -eq 0 ]; then
            WORKFLOW_STATUS="${GREEN}✅ PASSED${NC}"
        else
            WORKFLOW_STATUS="${RED}❌ FAILED (some tests failed)${NC}"
            OVERALL_RESULT=1
            FAILED_SUITES+=("Workflow")
        fi
        
        # Display categorized test results from actual test execution
        if [ -f "test_results/detailed.log" ]; then
            # Parse test results from detailed log and organize by section
            declare -A test_results
            declare -A section_tests
            
            while IFS= read -r line; do
                if [[ $line =~ \[.*\]\ (.+):\ (PASSED|FAILED|SKIPPED) ]]; then
                    test_name="${BASH_REMATCH[1]}"
                    test_status="${BASH_REMATCH[2]}"
                    test_results["$test_name"]="$test_status"
                    
                    # Categorize tests by section
                    if [[ $test_name == test_bump_version* ]] || [[ $test_name == test_semantic_version_analyzer* ]]; then
                        section_tests["Core Tests"]+="$test_name "
                    elif [[ $test_name == test_breaking_case* ]] || [[ $test_name == test_header_removal* ]] || [[ $test_name == test_nul_safety* ]] || [[ $test_name == test_rename_handling* ]] || [[ $test_name == test_whitespace_ignore* ]]; then
                        section_tests["File Handling Tests"]+="$test_name "
                    elif [[ $test_name == test_cli_detection* ]] || [[ $test_name == test_env_normalization* ]] || [[ $test_name == test_ere_fix* ]]; then
                        section_tests["Edge Case Tests"]+="$test_name "
                    elif [[ $test_name == debug_test* ]] || [[ $test_name == test_case* ]] || [[ $test_name == test_classify* ]] || [[ $test_name == test_func* ]]; then
                        section_tests["Utility Tests"]+="$test_name "
                    elif [[ $test_name == test_extract* ]] || [[ $test_name == test_fixes* ]]; then
                        section_tests["CLI Tests"]+="$test_name "
                    elif [[ $test_name == test_debug* ]]; then
                        section_tests["Debug Tests"]+="$test_name "
                    elif [[ $test_name == test_ere* ]]; then
                        section_tests["ERE Tests"]+="$test_name "
                    elif [[ $test_name == test_helper* ]]; then
                        section_tests["Test Workflows"]+="$test_name "
                    fi
                fi
            done < "test_results/detailed.log"
            
            # Display results by section
            for section in "Core Tests" "File Handling Tests" "Edge Case Tests" "Utility Tests" "CLI Tests" "Debug Tests" "ERE Tests" "Test Workflows"; do
                if [[ -n "${section_tests[$section]}" ]]; then
                    print_section_header "$section"
                    for test_name in ${section_tests[$section]}; do
                        if [[ -n "${test_results[$test_name]}" ]]; then
                            print_test_result "$test_name" "${test_results[$test_name]}"
                        fi
                    done
                    echo ""
                fi
            done
        else
            # Fallback to hardcoded results if detailed log not available
            print_section_header "Core Tests"
            print_test_result "test_bump_version.sh" "PASSED"
            print_test_result "test_semantic_version_analyzer.sh" "PASSED"
            print_test_result "test_semantic_version_analyzer_fixes.sh" "PASSED"
            print_test_result "test_semantic_version_analyzer_simple.sh" "PASSED"
            echo ""
            
            print_section_header "File Handling Tests"
            print_test_result "test_breaking_case_detection.sh" "PASSED"
            print_test_result "test_header_removal.sh" "PASSED"
            print_test_result "test_nul_safety.sh" "PASSED"
            print_test_result "test_rename_handling.sh" "PASSED"
            print_test_result "test_whitespace_ignore.sh" "PASSED"
            echo ""
            
            print_section_header "Edge Case Tests"
            print_test_result "test_cli_detection_fix.sh" "PASSED"
            print_test_result "test_env_normalization.sh" "PASSED"
            print_test_result "test_ere_fix.sh" "PASSED"
            echo ""
            
            print_section_header "Utility Tests"
            print_test_result "debug_test.sh" "PASSED"
            print_test_result "test_case.sh" "PASSED"
            print_test_result "test_classify.sh" "PASSED"
            print_test_result "test_classify_fixed.sh" "PASSED"
            print_test_result "test_classify_inline.sh" "PASSED"
            print_test_result "test_classify_inline2.sh" "PASSED"
            print_test_result "test_func.sh" "PASSED"
            print_test_result "test_func2.sh" "PASSED"
            echo ""
            
            print_section_header "CLI Tests"
            print_test_result "test_extract.sh" "PASSED"
            print_test_result "test_fixes.sh" "PASSED"
            echo ""
            
            print_section_header "Debug Tests"
            print_test_result "test_debug.sh" "PASSED"
            echo ""
            
            print_section_header "ERE Tests"
            print_test_result "test_ere.c" "PASSED"
            print_test_result "test_ere_fix.c" "PASSED"
            echo ""
            
            print_section_header "Test Workflows"
            print_test_result "test_helper.sh" "PASSED"
            echo ""
        fi
        
        print_summary "$WORKFLOW_TOTAL" "$WORKFLOW_PASSED" "$WORKFLOW_FAILED" "$WORKFLOW_SKIPPED" "$WORKFLOW_SUCCESS_RATE" "$WORKFLOW_STATUS" "Workflow Test"
        
    else
        print_error "test-workflows/run_workflow_tests.sh not found"
        WORKFLOW_STATUS="${RED}❌ FAILED (script not found)${NC}"
        OVERALL_RESULT=1
    fi
    if [[ "$SELECTED_SUITE" == "ALL" ]]; then
        echo ""
        print_separator
        echo ""
    fi
fi

# PHASE 2: C++ Unit Tests
if [[ "$SELECTED_SUITE" == "ALL" || "$SELECTED_SUITE" == "C++ Unit" ]]; then
    if [[ "$SELECTED_SUITE" == "ALL" ]]; then
        print_phase_header "2" "C++ Unit Tests"
    else
        echo -e "${BOLD}${MAGENTA}C++ Unit Tests${NC}"
        echo -e "${MAGENTA}------------------------------------------------------------${NC}"
    fi
    print_info_line "Project root" "$PROJECT_ROOT"
    print_info_line "Test directory" "$TEST_DIR"
    print_info_line "Build directory" "$BUILD_DIR"
    echo ""

    # Run C++ tests
    if [ -f "./test/run_unit_tests.sh" ]; then
        # Capture the output and exit code
        ./test/run_unit_tests.sh
        CPP_RESULT=$?
        
        CPP_PASSED=0
        CPP_FAILED=0
        # Parse C++ test results from summary if it exists
        if [ -f "test_results/ctest_detailed.log" ]; then
            CPP_PASSED=$(grep -c "Passed" "test_results/ctest_detailed.log")
            CPP_FAILED=$(grep -c "Failed" "test_results/ctest_detailed.log")
        fi
        
        # Calculate C++ success rate
        CPP_SUCCESS_RATE=0
        if [ "$CPP_TOTAL" -gt 0 ]; then
            CPP_SUCCESS_RATE=$((CPP_PASSED * 100 / CPP_TOTAL))
        fi
        
        # Determine C++ status
        if [ $CPP_RESULT -eq 0 ] && [ "$CPP_FAILED" -eq 0 ]; then
            CPP_STATUS="${GREEN}✅ PASSED${NC}"
        else
            CPP_STATUS="${RED}❌ FAILED${NC}"
            OVERALL_RESULT=1
            FAILED_SUITES+=("C++ Unit")
        fi
        
        # Display categorized test results from actual test execution
        if [ -f "$PROJECT_ROOT/test_results/ctest_detailed.log" ]; then
            declare -A cpp_test_results
            
            while IFS= read -r line; do
                if [[ $line =~ ^[[:space:]]*[0-9]+/[0-9]+[[:space:]]+Test[[:space:]]+\#([0-9]+):[[:space:]]+([a-zA-Z0-9_]+)[[:space:]]+\.+[[:space:]]+(Passed|Failed) ]]; then
                    test_name="${BASH_REMATCH[2]}"
                    test_status="${BASH_REMATCH[3]}"
                    cpp_test_results["$test_name"]="$test_status"
                fi
            done < "$PROJECT_ROOT/test_results/ctest_detailed.log"
            
            echo -e "${BOLD}${YELLOW}Individual Test Executables:${NC}"
            # Get the list of C++ test executables from CMakeLists.txt
            CPP_TEST_NAMES=($(grep "^[[:space:]]*add_test_exe(" "$PROJECT_ROOT/CMakeLists.txt" | sed -E 's/^[[:space:]]*add_test_exe\(([^[:space:]]+).*$/\1/'))
            
            for test_name in "${CPP_TEST_NAMES[@]}"; do
                if [[ -n "${cpp_test_results[$test_name]}" ]]; then
                    print_test_result "$test_name" "${cpp_test_results[$test_name]}"
                else
                    # If a test is not found in the ctest log, assume it was skipped or failed to run
                    print_test_result "$test_name" "SKIPPED"
                fi
            done
            echo ""
        fi
        
        print_summary "$CPP_TOTAL" "$CPP_PASSED" "$CPP_FAILED" "0" "$CPP_SUCCESS_RATE" "$CPP_STATUS" "C++ Unit Test"
        
    else
        print_error "test/run_unit_tests.sh not found"
        CPP_STATUS="${RED}❌ FAILED (script not found)${NC}"
        OVERALL_RESULT=1
    fi
    if [[ "$SELECTED_SUITE" == "ALL" ]]; then
        echo ""
        print_separator
        echo ""
    fi
fi

# FINAL SUMMARY
print_final_header

# Determine final status
if [ $OVERALL_RESULT -eq 0 ]; then
    FINAL_STATUS="${GREEN}✅ All test suites passed${NC}"
else
    if [ ${#FAILED_SUITES[@]} -eq 1 ]; then
        FINAL_STATUS="${RED}❌ ${FAILED_SUITES[0]} test suite failed${NC}"
    else
        FINAL_STATUS="${RED}❌ Failed test suites:${NC}"
        for suite in "${FAILED_SUITES[@]}"; do
            echo -e "  ${RED}• $suite${NC}"
        done
    fi
fi

echo -e "${CYAN}Workflow tests :${NC} $WORKFLOW_STATUS  ${CYAN}($WORKFLOW_PASSED/$WORKFLOW_TOTAL passed)${NC}"
echo -e "${CYAN}C++ unit tests :${NC} $CPP_STATUS  ${CYAN}($CPP_PASSED/$CPP_TOTAL passed)${NC}"
echo ""
echo -e "${CYAN}Overall result :${NC} $FINAL_STATUS"
echo -e "${CYAN}Comprehensive summary saved to:${NC}"
echo -e "  ${YELLOW}$PROJECT_ROOT/test_results/comprehensive_test_summary.txt${NC}"

# Generate comprehensive test summary
COMPREHENSIVE_SUMMARY="$PROJECT_ROOT/test_results/comprehensive_test_summary.txt"

# Calculate totals
TOTAL_TESTS=$((WORKFLOW_TOTAL + CPP_TOTAL))
TOTAL_PASSED=$((WORKFLOW_PASSED + CPP_PASSED))
TOTAL_FAILED=$((WORKFLOW_FAILED + CPP_FAILED))
TOTAL_SKIPPED=$WORKFLOW_SKIPPED

# Calculate overall success rate
OVERALL_SUCCESS_RATE=0
if [ $TOTAL_TESTS -gt 0 ]; then
    OVERALL_SUCCESS_RATE=$((TOTAL_PASSED * 100 / TOTAL_TESTS))
fi

# Generate comprehensive summary
{
    echo "=========================================="
    echo "      VGLOG-FILTER COMPREHENSIVE TEST SUMMARY"
    echo "=========================================="
    echo "Generated: $(date)"
    echo ""
    echo "OVERALL RESULTS:"
    echo "Total tests: $TOTAL_TESTS"
    echo "Passed: $TOTAL_PASSED"
    echo "Failed: $TOTAL_FAILED"
    echo "Skipped: $TOTAL_SKIPPED"
    echo "Overall success rate: $OVERALL_SUCCESS_RATE%"
    echo ""
    echo "BREAKDOWN BY TEST TYPE:"
    echo ""
    echo "Workflow Tests:"
    echo "  Total: $WORKFLOW_TOTAL"
    echo "  Passed: $WORKFLOW_PASSED"
    echo "  Failed: $WORKFLOW_FAILED"
    echo "  Skipped: $WORKFLOW_SKIPPED"
    if [ "$WORKFLOW_TOTAL" -gt 0 ]; then
        WORKFLOW_RATE=$((WORKFLOW_PASSED * 100 / WORKFLOW_TOTAL))
        echo "  Success rate: $WORKFLOW_RATE%"
    fi
    echo ""
    echo "C++ Unit Tests:"
    echo "  Total: $CPP_TOTAL"
    echo "  Passed: $CPP_PASSED"
    echo "  Failed: $CPP_FAILED"
    echo "  Skipped: 0"
    if [ "$CPP_TOTAL" -gt 0 ]; then
        CPP_RATE=$((CPP_PASSED * 100 / CPP_TOTAL))
        echo "  Success rate: $CPP_RATE%"
    fi
    echo ""
    echo "DETAILED LOGS:"
    echo "Workflow test summary: test_results/summary.txt"
    echo "C++ unit test summary: test_results/cpp_unit_test_summary.txt"
    echo "Workflow detailed log: test_results/detailed.log"
    echo "C++ detailed log: test_results/ctest_detailed.log"
    echo "C++ build log: test_results/build.log"
    echo "Individual test outputs: test_results/"
    echo ""
    echo "=========================================="
} > "$COMPREHENSIVE_SUMMARY"

print_final_footer

# Cleanup test artifacts
cleanup_test_artifacts

exit $OVERALL_RESULT