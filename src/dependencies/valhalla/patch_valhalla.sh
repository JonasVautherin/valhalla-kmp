#!/bin/sh
set -e
sed -i 's/find_package(Protobuf REQUIRED)/find_package(Protobuf REQUIRED)\nset_target_properties(protobuf::protoc PROPERTIES IMPORTED_LOCATION "${Protobuf_PROTOC_EXECUTABLE}")/' "$1/CMakeLists.txt"
