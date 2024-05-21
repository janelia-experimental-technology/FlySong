############################################################################
# XEM7001 - Xilinx constraints file
#
# Pin mappings for the XEM7001.  Use this as a template and comment out 
# the pins that are not used in your design.  (By default, map will fail
# if this file contains constraints for signals not in your design).
#
# Copyright (c) 2004-2015 Opal Kelly Incorporated
############################################################################
set_property BITSTREAM.GENERAL.COMPRESS True [current_design]

set_property PACKAGE_PIN K12 [get_ports {hi_muxsel}]
set_property IOSTANDARD LVCMOS33 [get_ports {hi_muxsel}]

############################################################################
## FrontPanel Host Interface
############################################################################
set_property PACKAGE_PIN N11 [get_ports {hi_in[0]}]
set_property PACKAGE_PIN R13 [get_ports {hi_in[1]}]
set_property PACKAGE_PIN R12 [get_ports {hi_in[2]}]
set_property PACKAGE_PIN P13 [get_ports {hi_in[3]}]
set_property PACKAGE_PIN T13 [get_ports {hi_in[4]}]
set_property PACKAGE_PIN T12 [get_ports {hi_in[5]}]
set_property PACKAGE_PIN P11 [get_ports {hi_in[6]}]
set_property PACKAGE_PIN R10 [get_ports {hi_in[7]}]

