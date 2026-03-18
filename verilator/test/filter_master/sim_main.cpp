#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vfilter_master.h"
#include "test_framework.h"

std::vector<Test>& get_tests()
{
    static std::vector<Test> tests;
    return tests;
}

static vluint64_t sim_time = 0;
double sc_time_stamp() { return sim_time; }

void tick(Vfilter_master* dut, VerilatedVcdC* tfp)
{
    dut->clk = 1;
    dut->eval();
    if (tfp) tfp->dump(sim_time++);

    dut->clk = 0;
    dut->eval();
    if (tfp) tfp->dump(sim_time++);
}

int main(int argc, char** argv)
{
    Verilated::commandArgs(argc, argv);

    Vfilter_master* dut = new Vfilter_master;

    dut->clk = 0;
    dut->reset = 0;

    VerilatedVcdC* tfp = nullptr;

#ifdef TRACE
    Verilated::traceEverOn(true);
#endif

    auto& tests = get_tests();

    for (auto& t : tests) {
        printf("=== %s ===\n", t.name);

#ifdef TRACE
        tfp = new VerilatedVcdC;

        char fname[256];
        snprintf(fname, sizeof(fname), "%s.vcd", t.name);

        dut->trace(tfp, 99);
        tfp->open(fname);
#endif

        sim_time = 0;

        dut->reset = 1;
        for (int i = 0; i < 5; i++) tick(dut, tfp);
        dut->reset = 0;

        t.fn(dut, tfp);

#ifdef TRACE
        tfp->close();
        delete tfp;
        tfp = nullptr;
#endif
    }

    printf("All tests passed.\n");

    delete dut;
    return 0;
}
