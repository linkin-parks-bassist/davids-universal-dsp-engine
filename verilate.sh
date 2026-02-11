verilator  src/*.v \
	--top-module top  -Wno-fatal -Isrc -Iinclude -cc -CFLAGS -fpermissive -CFLAGS -Wno-error --trace-fst -exe verilator/sim_io.cpp verilator/sim_ctrl.cpp verilator/sim_main.cpp \
	&& make -C obj_dir -j -f Vtop.mk Vtop
