#/bin/sh

if [ ! -d work/ ]; then
    vlib work
fi

vlog tb.sv pmodIf.v busIf.sv

vsim -c work.tb -lib work -do " \
add wave -noupdate /tb/* -recursive; \
run 1000ns; quit"