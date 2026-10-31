# ModelSim / Questa script
# In the ModelSim console:   cd <repo>/sim   then   do run_modelsim.do

vlib work
vcom -2008 ../src/traffic_light.vhd
vcom -2008 ../tb/tb_traffic_light.vhd
vsim -t ns work.tb_traffic_light

add wave -divider "Inputs"
add wave sim:/tb_traffic_light/clk
add wave sim:/tb_traffic_light/rst
add wave sim:/tb_traffic_light/side_sensor
add wave sim:/tb_traffic_light/ped_request
add wave sim:/tb_traffic_light/night
add wave -divider "Main road"
add wave -color green  sim:/tb_traffic_light/m_g
add wave -color yellow sim:/tb_traffic_light/m_y
add wave -color red    sim:/tb_traffic_light/m_r
add wave -divider "Side road"
add wave -color green  sim:/tb_traffic_light/s_g
add wave -color yellow sim:/tb_traffic_light/s_y
add wave -color red    sim:/tb_traffic_light/s_r
add wave -divider "Pedestrian / FSM"
add wave sim:/tb_traffic_light/walk
add wave sim:/tb_traffic_light/dut/state
add wave -radix unsigned sim:/tb_traffic_light/dut/sec_cnt

run -all
wave zoom full
