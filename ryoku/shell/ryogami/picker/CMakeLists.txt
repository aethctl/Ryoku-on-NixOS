# QML file names must be unique across qml/: each becomes a type named after its
# file, and one starting with `pragma Singleton` registers as a singleton.
cmake_minimum_required(VERSION 3.28)

project(ryogami-picker LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.6 REQUIRED COMPONENTS Quick ShaderTools Multimedia GuiPrivate)

qt_standard_project_setup(REQUIRES 6.6)

file(GLOB_RECURSE picker_sources CONFIGURE_DEPENDS
    RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}"
    src/*.cpp src/*.h)
file(GLOB_RECURSE picker_qml CONFIGURE_DEPENDS
    RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}"
    qml/*.qml qml/*.js)
file(GLOB picker_shaders CONFIGURE_DEPENDS
    RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}"
    shaders/*.vert shaders/*.frag)
file(GLOB picker_fonts CONFIGURE_DEPENDS
    RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}"
    qml/theme/fonts/*.ttf)

# QML files sit at the module root so their implicit import is the module and sees the C++ types.
foreach(font_file IN LISTS picker_fonts)
    get_filename_component(font_name "${font_file}" NAME)
    set_source_files_properties("${font_file}" PROPERTIES QT_RESOURCE_ALIAS "fonts/${font_name}")
endforeach()

# The Ryoku mark the masthead wears, read from the brand folder so the repo keeps one copy.
set(picker_brand "${CMAKE_CURRENT_SOURCE_DIR}/../../../assets/brand/logo-mark-v2.png")
set_source_files_properties("${picker_brand}" PROPERTIES QT_RESOURCE_ALIAS "brand/logo-mark.png")

foreach(qml_file IN LISTS picker_qml)
    get_filename_component(qml_name "${qml_file}" NAME)
    set_source_files_properties("${qml_file}" PROPERTIES QT_RESOURCE_ALIAS "${qml_name}")
    file(STRINGS "${qml_file}" singleton_pragma LIMIT_COUNT 1 REGEX "^pragma Singleton")
    if(singleton_pragma)
        set_source_files_properties("${qml_file}" PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
    endif()
endforeach()

qt_add_qml_module(ryogami-picker
    URI Ryoku.Ryogami
    VERSION 1.0
    OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/qml/Ryoku/Ryogami"
    SOURCES ${picker_sources}
    QML_FILES ${picker_qml}
    RESOURCES ${picker_fonts} ${picker_brand}
)

# qmltyperegistrar includes the QML_ELEMENT headers by bare name.
file(GLOB picker_source_dirs LIST_DIRECTORIES true "${CMAKE_CURRENT_SOURCE_DIR}/src/*")
target_include_directories(ryogami-picker PRIVATE ${picker_source_dirs})

# QRhi sits behind the GuiPrivate include path; only its exported classes are used.
target_link_libraries(ryogami-picker PRIVATE Qt6::Quick Qt6::Multimedia Qt6::GuiPrivate)

# Relocatable: the plugin finds its backing library through an $ORIGIN rpath.
set_target_properties(ryogami-picker ryogami-pickerplugin PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/qml/Ryoku/Ryogami")
set_target_properties(ryogami-pickerplugin PROPERTIES
    INSTALL_RPATH "$ORIGIN"
    BUILD_WITH_INSTALL_RPATH ON)

qt_add_shaders(ryogami-picker "ryogami_shaders"
    GLSL "330,300es"
    PREFIX "/"
    FILES ${picker_shaders}
)
