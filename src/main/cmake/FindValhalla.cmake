# FindValhalla.cmake
# Finds the Valhalla library
#
# This will define:
#   Valhalla_FOUND
#   Valhalla_VERSION
#   valhalla::valhalla  (imported target)

find_path(Valhalla_INCLUDE_DIR
    NAMES valhalla/valhalla.h
    PATH_SUFFIXES include
)

find_library(Valhalla_LIBRARY
    NAMES valhalla
    PATH_SUFFIXES lib
)

# Extract version from valhalla/config.h
if(Valhalla_INCLUDE_DIR AND EXISTS "${Valhalla_INCLUDE_DIR}/valhalla/config.h")
    file(STRINGS "${Valhalla_INCLUDE_DIR}/valhalla/config.h" _valhalla_version_line
        REGEX "^#define VALHALLA_VERSION_STR ")
    string(REGEX REPLACE ".*\"(.*)\".*" "\\1" Valhalla_VERSION "${_valhalla_version_line}")
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(Valhalla
    REQUIRED_VARS Valhalla_LIBRARY Valhalla_INCLUDE_DIR
    VERSION_VAR Valhalla_VERSION
)

if(Valhalla_FOUND AND NOT TARGET valhalla::valhalla)
    # Pull in actual dependencies via find_package (they all have cmake modules)
    find_package(Protobuf REQUIRED)
    find_package(ZLIB REQUIRED)
    find_package(Boost REQUIRED)

    add_library(valhalla::valhalla STATIC IMPORTED)
    set_target_properties(valhalla::valhalla PROPERTIES
        IMPORTED_LOCATION "${Valhalla_LIBRARY}"
        INTERFACE_INCLUDE_DIRECTORIES "${Valhalla_INCLUDE_DIR};${Valhalla_INCLUDE_DIR}/valhalla/third_party"
        INTERFACE_INCLUDE_DIRECTORIES "${Valhalla_INCLUDE_DIR};${Valhalla_INCLUDE_DIR}/valhalla;${Valhalla_INCLUDE_DIR}/valhalla/third_party"
        INTERFACE_LINK_LIBRARIES "protobuf::libprotobuf-lite;ZLIB::ZLIB;Boost::boost"
    )
endif()

mark_as_advanced(Valhalla_INCLUDE_DIR Valhalla_LIBRARY)
