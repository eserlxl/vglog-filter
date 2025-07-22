# Copyright (C) 2025 Eser KUBALI <lxldev.contact@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This file is part of vglog-filter and is licensed under
# the GNU General Public License v3.0 or later.
# See the LICENSE file in the project root for details.
cmake_minimum_required(VERSION 3.10)
project(vglog-filter LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})

option(DEBUG_MODE        "Enable debug build flags"         OFF)
option(PERFORMANCE_BUILD "Enable performance-optimised flags" ON)
option(WARNING_MODE      "Enable extra warnings"             ON)

if (DEBUG_MODE AND PERFORMANCE_BUILD)
    message(FATAL_ERROR "DEBUG_MODE and PERFORMANCE_BUILD cannot both be ON.")
endif()

add_executable(vglog-filter src/vglog-filter.cpp)

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
message(STATUS "OPT_FLAGS      : ${OPT_FLAGS}")
message(STATUS "WARNING_FLAGS  : ${WARNING_FLAGS}")
get_target_property(LTO_ENABLED vglog-filter INTERPROCEDURAL_OPTIMIZATION)
message(STATUS "INTERPROCEDURAL_OPTIMIZATION (LTO) enabled: ${LTO_ENABLED}")
get_target_property(VGLOG_COMPILE_OPTIONS vglog-filter COMPILE_OPTIONS)
message(STATUS "vglog-filter target compile options: ${VGLOG_COMPILE_OPTIONS}")
