//Copyright (C)2014-2026 GOWIN Semiconductor Corporation.
//All rights reserved.
//File Title: Timing Constraints file
//Tool Version: V1.9.12 (64-bit) 
//Created Time: 2026-01-22 09:09:19
create_clock -name SYS_CLK -period 8.889 -waveform {0 4.444} [get_nets {sys_clk}]
create_clock -name Crystal -period 37.037 -waveform {0 18.518} [get_ports {crystal}]
report_timing -setup -max_paths 200 -max_common_paths 1