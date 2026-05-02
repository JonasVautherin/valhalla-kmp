cmake_minimum_required(VERSION 3.10.2)

project(external-lz4)
include(ExternalProject)

ExternalProject_add(
    lz4
    URL https://github.com/lz4/lz4/archive/refs/tags/v1.9.4.tar.gz
    PREFIX lz4
    CONFIGURE_COMMAND ""
    BUILD_COMMAND make -C <SOURCE_DIR> BUILD_SHARED=no
    INSTALL_COMMAND make -C <SOURCE_DIR> install PREFIX=${CMAKE_INSTALL_PREFIX} BUILD_SHARED=no
    )
