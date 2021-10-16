#/bin/sh

if [ ! -d work/ ]; then
    vlib work
fi

vlog +define+SIM tb.sv pmodIf.v pmodCmd.sv busIf.sv

vsim -c work.tb -lib work -do " \
add wave -noupdate /tb/* -recursive; \
run 50000ns; quit"