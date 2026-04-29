set(FILE "${SOURCE_DIR}/CMakeLists.txt")
file(READ "${FILE}" CONTENT)
string(REPLACE
    "find_package(Protobuf REQUIRED)"
    "find_package(Protobuf REQUIRED)\nif(Protobuf_PROTOC_EXECUTABLE AND NOT TARGET protobuf::protoc)\n  add_executable(protobuf::protoc IMPORTED)\n  set_target_properties(protobuf::protoc PROPERTIES IMPORTED_LOCATION \"\${Protobuf_PROTOC_EXECUTABLE}\")\nendif()"
    CONTENT "${CONTENT}"
)
file(WRITE "${FILE}" "${CONTENT}")
