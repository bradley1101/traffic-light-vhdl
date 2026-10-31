# Simulation with GHDL (open source).  make sim  |  make wave  |  make clean
GHDL  = ghdl
FLAGS = --std=08
SIM   = sim

sim:
	cd $(SIM) && $(GHDL) -a $(FLAGS) ../src/traffic_light.vhd ../tb/tb_traffic_light.vhd
	cd $(SIM) && $(GHDL) -e $(FLAGS) tb_traffic_light
	cd $(SIM) && $(GHDL) -r $(FLAGS) tb_traffic_light --vcd=traffic_light.vcd

wave: sim
	cd $(SIM) && python3 plot_wave.py traffic_light.vcd ../docs/waveform.png

clean:
	cd $(SIM) && rm -f *.o *.cf *.vcd tb_traffic_light

.PHONY: sim wave clean
