if {[catch {

# define run engine funtion
source [file join {C:/lscc/radiant/2025.2} scripts tcl flow run_engine.tcl]
# define global variables
global para
set para(gui_mode) "1"
set para(prj_dir) "C:/Users/felix/Documents/Master_1ECAM/FPGA/lab"
if {![file exists {C:/Users/felix/Documents/Master_1ECAM/FPGA/lab/lab_1}]} {
  file mkdir {C:/Users/felix/Documents/Master_1ECAM/FPGA/lab/lab_1}
}
cd {C:/Users/felix/Documents/Master_1ECAM/FPGA/lab/lab_1}
# synthesize IPs
# synthesize VMs
# synthesize top design
file delete -force -- lab_lab_1.vm lab_lab_1.ldc
if {[file normalize "C:/Users/felix/Documents/Master_1ECAM/FPGA/lab/lab_1/lab_lab_1_synplify.tcl"] != [file normalize "./lab_lab_1_synplify.tcl"]} {
  file copy -force "C:/Users/felix/Documents/Master_1ECAM/FPGA/lab/lab_1/lab_lab_1_synplify.tcl" "./lab_lab_1_synplify.tcl"
}
if {[ catch {::radiant::runengine::run_engine synpwrap -prj "lab_lab_1_synplify.tcl" -log "lab_lab_1.srf"} result options ]} {
    file delete -force -- lab_lab_1.vm lab_lab_1.ldc
    return -options $options $result
}
::radiant::runengine::run_postsyn [list -a iCE40UP -p iCE40UP5K -t SG48 -sp High-Performance_1.2V -oc Industrial -top -w -o lab_lab_1_syn.udb lab_lab_1.vm] [list lab_lab_1.ldc]

} out]} {
   ::radiant::runengine::runtime_log $out
   exit 1
}
