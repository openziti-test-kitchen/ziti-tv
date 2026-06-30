cmake_minimum_required(VERSION 3.22)
project(zo-sdk-c-interop C)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

# Embed the runtime library path so the shared libziti.so is found after install
set(CMAKE_INSTALL_RPATH "/usr/local/lib")
set(CMAKE_BUILD_WITH_INSTALL_RPATH TRUE)

# ---------------------------------------------------------------------------
# ziti-sdk-c dependency
#
# Strategy A (default): download the prebuilt Linux-x86_64 zip from the
# official GitHub release and unpack it.  The zip ships:
#   include/ziti/...   - public headers
#   lib/libziti.a      - static library
#   lib/libtlsuv.a     - bundled transport dependency
#
# If ZITI_SDK_ROOT is set by the caller, skip the download and use that
# prefix directly (useful for CI caches or cross-compilation).
# ---------------------------------------------------------------------------

set(ZITI_SDK_VERSION "1.17.1" CACHE STRING "ziti-sdk-c release tag to download")
set(ZITI_SDK_ZIP_URL
    "https://github.com/openziti/ziti-sdk-c/releases/download/${ZITI_SDK_VERSION}/ziti-sdk-Linux-x86_64.zip"
)

if(NOT DEFINED ZITI_SDK_ROOT OR ZITI_SDK_ROOT STREQUAL "")
    include(FetchContent)
    FetchContent_Declare(
        ziti_sdk_prebuilt
        URL      ${ZITI_SDK_ZIP_URL}
        # No FIND_PACKAGE_ARGS: we wire it manually below.
    )
    FetchContent_MakeAvailable(ziti_sdk_prebuilt)
    set(ZITI_SDK_ROOT "${ziti_sdk_prebuilt_SOURCE_DIR}")
    message(STATUS "ziti-sdk-c prebuilt unpacked to: ${ZITI_SDK_ROOT}")
else()
    message(STATUS "Using caller-supplied ZITI_SDK_ROOT: ${ZITI_SDK_ROOT}")
endif()

# Locate headers and static library inside the unpacked/supplied tree.
# The zip layout observed for 1.17.1 is:
#   <root>/include/ziti/ziti.h
#   <root>/lib/libziti.a  (or libziti.so on some builds)
find_path(ZITI_INCLUDE_DIR
    NAMES ziti/ziti.h
    PATHS "${ZITI_SDK_ROOT}/include"
    NO_DEFAULT_PATH
    REQUIRED
)
find_library(ZITI_LIBRARY
    NAMES ziti
    PATHS "${ZITI_SDK_ROOT}/lib"
    NO_DEFAULT_PATH
    REQUIRED
)

message(STATUS "ziti headers: ${ZITI_INCLUDE_DIR}")
message(STATUS "ziti library: ${ZITI_LIBRARY}")

# libuv: use pkg-config (libuv1-dev on Ubuntu) or plain find_library on default paths
find_package(PkgConfig QUIET)
if(PkgConfig_FOUND)
    pkg_check_modules(UV QUIET libuv)
endif()
if(NOT UV_FOUND)
    find_library(UV_LIBRARY NAMES uv)
    find_path(UV_INCLUDE_DIR NAMES uv.h)
    if(UV_LIBRARY)
        set(UV_FOUND TRUE)
        set(UV_LIBRARIES ${UV_LIBRARY})
        set(UV_INCLUDE_DIRS ${UV_INCLUDE_DIR})
    endif()
endif()

# Build all four binaries.
foreach(TARGET echo_server echo_client http_server http_client)
    add_executable(${TARGET} ${TARGET}.c)
    target_include_directories(${TARGET} PRIVATE ${ZITI_INCLUDE_DIR})
    if(UV_FOUND)
        target_include_directories(${TARGET} PRIVATE ${UV_INCLUDE_DIRS})
        target_link_libraries(${TARGET} PRIVATE ${UV_LIBRARIES})
        target_link_directories(${TARGET} PRIVATE ${UV_LIBRARY_DIRS})
    endif()
    target_link_libraries(${TARGET} PRIVATE ${ZITI_LIBRARY})
    # json-c is a direct header dependency of the prebuilt SDK (model_support.h)
    find_library(JSONC_LIBRARY NAMES json-c)
    if(JSONC_LIBRARY)
        target_link_libraries(${TARGET} PRIVATE ${JSONC_LIBRARY})
    endif()
    # ziti shared lib and system pulls on Linux
    target_link_libraries(${TARGET} PRIVATE pthread m dl)
endforeach()
