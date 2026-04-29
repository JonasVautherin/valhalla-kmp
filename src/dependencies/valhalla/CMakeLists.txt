cmake_minimum_required(VERSION 3.10.2)

project(external-valhalla)
include(ExternalProject)

set(VALHALLA_VERSION "3.7.0" CACHE STRING "Valhalla version to build")

list(APPEND CMAKE_ARGS
    "-DCMAKE_PREFIX_PATH:PATH=${CMAKE_PREFIX_PATH}"
    "-DCMAKE_INSTALL_PREFIX:PATH=${CMAKE_INSTALL_PREFIX}"
    "-DCMAKE_TOOLCHAIN_FILE:PATH=${CMAKE_TOOLCHAIN_FILE}"
    "-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"
    "-DCMAKE_POSITION_INDEPENDENT_CODE=ON"
    "-DENABLE_TOOLS=OFF"
    "-DENABLE_DATA_TOOLS=OFF"
    "-DENABLE_HTTP=OFF"
    "-DENABLE_PYTHON_BINDINGS=OFF"
    "-DENABLE_SERVICES=OFF"
    "-DENABLE_THREAD_SAFE_TILE_REF_COUNT=OFF"
    "-DENABLE_TESTS=OFF"
    "-DBUILD_SHARED_LIBS=OFF"
    "-DENABLE_STATIC_LIBRARY_MODULES=ON"
    "-DENABLE_SINGLE_FILES_WERROR=OFF"
    "-DENABLE_ADDRESS_SANITIZER=OFF"
    "-DENABLE_GDAL=OFF"
    "-DCMAKE_CXX_FLAGS=-ffunction-sections -fdata-sections"
    "-DCMAKE_C_FLAGS=-ffunction-sections -fdata-sections"
    "-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER"
    )

if(HOST_PROTOC_EXECUTABLE)
    list(APPEND CMAKE_ARGS
        "-DProtobuf_PROTOC_EXECUTABLE=${HOST_PROTOC_EXECUTABLE}"
        )
endif()

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
    GIT_REPOSITORY https://github.com/valhalla/valhalla.git
    GIT_TAG ${VALHALLA_VERSION}
    GIT_SUBMODULES_RECURSE ON
    PREFIX valhalla
    PATCH_COMMAND ${CMAKE_COMMAND} -DSOURCE_DIR=<SOURCE_DIR> -P ${CMAKE_CURRENT_SOURCE_DIR}/patch_valhalla.cmake
          COMMAND git -C <SOURCE_DIR> apply ${CMAKE_CURRENT_SOURCE_DIR}/valhalla_static_install.patch
    CMAKE_ARGS "${CMAKE_ARGS}"
    DEPENDS protobuf boost lz4
    )
