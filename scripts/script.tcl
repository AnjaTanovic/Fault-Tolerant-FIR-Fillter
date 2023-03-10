variable dispScriptFile [file normalize [info script]]

proc getScriptDirectory {} {
    variable dispScriptFile
    set scriptFolder [file dirname $dispScriptFile]
    return $scriptFolder
}

set sdir [getScriptDirectory]
cd [getScriptDirectory]

# Definisanje direktorijuma u kojima ce biti smesten projekat
set resultDir ..\/result\/FIR_filter
file mkdir $resultDir
create_project ..\/result\/FIR_filter -part xc7z010clg400-1 -force


# Ukljucivanje izvornih fajlova u projekat
add_files -norecurse ..\/hdl\/communication_top.vhd
add_files -norecurse ..\/hdl\/fir_top.vhd
add_files -norecurse ..\/hdl\/redundancy_spares.vhd
add_files -norecurse ..\/hdl\/mac.vhd
add_files -norecurse ..\/hdl\/voter.vhd
add_files -norecurse ..\/hdl\/txt_util.vhd
add_files -norecurse ..\/hdl\/util_pkg.vhd
update_compile_order -fileset sources_1

# Ukljucivanje ogranicenja u projekat
add_files -fileset constrs_1 ..\/constraints\/clk_constraint.xdc

# Ukljucivanje testbenc fajlova u projekat
add_files -fileset sim_1 -norecurse ..\/hdl\/tb_communication.vhd
add_files -fileset sim_1 -norecurse ..\/hdl\/tb_fir.vhd
update_compile_order -fileset sim_1

# Ukljucivanje skripte za forsiranje signala (SA1 i SA0)
#set_property SOURCE_SET sources_1 [get_filesets sim_1]
add_files -fileset sim_1 -norecurse ..\/scripts\/script_force.tcl
set_property -name {xsim.simulate.runtime} -value {0 ns} -objects [get_filesets sim_1]
