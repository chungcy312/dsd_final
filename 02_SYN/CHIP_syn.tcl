sh mkdir -p Netlist
sh mkdir -p Report

set DESIGN "CHIP"

# Area-first synthesis target. Gate simulation effectively uses the
# testbench `CYCLE value from tb_define.v, which is 10 ns in this project.
set cycle             10.0
set clk_uncertainty    0.10
set clk_latency        0.50
set input_delay       [expr $cycle * 0.5]
set output_delay      [expr $cycle * 0.5]

remove_design -all

analyze -format verilog {../01_RTL/CHIP.v}
elaborate $DESIGN
current_design $DESIGN
link
uniquify

create_clock -name CLK -period $cycle [get_ports clk]
set_fix_hold [get_clocks CLK]
set_dont_touch_network [get_clocks CLK]
set_ideal_network [get_ports clk]
set_clock_uncertainty $clk_uncertainty [get_clocks CLK]
set_clock_latency $clk_latency [get_clocks CLK]

set_operating_conditions -min_library fast -min fast -max_library slow -max slow
set_wire_load_model -name tsmc13_wl10 -library slow

set_drive 1 [all_inputs]
set_load  1 [all_outputs]
set_max_fanout 6 [all_inputs]

set_input_delay  $input_delay  -clock CLK [remove_from_collection [all_inputs] [get_ports clk]]
set_output_delay $output_delay -clock CLK [all_outputs]

# Push area down after timing is constrained. DC still treats timing as the
# hard constraint; max_area 0 asks it to keep reducing area where legal.
set_max_area 0
set_flatten true -effort high
set_structure true

check_design > ./Report/${DESIGN}_check_design.rpt

compile_ultra -ungroup_all -area_high_effort_script
compile_ultra -incremental -area_high_effort_script

set bus_inference_style {%s[%d]}
set bus_naming_style    {%s[%d]}
set hdlout_internal_buses true
change_names -hierarchy -rule verilog
define_name_rules name_rule -allowed {a-z A-Z 0-9 _}    -max_length 255 -type cell
define_name_rules name_rule -allowed {a-z A-Z 0-9 _[]}  -max_length 255 -type net
define_name_rules name_rule -map {{"\\*cell\\*" "cell"}}
define_name_rules name_rule -case_insensitive
change_names -hierarchy -rules name_rule
set verilogout_no_tri true
set verilogout_higher_designs_first true

report_qor                                      > ./Report/${DESIGN}_syn.qor
report_constraint -all_violators               > ./Report/${DESIGN}_syn.constraint
report_area -hierarchy                         > ./Report/${DESIGN}_syn.area
report_timing -delay min -max_paths 20         > ./Report/${DESIGN}_syn.timing_min
report_timing -delay max -max_paths 20         > ./Report/${DESIGN}_syn.timing_max
report_power                                   > ./Report/${DESIGN}_syn.power

write -f ddc     -hierarchy -output ./Netlist/${DESIGN}_syn.ddc
write -f verilog -hierarchy -output ./Netlist/${DESIGN}_syn.v
write_sdf -version 2.1       ./Netlist/${DESIGN}_syn.sdf
write_sdc -version 1.8       ./Netlist/${DESIGN}_syn.sdc
