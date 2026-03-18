#include "test_framework.h"

static void drive_sample(Vhealth_monitor* dut, VerilatedVcdC* tfp, int sample)
{
    dut->sample_valid = 1;
    dut->sample_in = sample;
    tick(dut, tfp);
    dut->sample_valid = 0;
}

static void idle_cycle(Vhealth_monitor* dut, VerilatedVcdC* tfp)
{
    dut->sample_valid = 0;
    tick(dut, tfp);
}

static void reset_dut(Vhealth_monitor* dut, VerilatedVcdC* tfp)
{
    dut->enable = 1;
    dut->sample_valid = 0;
    dut->sample_in = 0;
    dut->reset = 1;
    for (int i = 0; i < 5; i++)
        tick(dut, tfp);
    dut->reset = 0;
}

TEST(reset_starts_healthy)
{
    reset_dut(dut, tfp);

    EXPECT_EQ(dut->health, 1);
    EXPECT_EQ(dut->peak_detect, 0);
    EXPECT_EQ(dut->envl_detect, 0);
}

TEST(normal_samples_do_not_trip_peak)
{
    reset_dut(dut, tfp);

    for (int i = 0; i < 20; i++) {
        drive_sample(dut, tfp, 1234);
        EXPECT_EQ(dut->peak_detect, 0);
        EXPECT_EQ(dut->health, 1);
    }
}

TEST(saturated_samples_trip_peak_detect)
{
    reset_dut(dut, tfp);

    // sat_max for data_width=16 is 32767
    for (int i = 0; i < 11; i++) {
        drive_sample(dut, tfp, 32767);
    }

    EXPECT_EQ(dut->peak_detect, 1);
    EXPECT_EQ(dut->health, 1);
}

TEST(saturated_samples_eventually_drop_health)
{
    reset_dut(dut, tfp);

    for (int i = 0; i < 12; i++) {
        drive_sample(dut, tfp, 32767);
    }

    EXPECT_EQ(dut->peak_detect, 1);
    EXPECT_EQ(dut->health, 0);
}

TEST(nonconsecutive_peaks_do_not_accumulate)
{
    reset_dut(dut, tfp);

    for (int burst = 0; burst < 3; burst++) {
        for (int i = 0; i < 5; i++) {
            drive_sample(dut, tfp, 32767);
        }

        drive_sample(dut, tfp, 1000);

        EXPECT_EQ(dut->peak_detect, 0);
        EXPECT_EQ(dut->health, 1);
    }
}

TEST(enable_gates_peak_logic)
{
    reset_dut(dut, tfp);

    dut->enable = 0;

    for (int i = 0; i < 20; i++) {
        drive_sample(dut, tfp, 32767);
    }

    EXPECT_EQ(dut->peak_detect, 0);
    EXPECT_EQ(dut->health, 1);

    dut->enable = 1;
}

TEST(reset_recovers_health_after_peak_failure)
{
    reset_dut(dut, tfp);

    for (int i = 0; i < 12; i++) {
        drive_sample(dut, tfp, 32767);
    }

    EXPECT_EQ(dut->health, 0);

    reset_dut(dut, tfp);

    EXPECT_EQ(dut->health, 1);
    EXPECT_EQ(dut->peak_detect, 0);
}
