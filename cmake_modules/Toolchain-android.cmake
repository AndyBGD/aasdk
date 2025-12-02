# Experimental Android toolchain for AASDK
# Usage:
#   cmake -S . -B build-android -G Ninja \
#     -DCMAKE_TOOLCHAIN_FILE=cmake_modules/Toolchain-android.cmake \
#     -DCMAKE_ANDROID_ARCH_ABI=arm64-v8a \
#     -DCMAKE_SYSTEM_VERSION=24

if(NOT DEFINED ENV{ANDROID_NDK} AND NOT DEFINED ENV{ANDROID_NDK_HOME})
  message(FATAL_ERROR "ANDROID_NDK or ANDROID_NDK_HOME environment variable must be set to the NDK path.")
endif()

# Prefer ANDROID_NDK, fall back to ANDROID_NDK_HOME for compatibility
if(DEFINED ENV{ANDROID_NDK})
  set(_NDK_ROOT "$ENV{ANDROID_NDK}")
else()
  set(_NDK_ROOT "$ENV{ANDROID_NDK_HOME}")
endif()

set(CMAKE_SYSTEM_NAME Android)
# Allow overriding from the command line; default to API 24 to cover Android 7.0+
if(NOT DEFINED CMAKE_SYSTEM_VERSION)
  set(CMAKE_SYSTEM_VERSION 24 CACHE STRING "Android API level")
endif()

# Default ABI: arm64-v8a; override with CMAKE_ANDROID_ARCH_ABI
if(NOT DEFINED CMAKE_ANDROID_ARCH_ABI)
  set(CMAKE_ANDROID_ARCH_ABI arm64-v8a CACHE STRING "Android ABI")
endif()

# Use static STL by default to simplify distribution of native libs
if(NOT DEFINED CMAKE_ANDROID_STL_TYPE)
  set(CMAKE_ANDROID_STL_TYPE c++_static CACHE STRING "Android STL")
endif()

set(CMAKE_ANDROID_NDK "${_NDK_ROOT}" CACHE PATH "Android NDK path")
set(CMAKE_ANDROID_NDK_TOOLCHAIN_VERSION clang)
set(ANDROID_NATIVE_API_LEVEL ${CMAKE_SYSTEM_VERSION})

# Allow CMake to find NDK sysroots/packages
set(CMAKE_FIND_ROOT_PATH "${CMAKE_ANDROID_NDK}/toolchains/llvm/prebuilt" "${CMAKE_ANDROID_NDK}")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

message(STATUS "Configuring for Android ABI: ${CMAKE_ANDROID_ARCH_ABI}, API: ${CMAKE_SYSTEM_VERSION}")
