# SPDX-FileCopyrightText: 2025 IObundle
#
# SPDX-License-Identifier: MIT

#extract cli args
set NAME [lindex $argv 0]
set CSR_IF [lindex $argv 1]
set BOARD [lindex $argv 2]
set VSRC [lindex $argv 3]
set INCLUDE_DIRS [lindex $argv 4]
set IS_FPGA [lindex $argv 5]
set USE_EXTMEM [lindex $argv 6]
set USE_ETHERNET [lindex $argv 7]

#verilog sources, vivado IPs, use file extension
foreach file [split $VSRC \ ] {
    puts $file
    if { [ file extension $file ] == ".edif" } {
        read_edif $file
    } elseif {$file != "" && $file != " " && $file != "\n"} {
        read_verilog -sv $file
    }
}

#include directories, use -include_dirs option
set SYNTH_FLAGS {}
foreach dir $INCLUDE_DIRS {
    lappend SYNTH_FLAGS "-include_dirs" "${dir}"
}

#read board properties
source vivado/$BOARD/board.tcl


#set pre-map custom assignments
if {[file exists "vivado/premap.tcl"]} {
    source "vivado/premap.tcl"
}


#read design constraints and synthesize design
if { $IS_FPGA == "1" } {
    puts "Synthesizing for FPGA"
    if {[file exists "vivado/$BOARD/$NAME\_dev.sdc"]} {
        read_xdc vivado/$BOARD/$NAME\_dev.sdc
    }
    if {[file exists "../src/$NAME.sdc"]} {
        read_xdc ../src/$NAME.sdc
    }
    if {[file exists "../../src/$NAME\_$CSR_IF.sdc"]} {
        read_xdc ../src/$NAME\_$CSR_IF.sdc
    }
    if {[file exists "vivado/$NAME\_tool.sdc"]} {
        read_xdc vivado/$NAME\_tool.sdc
    }
    eval synth_design -include_dirs ../src -include_dirs ../common_src -include_dirs ./src -include_dirs ./vivado/$BOARD $SYNTH_FLAGS -part $PART -top $NAME -verbose
} else {
    #read design constraints
    puts "Out of context synthesis"
    read_xdc -mode out_of_context vivado/$BOARD/$NAME\_dev.sdc
    read_xdc -mode out_of_context ../src/$NAME.sdc
    if {[file exists "../src/$NAME\_$CSR_IF.sdc"]} {
        read_xdc ../src/$NAME\_$CSR_IF.sdc
    }
    if {[file exists "./src/$NAME.sdc"]} {
        read_xdc ./src/$NAME.sdc
    }
    if {[file exists "vivado/$NAME\_tool.sdc"]} {
        read_xdc -mode out_of_context vivado/$NAME\_tool.sdc
    }
    eval synth_design -include_dirs ../src -include_dirs ../common_src -include_dirs ./src -include_dirs ./vivado/$BOARD $SYNTH_FLAGS -part $PART -top $NAME -mode out_of_context -flatten_hierarchy full -verbose
}

#set post-map custom assignments
if {[file exists "vivado/postmap.tcl"]} {
    source "vivado/postmap.tcl"
}

opt_design

place_design

route_design -timing

report_clocks
report_clock_interaction
report_cdc -details
report_bus_skew

report_clocks -file reports/$NAME\_$PART\_clocks.rpt
report_clock_interaction -file reports/$NAME\_$PART\_clock_interaction.rpt
report_cdc -details -file reports/$NAME\_$PART\_cdc.rpt
report_synchronizer_mtbf -file reports/$NAME\_$PART\_synchronizer_mtbf.rpt
report_utilization -file reports/$NAME\_$PART\_utilization.rpt
report_timing -file reports/$NAME\_$PART\_timing.rpt
report_timing_summary -file reports/$NAME\_$PART\_timing_summary.rpt
report_timing -file reports/$NAME\_$PART\_timing_paths.rpt -max_paths 30
report_bus_skew -file reports/$NAME\_$PART\_bus_skew.rpt

if { $IS_FPGA == "1" } {
    write_bitstream -force $NAME.bit
} else {
    write_verilog -force $NAME\_netlist.v
    write_verilog -force -mode synth_stub ${NAME}_stub.v
}
