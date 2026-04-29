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
    find_package(Protobuf REQUIRED)
    find_package(ZLIB REQUIRED)
    find_package(Boost REQUIRED)

    # Collect whichever component libs were found
    set(Valhalla_COMPONENT_LIBS "")
    foreach(comp TYR BALDR LOKI THOR ODIN SIF MEILI SKADI MIDGARD PROTO)
        if(Valhalla_${comp}_LIBRARY)
            list(APPEND Valhalla_COMPONENT_LIBS "${Valhalla_${comp}_LIBRARY}")
        endif()
    endforeach()

    add_library(valhalla::valhalla STATIC IMPORTED)
    set_target_properties(valhalla::valhalla PROPERTIES
        IMPORTED_LOCATION "${Valhalla_LIBRARY}"
        INTERFACE_INCLUDE_DIRECTORIES "${Valhalla_INCLUDE_DIR};${Valhalla_INCLUDE_DIR}/valhalla;${Valhalla_INCLUDE_DIR}/valhalla/third_party"
        INTERFACE_LINK_LIBRARIES "${Valhalla_COMPONENT_LIBS};protobuf::libprotobuf;ZLIB::ZLIB;Boost::boost"
    )
endif()

mark_as_advanced(Valhalla_INCLUDE_DIR Valhalla_LIBRARY
    Valhalla_TYR_LIBRARY Valhalla_BALDR_LIBRARY Valhalla_LOKI_LIBRARY
    Valhalla_THOR_LIBRARY Valhalla_ODIN_LIBRARY Valhalla_SIF_LIBRARY
    Valhalla_MEILI_LIBRARY Valhalla_SKADI_LIBRARY Valhalla_MIDGARD_LIBRARY
    Valhalla_PROTO_LIBRARY)
