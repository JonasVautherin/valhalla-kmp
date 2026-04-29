cmake_minimum_required(VERSION 3.10.2)

project(external-valhalla)
include(ExternalProject)

set(VALHALLA_VERSION "3.7.0" CACHE STRING "Valhalla version to build")

list(APPEND CMAKE_ARGS
    "-DCMAKE_PREFIX_PATH:PATH=${CMAKE_PREFIX_PATH}"
    "-DCMAKE_INSTALL_PREFIX:PATH=${CMAKE_INSTALL_PREFIX}"
    "-DCMAKE_TOOLCHAIN_FILE:PATH=${CMAKE_TOOLCHAIN_FILE}"
    "-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"
    "-DENABLE_TOOLS=OFF"
    "-DENABLE_DATA_TOOLS=OFF"
    "-DENABLE_HTTP=OFF"
    "-DENABLE_PYTHON_BINDINGS=OFF"
    "-DENABLE_SERVICE=OFF"
    "-DENABLE_SERVICES=OFF"
    "-DENABLE_THREAD_SAFE_TILE_REF_COUNT=OFF"
    "-DENABLE_BENCHMARKS=OFF"
    "-DENABLE_TESTS=OFF"
    "-DBUILD_SHARED_LIBS=OFF"
    "-DENABLE_STATIC_LIBRARY_MODULES=ON"
    "-DENABLE_SINGLE_FILES_WERROR=OFF"
    "-DENABLE_ADDRESS_SANITIZER=OFF"
    "-DPREFER_SYSTEM_DEPS=OFF"
    "-DENABLE_GDAL=OFF"
    "-DCMAKE_CXX_FLAGS=-ffunction-sections -fdata-sections"
    "-DCMAKE_C_FLAGS=-ffunction-sections -fdata-sections"
    )

if(IOS)
    list(APPEND CMAKE_ARGS
        "-DPLATFORM=${PLATFORM}"
        "-DDEPLOYMENT_TARGET=${DEPLOYMENT_TARGET}"
        "-DENABLE_STRICT_TRY_COMPILE=${ENABLE_STRICT_TRY_COMPILE}"
        )
endif()

message(STATUS "Preparing external project \"valhalla\" with args:")
foreach(CMAKE_ARG ${CMAKE_ARGS})
    message(STATUS "-- ${CMAKE_ARG}")
endforeach()

ExternalProject_add(
    valhalla
    URL https://github.com/valhalla/valhalla/archive/refs/tags/${VALHALLA_VERSION}.tar.gz
    PREFIX valhalla
    CMAKE_ARGS "${CMAKE_ARGS}"
    DEPENDS protobuf boost lz4
    )
