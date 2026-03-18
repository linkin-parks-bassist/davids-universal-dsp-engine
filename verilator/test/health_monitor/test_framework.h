#pragma once

#include <vector>
#include <functional>
#include <cstdio>
#include <cstdlib>

#include "Vhealth_monitor.h"
#include <verilated_vcd_c.h>

struct Test {
    const char* name;
    std::function<void(Vhealth_monitor*, VerilatedVcdC*)> fn;
};

std::vector<Test>& get_tests();

#define TEST(name) \
    void name(Vhealth_monitor*, VerilatedVcdC*); \
    struct name##_registrar { \
        name##_registrar() { \
            get_tests().push_back({#name, name}); \
        } \
    } name##_registrar_instance; \
    void name(Vhealth_monitor* dut, VerilatedVcdC* tfp)

#define EXPECT_EQ(a,b) \
    if ((a)!=(b)) { \
        printf("FAIL: %s != %s (got %d expected %d)\n", #a, #b, (int)(a), (int)(b)); \
        exit(1); \
    }

#define EXPECT_NE(a,b) \
    if ((a)==(b)) { \
        printf("FAIL: %s == %s (both %d, expected different)\n", #a, #b, (int)(a)); \
        exit(1); \
    }

extern void tick(Vhealth_monitor* dut, VerilatedVcdC* tfp);
