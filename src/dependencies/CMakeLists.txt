cmake_minimum_required(VERSION 3.10.2)

project(dependencies)

add_subdirectory(zlib)
add_subdirectory(openssl)
add_subdirectory(cares)
add_subdirectory(absl)
add_subdirectory(protobuf)
add_subdirectory(lz4)
add_subdirectory(boost)
add_subdirectory(valhalla)