set_property SLEW FAST [get_ports {hi_in[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {hi_in[*]}]

set_property PACKAGE_PIN R15 [get_ports {hi_out[0]}]
set_property PACKAGE_PIN N13 [get_ports {hi_out[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {hi_out[*]}]

set_property PACKAGE_PIN T15 [get_ports {hi_inout[0]}]
set_property PACKAGE_PIN T14 [get_ports {hi_inout[1]}]
set_property PACKAGE_PIN R16 [get_ports {hi_inout[2]}]
set_property PACKAGE_PIN P16 [get_ports {hi_inout[3]}]
set_property PACKAGE_PIN P15 [get_ports {hi_inout[4]}]
set_property PACKAGE_PIN N16 [get_ports {hi_inout[5]}]
set_property PACKAGE_PIN M16 [get_ports {hi_inout[6]}]
set_property PACKAGE_PIN M12 [get_ports {hi_inout[7]}]
set_property PACKAGE_PIN L13 [get_ports {hi_inout[8]}]
set_property PACKAGE_PIN K13 [get_ports {hi_inout[9]}]
set_property PACKAGE_PIN M14 [get_ports {hi_inout[10]}]
set_property PACKAGE_PIN L14 [get_ports {hi_inout[11]}]
set_property PACKAGE_PIN K16 [get_ports {hi_inout[12]}]
set_property PACKAGE_PIN K15 [get_ports {hi_inout[13]}]
set_property PACKAGE_PIN J14 [get_ports {hi_inout[14]}]
set_property PACKAGE_PIN J13 [get_ports {hi_inout[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {hi_inout[*]}]

set_property PACKAGE_PIN M15 [get_ports {hi_aa}]
set_property IOSTANDARD LVCMOS33 [get_ports {hi_aa}]


create_clock -name okHostClk -period 20.83 [get_ports {hi_in[0]}]

set_input_delay -add_delay -max -clock [get_clocks {okHostClk}]  11.000 [get_ports {hi_inout[*]}]
set_input_delay -add_delay -min -clock [get_clocks {okHostClk}]  0.000  [get_ports {hi_inout[*]}]
set_multicycle_path -setup -from [get_ports {hi_inout[*]}] 2

set_input_delay -add_delay -max -clock [get_clocks {okHostClk}]  6.700 [get_ports {hi_in[*]}]
set_input_delay -add_delay -min -clock [get_clocks {okHostClk}]  0.000 [get_ports {hi_in[*]}]
set_multicycle_path -setup -from [get_ports {hi_in[*]}] 2

set_output_delay -add_delay -clock [get_clocks {okHostClk}]  8.900 [get_ports {hi_out[*]}]

set_output_delay -add_delay -clock [get_clocks {okHostClk}]  9.200 [get_ports {hi_inout[*]}]

# LEDs #####################################################################
set_property PACKAGE_PIN H5 [get_ports {led[0]}]
set_property PACKAGE_PIN F3 [get_ports {led[1]}]
set_property PACKAGE_PIN E3 [get_ports {led[2]}]
set_property PACKAGE_PIN H4 [get_ports {led[3]}]
set_property PACKAGE_PIN D3 [get_ports {led[4]}]
set_property PACKAGE_PIN C3 [get_ports {led[5]}]
set_property PACKAGE_PIN H3 [get_ports {led[6]}]
set_property PACKAGE_PIN A4 [get_ports {led[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[*]}]

set_property PACKAGE_PIN K1 [get_ports {cnvPin}]
set_property IOSTANDARD LVCMOS33 [get_ports {cnvPin}]
set_property PACKAGE_PIN E12 [get_ports {tmpPin}]
set_property IOSTANDARD LVCMOS33 [get_ports {tmpPin}]
set_property PACKAGE_PIN K2 [get_ports {tenPin}]
set_property IOSTANDARD LVCMOS33 [get_ports {tenPin}]

set_property PACKAGE_PIN B15 [get_ports {sclkPin}]
set_property IOSTANDARD LVCMOS33 [get_ports {sclkPin}]
set_property PACKAGE_PIN C16 [get_ports {mosiPin}]
set_property IOSTANDARD LVCMOS33 [get_ports {mosiPin}]
set_property PACKAGE_PIN D15 [get_ports {adccsPin}]
set_property IOSTANDARD LVCMOS33 [get_ports {adccsPin}]

#set_property PACKAGE_PIN J1 [get_ports {misoPins}]
#set_property IOSTANDARD LVCMOS33 [get_ports {misoPins}]


set_property PACKAGE_PIN D14 [get_ports {misoPins[0]}]
set_property PACKAGE_PIN D16 [get_ports {misoPins[1]}]
set_property PACKAGE_PIN E15 [get_ports {misoPins[2]}]
set_property PACKAGE_PIN E16 [get_ports {misoPins[3]}]
set_property PACKAGE_PIN F14 [get_ports {misoPins[4]}]
set_property PACKAGE_PIN G15 [get_ports {misoPins[5]}]
set_property PACKAGE_PIN G16 [get_ports {misoPins[6]}]
set_property PACKAGE_PIN H14 [get_ports {misoPins[7]}]
set_property PACKAGE_PIN H16 [get_ports {misoPins[8]}]
set_property PACKAGE_PIN H13 [get_ports {misoPins[9]}]
set_property PACKAGE_PIN G14 [get_ports {misoPins[10]}]
set_property PACKAGE_PIN F15 [get_ports {misoPins[11]}]
set_property IOSTANDARD LVCMOS33 [get_ports {misoPins[*]}]

# aux out ###############################################################
set_property PACKAGE_PIN R3 [get_ports {auxioPin}]
set_property IOSTANDARD LVCMOS33 [get_ports {auxioPin}]

# serial out ###############################################################
set_property PACKAGE_PIN M2 [get_ports {serialPin}]
set_property IOSTANDARD LVCMOS33 [get_ports {serialPin}]

# LED drivers ################################################################
set_property PACKAGE_PIN L2 [get_ports {LED0Pin}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED0Pin}]
set_property PACKAGE_PIN L3 [get_ports {LED1Pin}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED1Pin}]
set_property PACKAGE_PIN T2 [get_ports {LED0InvPin}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED0InvPin}]
set_property PACKAGE_PIN R2 [get_ports {LED1InvPin}]
set_property IOSTANDARD LVCMOS33 [get_ports {LED1InvPin}]

# Battery Interface ###############################################################
set_property PACKAGE_PIN K3 [get_ports {batStatePin}]
set_property IOSTANDARD LVCMOS33 [get_ports {batStatePin}]
set_property PACKAGE_PIN M1 [get_ports {batEnablePin}]
set_property IOSTANDARD LVCMOS33 [get_ports {batEnablePin}]

# TEST POINTS #####################################################################
set_property PACKAGE_PIN T10 [get_ports {tp[0]}]
set_property PACKAGE_PIN T8 [get_ports {tp[1]}]
set_property PACKAGE_PIN R8 [get_ports {tp[2]}]
set_property PACKAGE_PIN T7 [get_ports {tp[3]}]
set_property PACKAGE_PIN R7 [get_ports {tp[4]}]
set_property PACKAGE_PIN T9 [get_ports {tp[5]}]
set_property PACKAGE_PIN R6 [get_ports {tp[6]}]
set_property PACKAGE_PIN T5 [get_ports {tp[7]}]
set_property PACKAGE_PIN P8 [get_ports {tp[8]}]
set_property PACKAGE_PIN R5 [get_ports {tp[9]}]
set_property PACKAGE_PIN N6 [get_ports {tp[10]}]
set_property PACKAGE_PIN P5 [get_ports {tp[11]}]
set_property PACKAGE_PIN T4 [get_ports {tp[12]}]
set_property PACKAGE_PIN P4 [get_ports {tp[13]}]
set_property PACKAGE_PIN N4 [get_ports {tp[14]}]
set_property PACKAGE_PIN T3 [get_ports {tp[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {tp[*]}]

# SRAM DATA #####################################################################
set_property PACKAGE_PIN C4 [get_ports {RAMdata[0]}]
set_property PACKAGE_PIN A3 [get_ports {RAMdata[1]}]
set_property PACKAGE_PIN B2 [get_ports {RAMdata[2]}]
set_property PACKAGE_PIN C2 [get_ports {RAMdata[3]}]
set_property PACKAGE_PIN D1 [get_ports {RAMdata[4]}]
set_property PACKAGE_PIN E1 [get_ports {RAMdata[5]}]
set_property PACKAGE_PIN G2 [get_ports {RAMdata[6]}]
set_property PACKAGE_PIN H2 [get_ports {RAMdata[7]}]
set_property PACKAGE_PIN D4 [get_ports {RAMdata[8]}]
set_property PACKAGE_PIN A2 [get_ports {RAMdata[9]}]
set_property PACKAGE_PIN B1 [get_ports {RAMdata[10]}]
set_property PACKAGE_PIN C1 [get_ports {RAMdata[11]}]
set_property PACKAGE_PIN E2 [get_ports {RAMdata[12]}]
set_property PACKAGE_PIN F2 [get_ports {RAMdata[13]}]
set_property PACKAGE_PIN G1 [get_ports {RAMdata[14]}]
set_property PACKAGE_PIN H1 [get_ports {RAMdata[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {RAMdata[*]}]

# SRAM ADDRESS #####################################################################
set_property PACKAGE_PIN J1 [get_ports {RAMadr[0]}]
set_property PACKAGE_PIN D9 [get_ports {RAMadr[1]}]
set_property PACKAGE_PIN A8 [get_ports {RAMadr[2]}]
set_property PACKAGE_PIN D10 [get_ports {RAMadr[3]}]
set_property PACKAGE_PIN C8 [get_ports {RAMadr[4]}]
set_property PACKAGE_PIN C9 [get_ports {RAMadr[5]}]
set_property PACKAGE_PIN A9 [get_ports {RAMadr[6]}]
set_property PACKAGE_PIN A10 [get_ports {RAMadr[7]}]
set_property PACKAGE_PIN C12 [get_ports {RAMadr[8]}]
set_property PACKAGE_PIN A14 [get_ports {RAMadr[9]}]
set_property PACKAGE_PIN A13 [get_ports {RAMadr[10]}]
set_property PACKAGE_PIN B14 [get_ports {RAMadr[11]}]
set_property PACKAGE_PIN E13 [get_ports {RAMadr[12]}]
set_property PACKAGE_PIN A15 [get_ports {RAMadr[13]}]
set_property PACKAGE_PIN C14 [get_ports {RAMadr[14]}]
set_property PACKAGE_PIN B16 [get_ports {RAMadr[15]}]
set_property PACKAGE_PIN J3 [get_ports {RAMadr[16]}]
set_property PACKAGE_PIN B9 [get_ports {RAMadr[17]}]
set_property PACKAGE_PIN C11 [get_ports {RAMadr[18]}]
set_property PACKAGE_PIN F13 [get_ports {RAMadr[19]}]
set_property PACKAGE_PIN B12 [get_ports {RAMadr[20]}]
set_property PACKAGE_PIN A12 [get_ports {RAMadr[21]}]

set_property IOSTANDARD LVCMOS33 [get_ports {RAMadr[*]}]

# SRAM CONTROL #####################################################################
set_property PACKAGE_PIN P10 [get_ports {RAMoe}]
set_property IOSTANDARD LVCMOS33 [get_ports {RAMoe}]

set_property PACKAGE_PIN B10 [get_ports {RAMwr}]
set_property IOSTANDARD LVCMOS33 [get_ports {RAMwr}]
