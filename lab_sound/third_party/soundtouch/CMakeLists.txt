cmake_minimum_required(VERSION 3.10)

set(SOUNDTOUCH_ROOT "${CMAKE_CURRENT_SOURCE_DIR}")

#-------------------------------------------------------------------------------

project(soundtouch)

file(GLOB soundtouch_src
        "${SOUNDTOUCH_ROOT}/*"
        "${SOUNDTOUCH_ROOT}/SoundTouch/*"
        "${SOUNDTOUCH_ROOT}/SoundTouch/SoundTouch/*"
        "${SOUNDTOUCH_ROOT}/SoundTouch/SoundStretch/*"
        "${SOUNDTOUCH_ROOT}/include/SoundTouch/*"
        "${SOUNDTOUCH_ROOT}/include/SoundTouch/SoundTouch/*"
        "${SOUNDTOUCH_ROOT}/include/SoundTouch/SoundStretch/*"
)

add_library(soundtouch STATIC ${soundtouch_src})

target_include_directories(soundtouch PUBLIC
        ${SOUNDTOUCH_ROOT}/include)

set_target_properties(soundtouch
    PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib"
    ARCHIVE_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
)

