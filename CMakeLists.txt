# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
cmake_minimum_required(VERSION 3.10)
project(vglog-filter LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})

option(DEBUG_MODE        "Enable debug build flags"         OFF)
option(PERFORMANCE_BUILD "Enable performance-optimised flags" ON)
option(WARNING_MODE      "Enable extra warnings"             ON)
option(BUILD_TESTS       "Build test suite"                  ON)

if (DEBUG_MODE AND PERFORMANCE_BUILD)
    message(FATAL_ERROR "DEBUG_MODE and PERFORMANCE_BUILD cannot both be ON.")
endif()

# ---------------- compile / link flags ---------------------------------------
if (DEBUG_MODE)
    set(OPT_FLAGS -g -O0)
elseif (PERFORMANCE_BUILD)
    set(OPT_FLAGS -O3 -march=native -mtune=native)
else()
    set(OPT_FLAGS -O2)
endif()

set(WARNING_FLAGS -Wall -pedantic)
if (WARNING_MODE)
    list(APPEND WARNING_FLAGS -Wextra)
endif()

add_executable(vglog-filter src/vglog-filter.cpp)

# Add test executable if BUILD_TESTS is enabled
if (BUILD_TESTS)
    add_executable(test_basic test/test_basic.cpp)
    target_compile_options(test_basic PRIVATE ${WARNING_FLAGS})
    message(STATUS "Test target 'test_basic' added")
    
    add_executable(test_integration test/test_integration.cpp)
    target_compile_options(test_integration PRIVATE ${WARNING_FLAGS})
    message(STATUS "Test target 'test_integration' added")
    
    add_executable(test_comprehensive test/test_comprehensive.cpp)
    target_compile_options(test_comprehensive PRIVATE ${WARNING_FLAGS})
    message(STATUS "Test target 'test_comprehensive' added")
    
    add_executable(test_edge_cases test/test_edge_cases.cpp)
    target_compile_options(test_edge_cases PRIVATE ${WARNING_FLAGS})
    message(STATUS "Test target 'test_edge_cases' added")
    
    add_executable(test_memory_leaks test/test_memory_leaks.cpp)
    target_compile_options(test_memory_leaks PRIVATE ${WARNING_FLAGS})
    message(STATUS "Test target 'test_memory_leaks' added")
endif()
    
target_compile_options(vglog-filter PRIVATE ${OPT_FLAGS} ${WARNING_FLAGS})

# Let CMake manage LTO automatically (requires 3.9+)
if (PERFORMANCE_BUILD AND NOT DEBUG_MODE)
    set_target_properties(vglog-filter PROPERTIES INTERPROCEDURAL_OPTIMIZATION TRUE)
endif()

target_compile_definitions(vglog-filter PRIVATE
    $<$<BOOL:PERFORMANCE_BUILD>:NDEBUG>
    $<$<BOOL:DEBUG_MODE>:DEBUG>)

# ---------------- log summary -------------------------------------------------
message(STATUS "DEBUG_MODE     : ${DEBUG_MODE}")
message(STATUS "PERFORMANCE_BUILD: ${PERFORMANCE_BUILD}")
message(STATUS "WARNING_MODE   : ${WARNING_MODE}")
message(STATUS "BUILD_TESTS    : ${BUILD_TESTS}")
message(STATUS "OPT_FLAGS      : ${OPT_FLAGS}")
message(STATUS "WARNING_FLAGS  : ${WARNING_FLAGS}")
get_target_property(LTO_ENABLED vglog-filter INTERPROCEDURAL_OPTIMIZATION)
message(STATUS "INTERPROCEDURAL_OPTIMIZATION (LTO) enabled: ${LTO_ENABLED}")
get_target_property(VGLOG_COMPILE_OPTIONS vglog-filter COMPILE_OPTIONS)
message(STATUS "vglog-filter target compile options: ${VGLOG_COMPILE_OPTIONS}")

# Add test target
if (BUILD_TESTS)
    add_custom_target(test
        COMMAND ${CMAKE_BINARY_DIR}/test_basic
        COMMAND ${CMAKE_BINARY_DIR}/test_integration
        COMMAND ${CMAKE_BINARY_DIR}/test_comprehensive
        COMMAND ${CMAKE_BINARY_DIR}/test_edge_cases
        COMMAND ${CMAKE_BINARY_DIR}/test_memory_leaks
        DEPENDS test_basic test_integration test_comprehensive test_edge_cases test_memory_leaks
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
        COMMENT "Running all tests"
    )
endif()
