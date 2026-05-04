cmake_minimum_required(VERSION 3.10.2)
project(valhalla-bridge CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

find_package(Valhalla REQUIRED)

if(ANDROID)
    # Android: shared library containing the C API + JNI adapter
    add_library(valhalla_jni SHARED valhalla_capi.cpp valhalla_jni.cpp)

    target_link_libraries(valhalla_jni PRIVATE valhalla::valhalla)

    target_compile_options(valhalla_jni PRIVATE -fvisibility=hidden)

    target_link_options(valhalla_jni PRIVATE
        -static-libstdc++
        -Wl,--exclude-libs,ALL
        -Wl,-z,max-page-size=16384
        -Wl,-z,common-page-size=16384
    )
else()
    # iOS: static library with just the C API (merged into a framework by build_ios.sh)
    add_library(valhalla_capi STATIC valhalla_capi.cpp)

    target_link_libraries(valhalla_capi PRIVATE valhalla::valhalla)

    target_compile_options(valhalla_capi PRIVATE -fvisibility=hidden)

    install(TARGETS valhalla_capi ARCHIVE DESTINATION lib)
    install(FILES valhalla_capi.h DESTINATION include)
endif()
