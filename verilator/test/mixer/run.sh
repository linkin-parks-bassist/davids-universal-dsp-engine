#!/bin/bash
set -e

verilator -Wall --trace -Wno-fatal \
    --top-module mixer \
    --cc ../../../src/*.v \
    -I../../../src -I../../../include \
    --exe sim_main.cpp tests.cpp \
    -CFLAGS "-fpermissive -Wno-error -DTRACE" \
    -LDFLAGS "-lm"

make -C obj_dir -f Vmixer.mk

./obj_dir/Vmixer
