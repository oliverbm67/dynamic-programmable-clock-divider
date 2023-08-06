"""Cocotb testbench for the Dynamic Programmable Clock Divider"""
import random
import cocotb
from cocotb.triggers import Timer,RisingEdge,FallingEdge
from cocotb.clock import Clock
from cocotb.utils import get_sim_time

async def dut_setup(dut, clk_period=1):
    """Reset the DUT and start the input clock. Assign sensible default to all inputs"""
    dut.rst_n.value = 0
    dut.div_ctrl.value = 0
    ## Clock generation
    cocotb.start_soon(Clock(dut.clk_src, clk_period, units="ns").start(start_high=False))
    ## Wait more than a clock period to avoid being synchronized with the clock
    await Timer(1.2*clk_period, units="ns")
    ## Reset synchronously deasserted
    await RisingEdge(dut.clk_src)
    dut.rst_n.value = 1

@cocotb.test()
async def default_test(dut):
    """Drive the clock of the DUT  with no checks and control of 0 i.e. clock is bypassed"""

    await dut_setup(dut)
    ## Await some time before ending the test
    await Timer(10, units="ns")
    dut._log.info("test completed")

async def divider_test(dut, divider=2):
    """Check the output frequency is the one programmed.
    0 should be a bypass of the divider, hence output is identical to the input
    1 is the input clock but inverted"""

    ## Make sure the clock period is 1ns
    await dut_setup(dut,1)
    ## Setup the divider value
    dut.div_ctrl.value = divider
    ## Wait for at least 1 clock cycle to be sure to count on the new period
    await RisingEdge(dut.clk_out)
    await RisingEdge(dut.clk_out)
    ## Measure period and half-period
    start_time = get_sim_time(units="ns")
    await FallingEdge(dut.clk_out)
    half_period = get_sim_time(units="ns")
    await RisingEdge(dut.clk_out)
    end_time = get_sim_time(units="ns")
    ## Wait for an extra clock cycle for better waveform viewing if needed
    await RisingEdge(dut.clk_out)
    period_measured = end_time - start_time
    half_period_measured = half_period - start_time
    if divider >= 2:        ## Normal case
        ## Allow 1% tolerance on expected period to get rid of rounding error
        assert (period_measured > 0.99*divider) and (period_measured < 1.01*divider), f"Incorrect full period. Expected {float(divider)} ns but measured {period_measured}"
        assert (half_period_measured > 0.99*divider/2) and (half_period_measured < 1.01*divider/2), f"Incorrect half period. Expected {float(divider/2)} ns but measured {half_period_measured}"
    else:
         ## Allow 1% tolerance on expected period to get rid of rounding error
        assert (period_measured > 0.99) and (period_measured < 1.01), f"Incorrect full period. Expected 1 ns but measured {period_measured} ns"
        assert (half_period_measured > 0.99/2) and (half_period_measured < 1.01/2), f"Incorrect half period. Expected 0.5 ns but measured {half_period_measured} ns"

@cocotb.test()
async def random_divider_test(dut, iteration=10):
    """Create multiple tests with a random value for the division factor"""
    max_divider_value = 2**int(dut.DIV_CTRL_SIZE_P.value) - 1;
    for iter in range(iteration):
        divider = random.randint(0,max_divider_value)
        await divider_test(dut, divider)

@cocotb.test()
async def edge_case_test(dut):
    """Check the edge case for division : 0,1 and the maxium division factor"""
    max_divider_value = 2**int(dut.DIV_CTRL_SIZE_P.value) - 1;
    await divider_test(dut, 0)
    await divider_test(dut, 1)
    await divider_test(dut, max_divider_value)

@cocotb.test()
async def complete_divider_test(dut):
    """Create multiple tests with a random value for the division factor"""
    max_divider_value = 2**int(dut.DIV_CTRL_SIZE_P.value) - 1;
    for divider in range(0,max_divider_value + 1):
         ## Make sure the clock period is 1ns
        await dut_setup(dut,1)
        ## Setup the divider value
        dut.div_ctrl.value = divider
        ## Wait for at least 1 clock cycle to be sure to count on the new period
        await RisingEdge(dut.clk_out)
        await RisingEdge(dut.clk_out)
        ## Measure period and half-period
        start_time = get_sim_time(units="ns")
        await FallingEdge(dut.clk_out)
        half_period = get_sim_time(units="ns")
        await RisingEdge(dut.clk_out)
        end_time = get_sim_time(units="ns")
        ## Wait for an extra clock cycle for better waveform viewing if needed
        await RisingEdge(dut.clk_out)
        period_measured = end_time - start_time
        half_period_measured = half_period - start_time
        if divider >= 2:        ## Normal case
            ## Allow 1% tolerance on expected period to get rid of rounding error
            if not((period_measured > 0.99*divider) and (period_measured < 1.01*divider)):
                print(f"Incorrect full period. Expected {float(divider)} ns but measured {period_measured}")
        else:
             ## Allow 1% tolerance on expected period to get rid of rounding error
            if not((period_measured > 0.99) and (period_measured < 1.01)):
                print(f"Incorrect full period. Expected 1 ns but measured {period_measured} ns")