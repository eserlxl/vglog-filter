# Copyright © 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.

cmake_minimum_required(VERSION 3.16)

# Read version from file before project declaration
file(READ "${CMAKE_SOURCE_DIR}/VERSION" VGLOG_FILTER_VERSION_STRING)
string(STRIP "${VGLOG_FILTER_VERSION_STRING}" VGLOG_FILTER_VERSION_STRING)

# ---- Project -----------------------------------------------------------------
project(vglog-filter VERSION ${VGLOG_FILTER_VERSION_STRING}
  DESCRIPTION "A minimal, fast log filter"
  LANGUAGES CXX)

# BUILD-001-A1: Add out-of-source build support
# Prevent accidental in-source builds which can pollute the source directory
option(BUILD_OUT_OF_SOURCE "Require out-of-source builds (recommended)" ON)

if (BUILD_OUT_OF_SOURCE)
    # Check if build directory is the same as source directory
    get_filename_component(CMAKE_SOURCE_DIR_ABS "${CMAKE_SOURCE_DIR}" ABSOLUTE)
    get_filename_component(CMAKE_BINARY_DIR_ABS "${CMAKE_BINARY_DIR}" ABSOLUTE)

    if (CMAKE_SOURCE_DIR_ABS STREQUAL CMAKE_BINARY_DIR_ABS)
        message(FATAL_ERROR
                "In-source builds are not allowed when BUILD_OUT_OF_SOURCE is ON.\n"
                "Please create a separate build directory and run cmake from there.\n"
                "Example:\n"
                "  mkdir build\n"
                "  cd build\n"
                "  cmake ..\n"
                "\n"
                "To disable this check, set BUILD_OUT_OF_SOURCE to OFF:\n"
                "  cmake -DBUILD_OUT_OF_SOURCE=OFF .\n"
                "\n"
                "However, out-of-source builds are strongly recommended for safety.")
    endif ()
endif ()

# C++ standard (no compiler extensions)
set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Enable compile commands export for IDE integration
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# RPATH settings
set(CMAKE_BUILD_WITH_INSTALL_RPATH TRUE)
set(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)
# Use RUNPATH instead of RPATH for better compatibility
set(CMAKE_BUILD_RPATH_USE_ORIGIN TRUE)
# Set to use RUNPATH (more modern, allows LD_LIBRARY_PATH to override)
if (NOT MSVC)
    set(CMAKE_SHARED_LIBRARY_RUNTIME_C_FLAG "-Wl,-rpath,")
    set(CMAKE_SHARED_LIBRARY_RUNTIME_CXX_FLAG "-Wl,-rpath,")
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -Wl,--enable-new-dtags")
endif ()

# Set build type if not specified (with cache and property)
if (NOT CMAKE_CONFIGURATION_TYPES AND NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "Release" CACHE STRING "Build type")
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug" "Release" "RelWithDebInfo" "MinSizeRel")
endif ()

# Set verbose makefile
set(CMAKE_VERBOSE_MAKEFILE ON)

# ---- Tooling (ccache / sccache) --------------------------------------------
if (NOT CMAKE_CXX_COMPILER_LAUNCHER)
    find_program(CCACHE_PROGRAM ccache)
    if (CCACHE_PROGRAM)
        message(STATUS "Using ccache: ${CCACHE_PROGRAM}")
        set(CMAKE_CXX_COMPILER_LAUNCHER ${CCACHE_PROGRAM})
    else ()
        find_program(SCCACHE_PROGRAM sccache)
        if (SCCACHE_PROGRAM)
            message(STATUS "Using sccache: ${SCCACHE_PROGRAM}")
            set(CMAKE_CXX_COMPILER_LAUNCHER ${SCCACHE_PROGRAM})
        endif ()
    endif ()
endif ()

# Put built binaries under <build>/bin (and per-config subdirs for multi-config generators)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
foreach(cfg IN ITEMS Debug Release RelWithDebInfo MinSizeRel)
  string(TOUPPER "${cfg}" CFG_UP)
  set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_${CFG_UP} "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/${cfg}")
endforeach()

# ---- Options -----------------------------------------------------------------
option(DEBUG_MODE                 "Enable debug build flags"                         OFF)
option(PERFORMANCE_BUILD          "Enable performance-optimized flags"               ON)
option(WARNING_MODE               "Enable extra warnings"                            ON)
option(BUILD_TESTING              "Build tests and enable CTest"                     ON)  # Standard CMake option name
option(ENABLE_NATIVE_OPTIMIZATION "Use -march=native/-mtune=native in performance"   OFF)
option(ENABLE_SANITIZERS          "Enable Address/Undefined sanitizers in debug"     OFF)

# Backward compatibility with a previous non-standard option name
if(DEFINED BUILD_TESTS AND NOT DEFINED BUILD_TESTING)
  set(BUILD_TESTING "${BUILD_TESTS}")
endif()

# Mutually exclusive modes sanity check
if(DEBUG_MODE AND PERFORMANCE_BUILD)
  message(FATAL_ERROR "DEBUG_MODE and PERFORMANCE_BUILD cannot both be ON.")
endif()

# ---- Helper interface targets ------------------------------------------------
# project_options: optimization/sanitizer/defines that apply to all targets
add_library(project_options INTERFACE)
target_include_directories(project_options INTERFACE
    $<BUILD_INTERFACE:${CMAKE_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)
target_compile_definitions(project_options INTERFACE
    VGLOG_FILTER_VERSION="${VGLOG_FILTER_VERSION_STRING}"
)

# project_warnings: warning levels per compiler
add_library(project_warnings INTERFACE)

# Detect compiler family
if (MSVC)
  # /O flags handled via mode below; keep warnings modern
  target_compile_options(project_warnings INTERFACE
    /W4
    /permissive-)
else()
  # Reasonably strict but practical defaults
  target_compile_options(project_warnings INTERFACE
    -Wall
    -Wextra
    -Wpedantic
    -Wconversion
    -Wshadow
    -Wnon-virtual-dtor
    -Wold-style-cast
    -Woverloaded-virtual
    -Wnull-dereference
    -Wformat=2
    -Wimplicit-fallthrough)
endif()

# Optimization / Debug / Sanitizer flags
if (MSVC)
  if (DEBUG_MODE)
    target_compile_options(project_options INTERFACE /Od /Z7)
    target_compile_definitions(project_options INTERFACE DEBUG)
  elseif (PERFORMANCE_BUILD)
    target_compile_options(project_options INTERFACE /O2)
    target_compile_definitions(project_options INTERFACE NDEBUG)
  else()
    target_compile_options(project_options INTERFACE /O2 /Z7)
  endif()
else()
  if (DEBUG_MODE)
    target_compile_options(project_options INTERFACE -O0 -g -fno-omit-frame-pointer)
    target_compile_definitions(project_options INTERFACE DEBUG)
    if (ENABLE_SANITIZERS)
      target_compile_options(project_options INTERFACE -fsanitize=address,undefined)
      target_link_options(project_options INTERFACE -fsanitize=address,undefined)
    endif()
  elseif (PERFORMANCE_BUILD)
    target_compile_options(project_options INTERFACE -O3)
    if (ENABLE_NATIVE_OPTIMIZATION)
      target_compile_options(project_options INTERFACE -march=native -mtune=native)
    endif()
    target_compile_definitions(project_options INTERFACE NDEBUG _FORTIFY_SOURCE=2)
  else()
    # Reasonable default when neither mode is explicitly chosen
    target_compile_options(project_options INTERFACE -O2 -g)
    target_compile_definitions(project_options INTERFACE _FORTIFY_SOURCE=2)
  endif()
endif()

# ---- Library ---------------------------------------------------------------
add_library(vglog-filter-lib
  src/options.cpp
  src/file_utils.cpp
  src/json_utils.cpp
  src/log_processor.cpp
  src/log_filter.cpp
  src/path_validation.cpp
  src/canonicalization.cpp
  src/log_parser.cpp
  src/log_writer.cpp
  src/options_builder.cpp
  src/cli_parser.cpp
)
target_link_libraries(vglog-filter-lib PUBLIC project_options project_warnings)
target_compile_features(vglog-filter-lib PUBLIC cxx_std_23)

# Apply additional compiler flags for security and code quality
if (NOT MSVC)
    target_compile_options(vglog-filter-lib PRIVATE
            $<$<COMPILE_LANGUAGE:CXX>:-fstack-protector-strong>
            $<$<AND:$<COMPILE_LANG_AND_ID:CXX,GNU>,$<NOT:$<PLATFORM_ID:Darwin>>>:-Wformat=2>
            $<$<AND:$<COMPILE_LANG_AND_ID:CXX,Clang>,$<NOT:$<PLATFORM_ID:Darwin>>>:-Wformat=2>
    )

    # Platform-specific linker options for security hardening (Linux only)
    if (CMAKE_SYSTEM_NAME STREQUAL "Linux")
        include(CheckLinkerFlag)
        check_linker_flag(CXX "-Wl,-z,relro,-z,now" LINKER_SUPPORTS_RELRO)
        if (LINKER_SUPPORTS_RELRO)
            target_link_options(vglog-filter-lib PRIVATE -Wl,-z,relro,-z,now)
        endif ()

        # Link only needed libraries
        check_linker_flag(CXX "-Wl,--as-needed" LINKER_SUPPORTS_AS_NEEDED)
        if (LINKER_SUPPORTS_AS_NEEDED)
            target_link_options(vglog-filter-lib PRIVATE -Wl,--as-needed)
        endif ()
    endif ()
endif ()

# ---- Main executable ---------------------------------------------------------
add_executable(vglog-filter src/main.cpp)
target_link_libraries(vglog-filter PRIVATE vglog-filter-lib)

# Apply security hardening to executable as well
if (NOT MSVC)
    target_compile_options(vglog-filter PRIVATE
            $<$<COMPILE_LANGUAGE:CXX>:-fstack-protector-strong>
            $<$<AND:$<COMPILE_LANG_AND_ID:CXX,GNU>,$<NOT:$<PLATFORM_ID:Darwin>>>:-Wformat=2>
            $<$<AND:$<COMPILE_LANG_AND_ID:CXX,Clang>,$<NOT:$<PLATFORM_ID:Darwin>>>:-Wformat=2>
    )

    # Platform-specific linker options for security hardening (Linux only)
    if (CMAKE_SYSTEM_NAME STREQUAL "Linux")
        include(CheckLinkerFlag)
        check_linker_flag(CXX "-Wl,-z,relro,-z,now" LINKER_SUPPORTS_RELRO)
        if (LINKER_SUPPORTS_RELRO)
            target_link_options(vglog-filter PRIVATE -Wl,-z,relro,-z,now)
        endif ()

        # Link only needed libraries
        check_linker_flag(CXX "-Wl,--as-needed" LINKER_SUPPORTS_AS_NEEDED)
        if (LINKER_SUPPORTS_AS_NEEDED)
            target_link_options(vglog-filter PRIVATE -Wl,--as-needed)
        endif ()
    endif ()
endif ()

# ---- IPO/LTO (only when meaningful) -----------------------------------------
include(CheckIPOSupported)
set(_ipo_allowed OFF)
check_ipo_supported(RESULT _ipo_allowed OUTPUT _ipo_msg)
if (FALSE) # IPO Disabled
  # set_property(TARGET vglog-filter PROPERTY INTERPROCEDURAL_OPTIMIZATION TRUE)
  # set_property(TARGET vglog-filter-lib PROPERTY INTERPROCEDURAL_OPTIMIZATION TRUE)
  message(STATUS "IPO/LTO disabled by policy for stability")
else()
  message(STATUS "IPO/LTO not enabled: ${_ipo_msg}")
endif()

# ---- Tests (CTest) -----------------------------------------------------------
if (BUILD_TESTING)
  include(CTest)
  enable_testing()

  # Helper to add a test if its source exists
  function(add_test_exe name srcpath)
    if (EXISTS "${CMAKE_SOURCE_DIR}/${srcpath}")
      add_executable(${name} "${srcpath}")
      target_link_libraries(${name} PRIVATE vglog-filter-lib)
      add_test(NAME ${name} COMMAND ${name})
      message(STATUS "Test target '${name}' added (${srcpath})")
    else()
      message(STATUS "Skipping test '${name}': source not found at ${srcpath}")
    endif()
  endfunction()



  add_test_exe(test_canonicalization  "test/test_canonicalization.cpp")
  add_test_exe(test_basic           "test/test_basic.cpp")
  add_test_exe(test_integration     "test/test_integration.cpp")
  add_test_exe(test_comprehensive   "test/test_comprehensive.cpp")
  add_test_exe(test_edge_cases      "test/test_edge_cases.cpp")
  add_test_exe(test_memory_leaks    "test/test_memory_leaks.cpp")
  add_test_exe(test_path_validation "test/test_path_validation.cpp")
  add_test_exe(test_regex_patterns  "test/test_regex_patterns.cpp")
  add_test_exe(test_cli_options     "test/test_cli_options.cpp")
  add_test_exe(test_edge_utf8_perm  "test/test_edge_utf8_perm.cpp")
  add_test_exe(test_structured_filter "test/test_structured_filter.cpp")
  add_test_exe(test_rotation_strict   "test/test_rotation_strict.cpp")
  add_test_exe(test_log_parser        "test/test_log_parser.cpp")
  add_test_exe(test_log_writer        "test/test_log_writer.cpp")
  add_test_exe(test_new_features_iter1 "test/test_new_features_iter1.cpp")
  add_test_exe(test_cli_invocations   "test/test_cli_invocations.cpp")
  add_test_exe(test_features_iter2    "test/test_features_iter2.cpp")
  add_test_exe(test_features_iter3    "test/test_features_iter3.cpp")
  add_test_exe(test_json_modes        "test/test_json_modes.cpp")
  add_test_exe(test_options_builder   "test/test_options_builder.cpp")

  # Convenience target to run tests with nice output
  add_custom_target(run-tests
    COMMAND "${CMAKE_CTEST_COMMAND}" --output-on-failure
    WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
    COMMENT "Running all tests via CTest")
endif()

# ---- Clean Targets -----------------------------------------------------------
# Clean build artifacts only (keeps CMake cache)
if (CMAKE_GENERATOR MATCHES "Makefiles|Ninja")
    add_custom_target(clean-build
            COMMAND ${CMAKE_COMMAND} --build "${CMAKE_BINARY_DIR}" --target clean
            COMMENT "Clean build artifacts (keeps CMake cache)"
            VERBATIM
    )
else ()
    add_custom_target(clean-build
            COMMAND ${CMAKE_COMMAND} -E echo "Note: clean-build for ${CMAKE_GENERATOR} removes all files"
            COMMAND ${CMAKE_COMMAND} -E remove_directory "${CMAKE_BINARY_DIR}/CMakeFiles"
            COMMAND ${CMAKE_COMMAND} -E remove "${CMAKE_BINARY_DIR}/CMakeCache.txt"
            COMMAND ${CMAKE_COMMAND} -E remove "${CMAKE_BINARY_DIR}/cmake_install.cmake"
            COMMENT "Clean build artifacts (keeps CMake cache)"
            VERBATIM
    )
endif ()

# clean-all: Remove ALL files and directories in the build directory
# Note: After running clean-all, CLion users must reload/reconfigure CMake
# (File -> Reload CMake Project or Tools -> CMake -> Reset Cache and Reload Project)
if (UNIX)
    add_custom_target(clean-all
            COMMAND find "${CMAKE_BINARY_DIR}/CMakeFiles" -name "*.dd" -type f -delete 2>/dev/null || true
            COMMAND find "${CMAKE_BINARY_DIR}/CMakeFiles" -type d -name "*.dir" -exec rm -rf {} + 2>/dev/null || true
            COMMAND ${CMAKE_COMMAND} -E remove_directory "${CMAKE_BINARY_DIR}/CMakeFiles"
            COMMAND ${CMAKE_COMMAND} -E remove "${CMAKE_BINARY_DIR}/CMakeCache.txt"
            COMMAND ${CMAKE_COMMAND} -E remove "${CMAKE_BINARY_DIR}/cmake_install.cmake"
            COMMAND ${CMAKE_COMMAND} -E remove "${CMAKE_BINARY_DIR}/compile_commands.json"
            COMMAND ${CMAKE_COMMAND} -E remove "${CMAKE_BINARY_DIR}/Makefile"
            COMMAND ${CMAKE_COMMAND} -E remove "${CMAKE_BINARY_DIR}/build.ninja"
            COMMAND ${CMAKE_COMMAND} -E remove "${CMAKE_BINARY_DIR}/rules.ninja"
            COMMAND ${CMAKE_COMMAND} -E remove "${CMAKE_BINARY_DIR}/.ninja_deps"
            COMMAND ${CMAKE_COMMAND} -E remove "${CMAKE_BINARY_DIR}/.ninja_log"
            COMMAND find "${CMAKE_BINARY_DIR}" -maxdepth 1 -name "*.a" -type f -delete 2>/dev/null || true
            COMMAND find "${CMAKE_BINARY_DIR}" -maxdepth 1 -name "*.so" -type f -delete 2>/dev/null || true
            COMMAND ${CMAKE_COMMAND} -E echo ""
            COMMAND ${CMAKE_COMMAND} -E echo "=========================================="
            COMMAND ${CMAKE_COMMAND} -E echo "Cleaned all CMake-generated files, cache, and build artifacts"
            COMMAND ${CMAKE_COMMAND} -E echo ""
            COMMAND ${CMAKE_COMMAND} -E echo "NOTE: If using CLion IDE, you must now:"
            COMMAND ${CMAKE_COMMAND} -E echo "  1. Reload CMake Project (File -> Reload CMake Project)"
            COMMAND ${CMAKE_COMMAND} -E echo "  OR"
            COMMAND ${CMAKE_COMMAND} -E echo "  2. Reset CMake Cache (Tools -> CMake -> Reset Cache and Reload Project)"
            COMMAND ${CMAKE_COMMAND} -E echo ""
            COMMAND ${CMAKE_COMMAND} -E echo "This is required because CMakeCache.txt was removed."
            COMMAND ${CMAKE_COMMAND} -E echo "=========================================="
            COMMENT "Clean all CMake-generated files, cache, and build artifacts (full clean)"
            VERBATIM
    )
else ()
    add_custom_target(clean-all
            COMMAND ${CMAKE_COMMAND} -E remove_directory "${CMAKE_BINARY_DIR}/CMakeFiles"
            COMMAND ${CMAKE_COMMAND} -E remove "${CMAKE_BINARY_DIR}/CMakeCache.txt"
            COMMAND ${CMAKE_COMMAND} -E remove "${CMAKE_BINARY_DIR}/cmake_install.cmake"
            COMMAND ${CMAKE_COMMAND} -E remove "${CMAKE_BINARY_DIR}/compile_commands.json"
            COMMAND ${CMAKE_COMMAND} -E echo ""
            COMMAND ${CMAKE_COMMAND} -E echo "=========================================="
            COMMAND ${CMAKE_COMMAND} -E echo "Cleaned CMake cache and generated files"
            COMMAND ${CMAKE_COMMAND} -E echo ""
            COMMAND ${CMAKE_COMMAND} -E echo "NOTE: If using CLion IDE, you must now:"
            COMMAND ${CMAKE_COMMAND} -E echo "  1. Reload CMake Project (File -> Reload CMake Project)"
            COMMAND ${CMAKE_COMMAND} -E echo "  OR"
            COMMAND ${CMAKE_COMMAND} -E echo "  2. Reset CMake Cache (Tools -> CMake -> Reset Cache and Reload Project)"
            COMMAND ${CMAKE_COMMAND} -E echo ""
            COMMAND ${CMAKE_COMMAND} -E echo "This is required because CMakeCache.txt was removed."
            COMMAND ${CMAKE_COMMAND} -E echo "=========================================="
            COMMENT "Clean all CMake-generated files and cache (full clean)"
            VERBATIM
    )
endif ()

message(STATUS "Clean targets available:")
message(STATUS "  - clean-build: Clean build artifacts only (keeps CMake cache)")
message(STATUS "  - clean-all: Remove all CMake-generated files, cache, and build artifacts")
message(STATUS "    Note: After 'clean-all', CLion users must reload CMake project")
message(STATUS "  Usage: cmake --build . --target <target-name>")

# ---- Summary -----------------------------------------------------------------
message(STATUS "========== Build Configuration ==========")
message(STATUS "CMAKE_CXX_COMPILER       : ${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION}")
message(STATUS "CMAKE_BUILD_TYPE         : ${CMAKE_BUILD_TYPE}")
message(STATUS "DEBUG_MODE               : ${DEBUG_MODE}")
message(STATUS "PERFORMANCE_BUILD        : ${PERFORMANCE_BUILD}")
message(STATUS "WARNING_MODE             : ${WARNING_MODE}")
message(STATUS "BUILD_TESTING            : ${BUILD_TESTING}")
message(STATUS "ENABLE_NATIVE_OPTIMIZATION: ${ENABLE_NATIVE_OPTIMIZATION}")
message(STATUS "ENABLE_SANITIZERS        : ${ENABLE_SANITIZERS}")
get_target_property(_ipo vglog-filter INTERPROCEDURAL_OPTIMIZATION)
message(STATUS "IPO/LTO (vglog-filter)   : ${_ipo}")
message(STATUS "Runtime output directory : ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}")
message(STATUS "========================================")
