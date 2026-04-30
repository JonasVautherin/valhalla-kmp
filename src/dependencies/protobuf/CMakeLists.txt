cmake_minimum_required(VERSION 3.10.2)

project(external-protobuf)
include(ExternalProject)


list(APPEND CMAKE_ARGS
    "-DCMAKE_PREFIX_PATH:PATH=${CMAKE_PREFIX_PATH}"
    "-DCMAKE_INSTALL_PREFIX:PATH=${CMAKE_INSTALL_PREFIX}"
    "-DCMAKE_TOOLCHAIN_FILE:PATH=${CMAKE_TOOLCHAIN_FILE}"
    "-DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"
    "-Dprotobuf_BUILD_TESTS=OFF"
    "-Dprotobuf_BUILD_SHARED_LIBS=OFF"
    "-Dprotobuf_MODULE_COMPATIBLE=ON"
    "-Dprotobuf_MSVC_STATIC_RUNTIME=OFF"
    "-DCMAKE_POSITION_INDEPENDENT_CODE=ON"
    "-Dprotobuf_ABSL_PROVIDER=package"
    "-DCMAKE_CXX_STANDARD=17"
    )

if(CMAKE_CROSSCOMPILING)
    list(APPEND CMAKE_ARGS
        "-Dprotobuf_BUILD_PROTOC_BINARIES=OFF"
        )
endif()

if(CMAKE_EXE_LINKER_FLAGS)
    list(APPEND CMAKE_ARGS
        "-DCMAKE_EXE_LINKER_FLAGS=${CMAKE_EXE_LINKER_FLAGS}"
        )
endif()

if(IOS)
    list(APPEND CMAKE_ARGS
        "-DPLATFORM=${PLATFORM}"
        "-DDEPLOYMENT_TARGET=${DEPLOYMENT_TARGET}"
        "-DENABLE_STRICT_TRY_COMPILE=${ENABLE_STRICT_TRY_COMPILE}"
        )
endif()

message(STATUS "Preparing external project \"protobuf\" with args:")
foreach(CMAKE_ARG ${CMAKE_ARGS})
    message(STATUS "-- ${CMAKE_ARG}")
endforeach()

ExternalProject_add(
    protobuf
    URL https://github.com/protocolbuffers/protobuf/archive/refs/tags/v34.1.tar.gz
    PREFIX protobuf
    CMAKE_ARGS "${CMAKE_ARGS}"
    DEPENDS absl cares openssl zlib
    )
