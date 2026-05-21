from vunit import VUnit

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()

# Optionally add VUnit's builtin HDL utilities for checking, logging, communication...
# See http://vunit.github.io/hdl_libraries.html.
vu.add_vhdl_builtins()
# or
# vu.add_verilog_builtins()

# Create library 'lib'
lib = vu.add_library("lib")

vu.add_vhdl_builtins()
vu.add_osvvm()
vu.add_verification_components()

# Add all files ending in .vhd in current working directory to library
lib.add_source_files("*.vhd")
lib.add_source_files("../../rtl/*/*.vhd")
lib.add_source_files("../../open-logic-main/src/base/vhdl/*.vhd")
lib.add_source_files("../../open-logic-main/src/intf/vhdl/*.vhd")

# Run vunit function
vu.main()

