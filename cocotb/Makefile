SIM ?=verilator
TOPLEVEL_LANG ?=verilog

VERILOG_SOURCES += $(PWD)/../rtl/dpcd.sv
TOP_LEVEL = dpcd

MODULE = test_dpcd

## For verilator simulation
EXTRA_ARGS += --trace --trace-structs
# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim