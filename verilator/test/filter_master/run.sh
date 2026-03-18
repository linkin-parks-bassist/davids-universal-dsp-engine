#!/bin/bash
set -e

verilator -Wall --trace -Wno-fatal \
    --top-module filter_master \
    --cc ../../../src/*.v \
    -I../../../src -I../../../include \
    --exe sim_main.cpp tests.cpp \
    -CFLAGS "-fpermissive -Wno-error -DTRACE" \
    -LDFLAGS "-lm"

make -C obj_dir -f Vfilter_master.mk

./obj_dir/Vfilter_master
