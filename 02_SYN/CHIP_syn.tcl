sh mkdir -p Netlist
sh mkdir -p Report

set DESIGN "CHIP"

remove_design -all

analyze -format verilog {../01_RTL/CHIP.v}
elaborate $DESIGN
current_design $DESIGN
link
uniquify

# Keep all timing/design constraints in one place.
read_sdc ./CHIP_syn.sdc

# Timing-first flow.  Keep area recovery out of the main loop until setup
# paths are clean; aggressive area optimization was downsizing marginal paths.
set_flatten true -effort high
set_structure true
set compile_ultra_ungroup_dw true

check_design > ./Report/${DESIGN}_check_design.rpt

# Compile, flatten hierarchy, then run timing-focused incremental cleanup.
compile_ultra
ungroup -all -flatten
compile_ultra -incremental
compile_ultra -incremental

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
report_timing -delay min -max_paths 20 -path full -nets -transition_time -capacitance \
                                                   > ./Report/${DESIGN}_syn.timing_min
report_timing -delay max -max_paths 100 -path full -nets -transition_time -capacitance \
                                                   > ./Report/${DESIGN}_syn.timing_max
report_timing -delay max -max_paths 1 -path full_clock_expanded -nets -transition_time -capacitance -input_pins \
                                                   > ./Report/${DESIGN}_syn.critical_path
report_timing -delay max -max_paths 10 -nworst 3 -path end \
                                                   > ./Report/${DESIGN}_syn.worst_endpoints
report_timing -delay max -group CLK -max_paths 20 -path full -nets -transition_time -capacitance \
                                                   > ./Report/${DESIGN}_syn.timing_CLK
report_timing_summary                            > ./Report/${DESIGN}_syn.timing_summary
report_power                                   > ./Report/${DESIGN}_syn.power

write -f ddc     -hierarchy -output ./Netlist/${DESIGN}_syn.ddc
write -f verilog -hierarchy -output ./Netlist/${DESIGN}_syn.v
write_sdf -version 2.1       ./Netlist/${DESIGN}_syn.sdf
write_sdc -version 1.8       ./Netlist/${DESIGN}_syn.sdc
