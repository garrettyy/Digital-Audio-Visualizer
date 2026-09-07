# --- VGA Red ---
set_property PACKAGE_PIN G19 [get_ports {r[0]}]
set_property PACKAGE_PIN H19 [get_ports {r[1]}]
set_property PACKAGE_PIN J19 [get_ports {r[2]}]
set_property PACKAGE_PIN N19 [get_ports {r[3]}]

# --- VGA Green ---
set_property PACKAGE_PIN J17 [get_ports {g[0]}]
set_property PACKAGE_PIN H17 [get_ports {g[1]}]
set_property PACKAGE_PIN G17 [get_ports {g[2]}]
set_property PACKAGE_PIN D17 [get_ports {g[3]}]

# --- VGA Blue ---
set_property PACKAGE_PIN N18 [get_ports {b[0]}]
set_property PACKAGE_PIN L18 [get_ports {b[1]}]
set_property PACKAGE_PIN K18 [get_ports {b[2]}]
set_property PACKAGE_PIN J18 [get_ports {b[3]}]

# --- VGA Sync ---
set_property PACKAGE_PIN P19 [get_ports hsync]
set_property PACKAGE_PIN R19 [get_ports vsync]

# --- Digital Inputs (Clock, Reset, Switch) ---
set_property PACKAGE_PIN W5 [get_ports clk]
set_property PACKAGE_PIN U18 [get_ports rst]
set_property PACKAGE_PIN V17 [get_ports sw_filter_en]
set_property PACKAGE_PIN V16 [get_ports sw_highpass_en]

# --- Analog Microphone Inputs (JXADC Header) ---
set_property PACKAGE_PIN J3 [get_ports vauxp6]
set_property PACKAGE_PIN K3 [get_ports vauxn6]

# ==================================================
# IO STANDARD CONFIGURATION (3.3V Logic)
# ==================================================
set_property IOSTANDARD LVCMOS33 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports hsync]
set_property IOSTANDARD LVCMOS33 [get_ports rst]
set_property IOSTANDARD LVCMOS33 [get_ports sw_filter_en]
set_property IOSTANDARD LVCMOS33 [get_ports sw_highpass_en]
set_property IOSTANDARD LVCMOS33 [get_ports vsync]
set_property IOSTANDARD LVCMOS33 [get_ports {b[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {b[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {b[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {b[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {g[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {g[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {g[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {g[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {r[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {r[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {r[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {r[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports vauxp6]
set_property IOSTANDARD LVCMOS33 [get_ports vauxn6]

# ==================================================
# CLOCK TIMING CONSTRAINT
# ==================================================
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} -add [get_ports clk]