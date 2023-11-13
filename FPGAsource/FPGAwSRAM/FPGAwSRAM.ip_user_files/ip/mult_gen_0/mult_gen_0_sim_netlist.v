// Copyright 1986-2017 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2017.1 (win64) Build 1846317 Fri Apr 14 18:55:03 MDT 2017
// Date        : Sun May 14 15:34:09 2017
// Host        : sawtelles-lw1 running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode funcsim
//               C:/PROJECTS/STERN/96CH_RECORDER/FPGA/96mic/96mic.runs/mult_gen_0_synth_1/mult_gen_0_sim_netlist.v
// Design      : mult_gen_0
// Purpose     : This verilog netlist is a functional simulation representation of the design and should not be modified
//               or synthesized. This netlist cannot be used for SDF annotated simulation.
// Device      : xc7a15tftg256-1
// --------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

(* CHECK_LICENSE_TYPE = "mult_gen_0,mult_gen_v12_0_12,{}" *) (* downgradeipidentifiedwarnings = "yes" *) (* x_core_info = "mult_gen_v12_0_12,Vivado 2017.1" *) 
(* NotValidForBitStream *)
module mult_gen_0
   (CLK,
    A,
    P);
  (* x_interface_info = "xilinx.com:signal:clock:1.0 clk_intf CLK" *) input CLK;
  (* x_interface_info = "xilinx.com:signal:data:1.0 a_intf DATA" *) input [15:0]A;
  (* x_interface_info = "xilinx.com:signal:data:1.0 p_intf DATA" *) output [32:0]P;

  wire [15:0]A;
  wire CLK;
  wire [32:0]P;
  wire [47:0]NLW_U0_PCASC_UNCONNECTED;
  wire [1:0]NLW_U0_ZERO_DETECT_UNCONNECTED;

  (* C_A_TYPE = "1" *) 
  (* C_A_WIDTH = "16" *) 
  (* C_B_TYPE = "1" *) 
  (* C_B_VALUE = "10010010101011100" *) 
  (* C_B_WIDTH = "17" *) 
  (* C_CCM_IMP = "2" *) 
  (* C_CE_OVERRIDES_SCLR = "0" *) 
  (* C_HAS_CE = "0" *) 
  (* C_HAS_SCLR = "0" *) 
  (* C_HAS_ZERO_DETECT = "0" *) 
  (* C_LATENCY = "1" *) 
  (* C_MODEL_TYPE = "0" *) 
  (* C_MULT_TYPE = "2" *) 
  (* C_OPTIMIZE_GOAL = "1" *) 
  (* C_OUT_HIGH = "32" *) 
  (* C_OUT_LOW = "0" *) 
  (* C_ROUND_OUTPUT = "0" *) 
  (* C_ROUND_PT = "0" *) 
  (* C_VERBOSITY = "0" *) 
  (* C_XDEVICEFAMILY = "artix7" *) 
  (* downgradeipidentifiedwarnings = "yes" *) 
  mult_gen_0_mult_gen_v12_0_12 U0
       (.A(A),
        .B({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .CE(1'b1),
        .CLK(CLK),
        .P(P),
        .PCASC(NLW_U0_PCASC_UNCONNECTED[47:0]),
        .SCLR(1'b0),
        .ZERO_DETECT(NLW_U0_ZERO_DETECT_UNCONNECTED[1:0]));
endmodule

(* C_A_TYPE = "1" *) (* C_A_WIDTH = "16" *) (* C_B_TYPE = "1" *) 
(* C_B_VALUE = "10010010101011100" *) (* C_B_WIDTH = "17" *) (* C_CCM_IMP = "2" *) 
(* C_CE_OVERRIDES_SCLR = "0" *) (* C_HAS_CE = "0" *) (* C_HAS_SCLR = "0" *) 
(* C_HAS_ZERO_DETECT = "0" *) (* C_LATENCY = "1" *) (* C_MODEL_TYPE = "0" *) 
(* C_MULT_TYPE = "2" *) (* C_OPTIMIZE_GOAL = "1" *) (* C_OUT_HIGH = "32" *) 
(* C_OUT_LOW = "0" *) (* C_ROUND_OUTPUT = "0" *) (* C_ROUND_PT = "0" *) 
(* C_VERBOSITY = "0" *) (* C_XDEVICEFAMILY = "artix7" *) (* ORIG_REF_NAME = "mult_gen_v12_0_12" *) 
(* downgradeipidentifiedwarnings = "yes" *) 
module mult_gen_0_mult_gen_v12_0_12
   (CLK,
    A,
    B,
    CE,
    SCLR,
    ZERO_DETECT,
    P,
    PCASC);
  input CLK;
  input [15:0]A;
  input [16:0]B;
  input CE;
  input SCLR;
  output [1:0]ZERO_DETECT;
  output [32:0]P;
  output [47:0]PCASC;

  wire \<const0> ;
  wire [15:0]A;
  wire CLK;
  wire [32:2]\^P ;
  wire [1:0]NLW_i_mult_P_UNCONNECTED;
  wire [47:0]NLW_i_mult_PCASC_UNCONNECTED;
  wire [1:0]NLW_i_mult_ZERO_DETECT_UNCONNECTED;

  assign P[32:2] = \^P [32:2];
  assign P[1] = \<const0> ;
  assign P[0] = \<const0> ;
  assign PCASC[47] = \<const0> ;
  assign PCASC[46] = \<const0> ;
  assign PCASC[45] = \<const0> ;
  assign PCASC[44] = \<const0> ;
  assign PCASC[43] = \<const0> ;
  assign PCASC[42] = \<const0> ;
  assign PCASC[41] = \<const0> ;
  assign PCASC[40] = \<const0> ;
  assign PCASC[39] = \<const0> ;
  assign PCASC[38] = \<const0> ;
  assign PCASC[37] = \<const0> ;
  assign PCASC[36] = \<const0> ;
  assign PCASC[35] = \<const0> ;
  assign PCASC[34] = \<const0> ;
  assign PCASC[33] = \<const0> ;
  assign PCASC[32] = \<const0> ;
  assign PCASC[31] = \<const0> ;
  assign PCASC[30] = \<const0> ;
  assign PCASC[29] = \<const0> ;
  assign PCASC[28] = \<const0> ;
  assign PCASC[27] = \<const0> ;
  assign PCASC[26] = \<const0> ;
  assign PCASC[25] = \<const0> ;
  assign PCASC[24] = \<const0> ;
  assign PCASC[23] = \<const0> ;
  assign PCASC[22] = \<const0> ;
  assign PCASC[21] = \<const0> ;
  assign PCASC[20] = \<const0> ;
  assign PCASC[19] = \<const0> ;
  assign PCASC[18] = \<const0> ;
  assign PCASC[17] = \<const0> ;
  assign PCASC[16] = \<const0> ;
  assign PCASC[15] = \<const0> ;
  assign PCASC[14] = \<const0> ;
  assign PCASC[13] = \<const0> ;
  assign PCASC[12] = \<const0> ;
  assign PCASC[11] = \<const0> ;
  assign PCASC[10] = \<const0> ;
  assign PCASC[9] = \<const0> ;
  assign PCASC[8] = \<const0> ;
  assign PCASC[7] = \<const0> ;
  assign PCASC[6] = \<const0> ;
  assign PCASC[5] = \<const0> ;
  assign PCASC[4] = \<const0> ;
  assign PCASC[3] = \<const0> ;
  assign PCASC[2] = \<const0> ;
  assign PCASC[1] = \<const0> ;
  assign PCASC[0] = \<const0> ;
  assign ZERO_DETECT[1] = \<const0> ;
  assign ZERO_DETECT[0] = \<const0> ;
  GND GND
       (.G(\<const0> ));
  (* C_A_TYPE = "1" *) 
  (* C_A_WIDTH = "16" *) 
  (* C_B_TYPE = "1" *) 
  (* C_B_VALUE = "10010010101011100" *) 
  (* C_B_WIDTH = "17" *) 
  (* C_CCM_IMP = "2" *) 
  (* C_CE_OVERRIDES_SCLR = "0" *) 
  (* C_HAS_CE = "0" *) 
  (* C_HAS_SCLR = "0" *) 
  (* C_HAS_ZERO_DETECT = "0" *) 
  (* C_LATENCY = "1" *) 
  (* C_MODEL_TYPE = "0" *) 
  (* C_MULT_TYPE = "2" *) 
  (* C_OPTIMIZE_GOAL = "1" *) 
  (* C_OUT_HIGH = "32" *) 
  (* C_OUT_LOW = "0" *) 
  (* C_ROUND_OUTPUT = "0" *) 
  (* C_ROUND_PT = "0" *) 
  (* C_VERBOSITY = "0" *) 
  (* C_XDEVICEFAMILY = "artix7" *) 
  (* downgradeipidentifiedwarnings = "yes" *) 
  mult_gen_0_mult_gen_v12_0_12_viv i_mult
       (.A(A),
        .B({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .CE(1'b0),
        .CLK(CLK),
        .P({\^P ,NLW_i_mult_P_UNCONNECTED[1:0]}),
        .PCASC(NLW_i_mult_PCASC_UNCONNECTED[47:0]),
        .SCLR(1'b0),
        .ZERO_DETECT(NLW_i_mult_ZERO_DETECT_UNCONNECTED[1:0]));
endmodule
`pragma protect begin_protected
`pragma protect version = 1
`pragma protect encrypt_agent = "XILINX"
`pragma protect encrypt_agent_info = "Xilinx Encryption Tool 2015"
`pragma protect key_keyowner="Cadence Design Systems.", key_keyname="cds_rsa_key", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=64)
`pragma protect key_block
hYn4T1Tz8lmB8loeGYuHmgEJp5TdMkRKn5tdK0Pxo3wkkBR/aG2es4RXT0Kx9IkGgy2jVWVPoeKB
usRl+M6Pxw==

`pragma protect key_keyowner="Mentor Graphics Corporation", key_keyname="MGC-VERIF-SIM-RSA-1", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=128)
`pragma protect key_block
cZOTsELKZdXMGraSgAw9rgqxvSLbW0aT2lTeYBbmmRdIiILVX40Q3XF89sXvrmWq2q7dAJSXvpsX
1JIpxbCUMi40Nuru7hdg9WkNNMs1Q8UJCou9g/GNLxJnh56Wx2JqOiplBqlgeaLjd0T16sGmIYm4
kTNGsNPOASR/dWaldsE=

`pragma protect key_keyowner="Synopsys", key_keyname="SNPS-VCS-RSA-1", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=128)
`pragma protect key_block
o6ehD67QiTZFs1auOjL5nkbDEbn3neiXmbyTqqoQKK+v0TaPL6hSxGHE/Fz3NtmR3RIza9+Y9rVH
Je7RNuyq8vsgofAGK5Qpf28P/9kF6eDh0JgLJHOonk7lnG+gufS3pMHIfioCEe/2wyoIxzbwUPNl
TCIJtbzDvWpcCIKBgiQ=

`pragma protect key_keyowner="Aldec", key_keyname="ALDEC15_001", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
cASOe3RHelXhU6s/jEEqAnadTjmj4ihjbMuYb8YjKT8lAROht6xaHEt/3WXUlUPXIpDwtJlexClV
csQVUSlNShzZmxBI5epxH/HJqLhQYwkRDFK2BUAagxn++cS1iWJGlow9Gha0EU+PfllVje3OWy4O
LbiqHgQlEG6sIGo0ZCj6KPC87SBAytHtAiVRpovpGAxLS/DLeXSJaavSSwOc7nmWFDaNEi9dJS9i
qixZxDI5QNaDp3uaBFLzKqo9oSPgNj1mYKRZp6XL0ganfqQCHh/snCyymi+o0DC5vSM/+RtCZHXA
A1u3UsiXv/IfegAneXJ/yU2Rpj4P9iaLKgmtjQ==

`pragma protect key_keyowner="ATRENTA", key_keyname="ATR-SG-2015-RSA-3", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
kAlIhoAHksCGo5mF85FXcP0dM1NExLuDn6ZkyfgoWH09b5qcw8bLJnQMlkLvdLRrczznUPKBLrRR
nUHSMi9UTzRZ0rrnazgGnHFEV1vyoRgDQDOpkZbrkgl/VynbkoMBhCQXYT59yyHhqjI6WeIYVipR
zyn+NdmUB+/GwlsSYygywX31rotvUxb4RZmCqg+UCemw+N0tS43QuIzJuG1JM+3+SVbU3LuVcClf
rOwWqAFHsOXBSrXNoPX6QeNlYUKy8gcjiaQqPSrbrSJWdgvqshdNnvLWuzkREOLY43TCoAFwM8p5
73h2VUHmwffIqzCELbp3Tee5sQXgMbvJ+Mbfpg==

`pragma protect key_keyowner="Xilinx", key_keyname="xilinx_2016_05", key_method="rsa"
`pragma protect encoding = (enctype="BASE64", line_length=76, bytes=256)
`pragma protect key_block
CFQ8408huN9E8h2/r246qkePkogHtf4rd5gf8GO4NiUzetOQ2my8cbvxYBjZy3yQSw0/LrN95Drj
cc3uAe9r+wOvBQ3aM7AKnKpRkAvmqyCRt8lkW5NRi37udLv8jQJ5gVByTJ76KIn8s2kfj/iHou8+
VyK641fcvp2Fk/dmC13HALsHzGvO1m9Kg3zHT1aJxtdh2FDGLhOy/TtcAEbSWUhNkclp4pw4r97T
urhhIiarPZZDEkAXG1Ezi9I9ebmvdHMRRa/e9P95Xg7vwS04EHfmVTpFKF7UHncoI46I8za8vjyZ
8MCKLS5zKbgCU1OCJ9lQ6mJX1roD79pJrnKYpw==

`pragma protect key_keyowner="Mentor Graphics Corporation", key_keyname="MGC-PREC-RSA", key_method="rsa"
`pragma protect encoding = (enctype="base64", line_length=76, bytes=256)
`pragma protect key_block
nAe2yz38W+toa47teXFomvr0s3S7B/mFs08V3isJo/x2QJRmzNs0XiNhAEvzTYJSpHgqTw5IzrWq
0lW2CNEVEn7nULmMZObrv1Tk/gy3nFeX8Ug9HLfX3V0QEmN2QZnRlPTpZ/jWElW/FsfAJoYrx5LJ
sIxZdHBH8mVP5RDmHVxEmHwOvzooeFGzyIdb2cq+TFJgYLtVUJmRxsBQHVlr+7TJ6IEHuExkLnjb
DyPnQFol/m9w7rcWk3cb/6sFXTI6YQplz5+kSyKpS7Lps3HnWjvnazi+2lVjikgzUvslX1TRa0yw
nUwudxo+/x26UMbNYdlsh2j/uG9z1Syvtox0FA==

`pragma protect key_keyowner="Synplicity", key_keyname="SYNP15_1", key_method="rsa"
`pragma protect encoding = (enctype="base64", line_length=76, bytes=256)
`pragma protect key_block
N1k8yedDzpZ6fllDD0pjuyFR32LIzWu0hurCyNGDLYa54A72Vtquyp8/YG/imGN8eUS3qaFAbnQt
HO+JvKbL3XRIMX0HLPbSykuJLWcdylfV1Ig2EkYNure4uqUqBnMyb1awePUmWo5YG3EYQav0b7Vv
UwgYmhz6w7jdE6Q9aGaXNOQU9fpNHWZzUzVmubb11BEUnG8ORR378OV0X6IsnfXAdL1sSiX7lnvr
D0R2q3Gm++FbV0Bvbpd8qIM7YczP8pd4/Bv+Z2oE/HbpBSP6cec+u7loIai9KZctbIUojEkj1xNK
mMOeQzY7zLn4YvBt5h6JrGzuRduJ9F2RqBWrbA==

`pragma protect data_method = "AES128-CBC"
`pragma protect encoding = (enctype = "BASE64", line_length = 76, bytes = 8464)
`pragma protect data_block
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
6BS+RbThDmCJME8frwk5gh5Wr9y0WFltS0nQHg==
`pragma protect end_protected
`ifndef GLBL
`define GLBL
`timescale  1 ps / 1 ps

module glbl ();

    parameter ROC_WIDTH = 100000;
    parameter TOC_WIDTH = 0;

//--------   STARTUP Globals --------------
    wire GSR;
    wire GTS;
    wire GWE;
    wire PRLD;
    tri1 p_up_tmp;
    tri (weak1, strong0) PLL_LOCKG = p_up_tmp;

    wire PROGB_GLBL;
    wire CCLKO_GLBL;
    wire FCSBO_GLBL;
    wire [3:0] DO_GLBL;
    wire [3:0] DI_GLBL;
   
    reg GSR_int;
    reg GTS_int;
    reg PRLD_int;

//--------   JTAG Globals --------------
    wire JTAG_TDO_GLBL;
    wire JTAG_TCK_GLBL;
    wire JTAG_TDI_GLBL;
    wire JTAG_TMS_GLBL;
    wire JTAG_TRST_GLBL;

    reg JTAG_CAPTURE_GLBL;
    reg JTAG_RESET_GLBL;
    reg JTAG_SHIFT_GLBL;
    reg JTAG_UPDATE_GLBL;
    reg JTAG_RUNTEST_GLBL;

    reg JTAG_SEL1_GLBL = 0;
    reg JTAG_SEL2_GLBL = 0 ;
    reg JTAG_SEL3_GLBL = 0;
    reg JTAG_SEL4_GLBL = 0;

    reg JTAG_USER_TDO1_GLBL = 1'bz;
    reg JTAG_USER_TDO2_GLBL = 1'bz;
    reg JTAG_USER_TDO3_GLBL = 1'bz;
    reg JTAG_USER_TDO4_GLBL = 1'bz;

    assign (strong1, weak0) GSR = GSR_int;
    assign (strong1, weak0) GTS = GTS_int;
    assign (weak1, weak0) PRLD = PRLD_int;

    initial begin
	GSR_int = 1'b1;
	PRLD_int = 1'b1;
	#(ROC_WIDTH)
	GSR_int = 1'b0;
	PRLD_int = 1'b0;
    end

    initial begin
	GTS_int = 1'b1;
	#(TOC_WIDTH)
	GTS_int = 1'b0;
    end

endmodule
`endif
