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

find_library(Valhalla_TYR_LIBRARY     NAMES valhalla-tyr     PATH_SUFFIXES lib)
find_library(Valhalla_BALDR_LIBRARY   NAMES valhalla-baldr   PATH_SUFFIXES lib)
find_library(Valhalla_LOKI_LIBRARY    NAMES valhalla-loki    PATH_SUFFIXES lib)
find_library(Valhalla_THOR_LIBRARY    NAMES valhalla-thor    PATH_SUFFIXES lib)
find_library(Valhalla_ODIN_LIBRARY    NAMES valhalla-odin    PATH_SUFFIXES lib)
find_library(Valhalla_SIF_LIBRARY     NAMES valhalla-sif     PATH_SUFFIXES lib)
find_library(Valhalla_MEILI_LIBRARY   NAMES valhalla-meili   PATH_SUFFIXES lib)
find_library(Valhalla_SKADI_LIBRARY   NAMES valhalla-skadi   PATH_SUFFIXES lib)
find_library(Valhalla_MIDGARD_LIBRARY NAMES valhalla-midgard PATH_SUFFIXES lib)
find_library(Valhalla_PROTO_LIBRARY   NAMES valhalla-proto   PATH_SUFFIXES lib)

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
    find_package(Protobuf REQUIRED CONFIG)
    find_package(ZLIB REQUIRED)
    find_package(Boost REQUIRED CONFIG)
    find_package(absl REQUIRED CONFIG)

    find_package(PkgConfig REQUIRED)
    pkg_check_modules(LZ4 REQUIRED IMPORTED_TARGET liblz4)

    # utf8_range stubs if not shipped with a cmake config
    if(NOT TARGET utf8_range::utf8_validity)
        find_library(UTF8_VALIDITY_LIB NAMES utf8_validity PATHS "${CMAKE_PREFIX_PATH}/lib" NO_DEFAULT_PATH)
        find_library(UTF8_RANGE_LIB    NAMES utf8_range    PATHS "${CMAKE_PREFIX_PATH}/lib" NO_DEFAULT_PATH)
        add_library(utf8_range::utf8_validity STATIC IMPORTED)
        add_library(utf8_range::utf8_range    STATIC IMPORTED)
        set_target_properties(utf8_range::utf8_validity PROPERTIES IMPORTED_LOCATION "${UTF8_VALIDITY_LIB}")
        set_target_properties(utf8_range::utf8_range    PROPERTIES IMPORTED_LOCATION "${UTF8_RANGE_LIB}")
    endif()

    # Collect absl + lz4 static libs for whole-archive absorption
    set(_whole_libs "")

    # absl
    get_cmake_property(_all_targets IMPORTED_TARGETS)
    foreach(_t IN LISTS _all_targets)
        if(_t MATCHES "^absl::")
            get_target_property(_loc ${_t} IMPORTED_LOCATION)
            if(NOT _loc)
                get_target_property(_loc ${_t} IMPORTED_LOCATION_RELEASE)
            endif()
            if(NOT _loc)
                get_target_property(_loc ${_t} IMPORTED_LOCATION_NOCONFIG)
            endif()
            if(_loc AND _loc MATCHES "\\.a$")
                list(APPEND _whole_libs "${_loc}")
            endif()
        endif()
    endforeach()

    # lz4 — pkg_check_modules gives us the path directly
    pkg_get_variable(LZ4_LIBDIR liblz4 libdir)
    find_library(_lz4_loc NAMES lz4 PATHS "${LZ4_LIBDIR}" NO_DEFAULT_PATH)
    if(_lz4_loc AND _lz4_loc MATCHES "\\.a$")
        list(APPEND _whole_libs "${_lz4_loc}")
    endif()

    # Intermediate INTERFACE target that forces whole-archive on absl
    add_library(valhalla_deps_whole INTERFACE)
    set_target_properties(valhalla_deps_whole PROPERTIES
        INTERFACE_LINK_LIBRARIES
            "-Wl,--whole-archive;${_whole_libs};-Wl,--no-whole-archive"
    )

    # Collect component libs
    set(Valhalla_COMPONENT_LIBS "")
    foreach(comp TYR BALDR LOKI THOR ODIN SIF MEILI SKADI MIDGARD PROTO)
        if(Valhalla_${comp}_LIBRARY)
            list(APPEND Valhalla_COMPONENT_LIBS "${Valhalla_${comp}_LIBRARY}")
        endif()
    endforeach()

    add_library(valhalla::valhalla STATIC IMPORTED)
    set_target_properties(valhalla::valhalla PROPERTIES
        IMPORTED_LOCATION "${Valhalla_LIBRARY}"
        INTERFACE_INCLUDE_DIRECTORIES
            "${Valhalla_INCLUDE_DIR};${Valhalla_INCLUDE_DIR}/valhalla;${Valhalla_INCLUDE_DIR}/valhalla/third_party"
        INTERFACE_LINK_LIBRARIES
            "${Valhalla_COMPONENT_LIBS};protobuf::libprotobuf;ZLIB::ZLIB;Boost::boost;valhalla_deps_whole"
    )
endif()

mark_as_advanced(Valhalla_INCLUDE_DIR Valhalla_LIBRARY
    Valhalla_TYR_LIBRARY Valhalla_BALDR_LIBRARY Valhalla_LOKI_LIBRARY
    Valhalla_THOR_LIBRARY Valhalla_ODIN_LIBRARY Valhalla_SIF_LIBRARY
    Valhalla_MEILI_LIBRARY Valhalla_SKADI_LIBRARY Valhalla_MIDGARD_LIBRARY
    Valhalla_PROTO_LIBRARY)
