cmake_minimum_required(VERSION 3.10.2)

project(host-dependencies)

# Produce a fully static protoc binary (musl on Alpine) so it can run
# inside glibc-based dockcross containers without any runtime deps.
set(CMAKE_EXE_LINKER_FLAGS "-static" CACHE STRING "")

# Build only what is needed to produce a host-native protoc.
# The subdirectory CMakeLists are shared with the cross-compile build.
add_subdirectory(../dependencies/zlib zlib)
add_subdirectory(../dependencies/openssl openssl)
add_subdirectory(../dependencies/cares cares)
add_subdirectory(../dependencies/absl absl)
add_subdirectory(../dependencies/protobuf protobuf)
