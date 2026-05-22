if {[catch {

# define run engine funtion
source [file join {C:/lscc/radiant/2025.2} scripts tcl flow run_engine.tcl]
# define global variables
global para
set para(gui_mode) "1"
set para(prj_dir) "C:/Users/felix/Documents/Master_1ECAM/FPGA/pico-ice-lab-master/project/robot"
if {![file exists {C:/Users/felix/Documents/Master_1ECAM/FPGA/pico-ice-lab-master/project/robot/impl_1}]} {
  file mkdir {C:/Users/felix/Documents/Master_1ECAM/FPGA/pico-ice-lab-master/project/robot/impl_1}
}
cd {C:/Users/felix/Documents/Master_1ECAM/FPGA/pico-ice-lab-master/project/robot/impl_1}
# synthesize IPs
# synthesize VMs
# synthesize top design
file delete -force -- robot_impl_1.vm robot_impl_1.ldc
::radiant::runengine::run_engine_newmsg synthesis -f "C:/Users/felix/Documents/Master_1ECAM/FPGA/pico-ice-lab-master/project/robot/impl_1/robot_impl_1_lattice.synproj" -logfile "robot_impl_1_lattice.srp"
::radiant::runengine::run_postsyn [list -a iCE40UP -p iCE40UP5K -t SG48 -sp High-Performance_1.2V -oc Industrial -top -w -o robot_impl_1_syn.udb robot_impl_1.vm] [list robot_impl_1.ldc]

} out]} {
   ::radiant::runengine::runtime_log $out
   exit 1
}
