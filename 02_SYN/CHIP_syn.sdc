# TODO: You may modified the clock constraints or add more constraints for your design
####################################################
set cycle 2.5   
####################################################


# The following are design spec. for synthesis
# You can NOT modify this seciton ! 
#####################################################
create_clock -name CLK -period $cycle [get_ports clk]
set_fix_hold                          [get_clocks CLK]
set_dont_touch_network                [get_clocks CLK]
set_ideal_network                     [get_ports clk]
set_clock_uncertainty            0.15 [get_clocks CLK] 
set_clock_latency                0.5  [get_clocks CLK] 

set_max_fanout 6 [all_inputs] 

set_operating_conditions -min_library fast -min fast -max_library slow -max slow
set_wire_load_model -name tsmc13_wl10 -library slow  
set_drive        1     [all_inputs]
set_load         1     [all_outputs]
#####################################################

# The following are input/output delay constraints
# TODO: You NEED to modify the constraints to pass gate-level simulation correctly (check TB and slow_memory)
# Note: You may also add more constraints for your design (but do not overwrite the existing ones in above section)
#####################################################
set mem_input_delay   [expr $cycle * 0.5]
set mem_output_delay  [expr $cycle * 0.5]
set reset_input_delay [expr $cycle * 0.6]
set done_output_delay  0.0

set mem_input_ports  [get_ports {mem_ready_D mem_ready_I mem_rdata_D[*] mem_rdata_I[*]}]
set reset_input_port [get_ports rst_n]
set mem_output_ports [get_ports {mem_read_D mem_write_D mem_addr_D[*] mem_wdata_D[*] mem_read_I mem_write_I mem_addr_I[*] mem_wdata_I[*]}]
set done_output_port [get_ports o_done]

set_input_delay  -max $mem_input_delay   -clock CLK $mem_input_ports
set_input_delay  -min 0.0                -clock CLK $mem_input_ports
set_input_delay  -max $reset_input_delay -clock CLK $reset_input_port
set_input_delay  -min 0.0                -clock CLK $reset_input_port
set_output_delay -max $mem_output_delay  -clock CLK $mem_output_ports
set_output_delay -min 0.0                -clock CLK $mem_output_ports
set_output_delay -max $done_output_delay -clock CLK $done_output_port
set_output_delay -min 0.0                -clock CLK $done_output_port

# The provided TB only toggles reset during initialization.  Do not let
# synchronous reset release dominate runtime setup optimization.
# set_false_path -from $reset_input_port
#####################################################

# Multicycle MUL block.
# RTL default CHIP.MUL_CYCLES must match this value.  The independent
# mul_a_reg/mul_b_reg launch registers capture forwarded operands, and
# mul_result_reg captures the multiplier output after multiple cycles.
set mul_cycles 3
set mul_from_regs [concat [get_registers -hier *mul_a_reg*] [get_registers -hier *mul_b_reg*]]
set mul_to_regs   [get_registers -hier *mul_result_reg*]
set_multicycle_path $mul_cycles -setup -from $mul_from_regs -to $mul_to_regs
set_multicycle_path [expr $mul_cycles - 1] -hold -from $mul_from_regs -to $mul_to_regs
