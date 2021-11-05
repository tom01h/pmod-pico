# Generated Cmake Pico project file

cmake_minimum_required(VERSION 3.13)

set(CMAKE_C_STANDARD 11)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_BUILD_TYPE "Release")
set(TINYUSB_DEBUG_LEVEL 0)

# initalize pico_sdk from installed location
# (note this can come from environment, CMake cache etc)
set(PICO_SDK_PATH $ENV{PICO_SDK_PATH})

# Pull in Raspberry Pi Pico SDK (must be before project)
include(pico_sdk_import.cmake)

project(pmodUsb C CXX)

# Initialise the Raspberry Pi Pico SDK
pico_sdk_init()

if (TARGET tinyusb_device)
	# Add executable. Default name is the project name, version 0.1

	add_executable(pmodUsb
		pmodUsb.c
		pico_stdio_usb/stdio_usb.c
		pico_stdio_usb/stdio_usb_descriptors.c
	)

	target_include_directories(pmodUsb PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
	target_include_directories(pmodUsb PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/pico_stdio_usb/include)

	pico_set_program_name(pmodUsb "pmodUsb")
	pico_set_program_version(pmodUsb "0.1")

	#pico_enable_stdio_uart(pmodUsb 0)
	#pico_enable_stdio_usb(pmodUsb 0)

	# Add the standard library to the build
	target_link_libraries(pmodUsb PRIVATE pico_stdlib)

	# Add any user requested libraries
	target_link_libraries(pmodUsb PRIVATE
		pico_unique_id
		tinyusb_device
		tinyusb_board
		pico_multicore
	)

	pico_add_extra_outputs(pmodUsb)

elseif(PICO_ON_DEVICE)
	message(WARNING "not building hello_usb because TinyUSB submodule is not initialized in the SDK")
endif()
