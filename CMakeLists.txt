cmake_minimum_required(VERSION 3.10)
project(vglog-filter LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})

option(DEBUG_MODE "Enable debug build flags" OFF)
option(PERFORMANCE_BUILD "Enable performance-optimized build flags" OFF)
option(WARNING_MODE "Enable extra warnings" OFF)

if(DEBUG_MODE AND PERFORMANCE_BUILD)
    message(FATAL_ERROR "DEBUG_MODE and PERFORMANCE_BUILD cannot both be ON.")
endif()

add_executable(vglog-filter src/vglog-filter.cpp)

# Optimization flags
set(OPT_FLAGS
    $<$<BOOL:DEBUG_MODE>:-g -O0>
    $<$<AND:$<NOT:$<BOOL:DEBUG_MODE>>,$<BOOL:PERFORMANCE_BUILD>>:-O3 -march=native -mtune=native -flto>
    $<$<AND:$<NOT:$<BOOL:DEBUG_MODE>>,$<NOT:$<BOOL:PERFORMANCE_BUILD>>>:-O2>
)

# Link flags
set(LINK_FLAGS
    $<$<AND:$<NOT:$<BOOL:DEBUG_MODE>>,$<BOOL:PERFORMANCE_BUILD>>:-flto>
)

# Warning flags
set(WARNING_FLAGS -Wall -pedantic)
if(WARNING_MODE)
    list(APPEND WARNING_FLAGS -Wextra)
endif()

target_compile_options(vglog-filter PRIVATE ${OPT_FLAGS} ${WARNING_FLAGS})
target_link_options(vglog-filter PRIVATE ${LINK_FLAGS})

target_compile_definitions(vglog-filter PRIVATE
    $<$<BOOL:PERFORMANCE_BUILD>:NDEBUG>
    $<$<BOOL:DEBUG_MODE>:DEBUG>
)
