cmake_minimum_required(VERSION 3.10.2)
project(valhalla-jni CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

find_package(Valhalla REQUIRED)

add_library(valhalla_jni SHARED valhalla_jni.cpp)

target_compile_options(valhalla_jni PRIVATE
    -ffunction-sections
    -fdata-sections
    -fvisibility=hidden
)

target_link_options(valhalla_jni PRIVATE
    -Wl,--gc-sections
    -Wl,--strip-all
    -Wl,-z,max-page-size=16384
    -Wl,-z,common-page-size=16384
)

target_link_libraries(valhalla_jni PRIVATE
    valhalla::valhalla
    #android
    #log
)
