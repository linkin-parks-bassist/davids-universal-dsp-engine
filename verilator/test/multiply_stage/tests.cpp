#include "test_framework.h"

#define COMMIT_ID_WIDTH 4

static void reset_dut(Vmultiply_stage* dut, VerilatedVcdC* tfp)
{
    dut->enable = 1;
    dut->in_valid = 0;
    dut->out_ready = 0;

    dut->block_in = 0;
    dut->shift_in = 0;
    dut->shift_disable_in = 0;
    dut->signedness_in = 0;
    dut->saturate_disable_in = 0;
    dut->arg_a_in = 0;
    dut->arg_b_in = 0;
    dut->arg_c_in = 0;
    dut->dest_in = 0;
    dut->commit_id_in = 0;
    dut->commit_flag_in = 0;

    dut->reset = 1;
    for (int i = 0; i < 5; i++)
        tick(dut, tfp);
    dut->reset = 0;
    settle(dut, tfp);
}

static void drive_input(
    Vmultiply_stage* dut,
    int block,
    int shift,
    int shift_disable,
    int signedness,
    int saturate_disable,
    int arg_a,
    int arg_b,
    int arg_c,
    int dest,
    int commit_id,
    int commit_flag)
{
    dut->block_in = block;
    dut->shift_in = shift;
    dut->shift_disable_in = shift_disable;
    dut->signedness_in = signedness;
    dut->saturate_disable_in = saturate_disable;
    dut->arg_a_in = arg_a;
    dut->arg_b_in = arg_b;
    dut->arg_c_in = arg_c;
    dut->dest_in = dest;
    dut->commit_id_in = commit_id;
    dut->commit_flag_in = commit_flag;
}

static void expect_output(
    Vmultiply_stage* dut,
    int out_valid,
    int block,
    int shift,
    int shift_disable,
    int signedness,
    int saturate_disable,
    long long product,
    int arg_c,
    int dest,
    int commit_id,
    int commit_flag)
{
    EXPECT_EQ(dut->out_valid, out_valid);
    EXPECT_U(8,  dut->block_out, block);
    EXPECT_U(5,  dut->shift_out, shift);
    EXPECT_EQ(dut->shift_disable_out, shift_disable);
    EXPECT_EQ(dut->signedness_out, signedness);
    EXPECT_EQ(dut->saturate_disable_out, saturate_disable);
    EXPECT_S(40, dut->product_out, product);
    EXPECT_S(16, dut->arg_c_out, arg_c);
    EXPECT_U(4,  dut->dest_out, dest);
    EXPECT_U(COMMIT_ID_WIDTH, dut->commit_id_out, commit_id);
    EXPECT_EQ(dut->commit_flag_out, commit_flag);
}

TEST(reset_clears_valid_and_makes_input_ready)
{
    reset_dut(dut, tfp);

    EXPECT_EQ(dut->out_valid, 0);
    EXPECT_EQ(dut->in_ready, 1);
}

TEST(basic_unsigned_multiply_and_metadata_forwarding)
{
    reset_dut(dut, tfp);

    dut->out_ready = 0;
    dut->in_valid = 1;
    drive_input(dut, 17, 5, 1, 0, 1, 3, 7, 1234, 9, 6, 1);
    settle(dut, tfp);

    EXPECT_EQ(dut->in_ready, 1);

    tick(dut, tfp);

    dut->in_valid = 0;
    settle(dut, tfp);

    expect_output(dut, 1, 17, 5, 1, 0, 1, 21, 1234, 9, 6, 1);
    EXPECT_EQ(dut->in_ready, 0);
}

TEST(basic_signed_multiply_negative_result)
{
    reset_dut(dut, tfp);

    dut->out_ready = 0;
    dut->in_valid = 1;
    drive_input(dut, 3, 2, 0, 1, 0, -3, 7, -11, 4, 5, 0);
    settle(dut, tfp);

    tick(dut, tfp);

    dut->in_valid = 0;
    settle(dut, tfp);

    expect_output(dut, 1, 3, 2, 0, 1, 0, -21, -11, 4, 5, 0);
}

TEST(basic_signed_multiply_two_negatives)
{
    reset_dut(dut, tfp);

    dut->out_ready = 0;
    dut->in_valid = 1;
    drive_input(dut, 8, 1, 0, 1, 1, -3, -4, 77, 2, 10, 1);
    settle(dut, tfp);

    tick(dut, tfp);

    dut->in_valid = 0;
    settle(dut, tfp);

    expect_output(dut, 1, 8, 1, 0, 1, 1, 12, 77, 2, 10, 1);
}

TEST(stall_holds_output_stable)
{
    reset_dut(dut, tfp);

    dut->out_ready = 0;
    dut->in_valid = 1;
    drive_input(dut, 21, 4, 1, 0, 0, 12, 13, 999, 7, 14, 1);
    settle(dut, tfp);

    tick(dut, tfp);

    dut->in_valid = 0;
    settle(dut, tfp);

    expect_output(dut, 1, 21, 4, 1, 0, 0, 156, 999, 7, 14, 1);
    EXPECT_EQ(dut->in_ready, 0);

    for (int i = 0; i < 3; i++) {
        drive_input(dut, 99, 31, 0, 1, 1, -8, 5, 111, 15, 3, 0);
        settle(dut, tfp);
        tick(dut, tfp);
        settle(dut, tfp);

        expect_output(dut, 1, 21, 4, 1, 0, 0, 156, 999, 7, 14, 1);
        EXPECT_EQ(dut->in_ready, 0);
    }
}

TEST(drain_clears_valid_when_no_new_input_arrives)
{
    reset_dut(dut, tfp);

    dut->out_ready = 0;
    dut->in_valid = 1;
    drive_input(dut, 2, 3, 0, 0, 1, 6, 7, 88, 1, 12, 0);
    settle(dut, tfp);

    tick(dut, tfp);

    dut->in_valid = 0;
    settle(dut, tfp);

    expect_output(dut, 1, 2, 3, 0, 0, 1, 42, 88, 1, 12, 0);

    dut->out_ready = 1;
    settle(dut, tfp);
    EXPECT_EQ(dut->in_ready, 1);

    tick(dut, tfp);
    settle(dut, tfp);

    EXPECT_EQ(dut->out_valid, 0);
    EXPECT_EQ(dut->in_ready, 1);
}

TEST(simultaneous_drain_and_accept_replaces_output_immediately)
{
    reset_dut(dut, tfp);

    dut->out_ready = 0;
    dut->in_valid = 1;
    drive_input(dut, 10, 1, 0, 0, 0, 2, 9, 100, 3, 4, 0);
    settle(dut, tfp);

    tick(dut, tfp);

    dut->in_valid = 0;
    settle(dut, tfp);

    expect_output(dut, 1, 10, 1, 0, 0, 0, 18, 100, 3, 4, 0);
    EXPECT_EQ(dut->in_ready, 0);

    dut->out_ready = 1;
    dut->in_valid = 1;
    drive_input(dut, 11, 7, 1, 1, 1, -5, 6, -22, 8, 15, 1);
    settle(dut, tfp);

    EXPECT_EQ(dut->in_ready, 1);

    tick(dut, tfp);

    dut->in_valid = 0;
    settle(dut, tfp);

    expect_output(dut, 1, 11, 7, 1, 1, 1, -30, -22, 8, 15, 1);
}

TEST(enable_low_freezes_state)
{
    reset_dut(dut, tfp);

    dut->out_ready = 0;
    dut->in_valid = 1;
    drive_input(dut, 12, 6, 1, 0, 1, 4, 5, 33, 2, 9, 1);
    settle(dut, tfp);

    tick(dut, tfp);

    dut->in_valid = 0;
    settle(dut, tfp);

    expect_output(dut, 1, 12, 6, 1, 0, 1, 20, 33, 2, 9, 1);

    dut->enable = 0;
    dut->out_ready = 1;
    dut->in_valid = 1;
    drive_input(dut, 99, 31, 0, 1, 0, -7, -8, 44, 15, 1, 0);
    settle(dut, tfp);

    for (int i = 0; i < 3; i++) {
        tick(dut, tfp);
        settle(dut, tfp);
        expect_output(dut, 1, 12, 6, 1, 0, 1, 20, 33, 2, 9, 1);
    }

    dut->enable = 1;
    dut->in_valid = 0;
    settle(dut, tfp);
}

TEST(unsigned_mode_treats_negative_bit_patterns_as_unsigned)
{
    reset_dut(dut, tfp);

    dut->out_ready = 0;
    dut->in_valid = 1;
    drive_input(dut, 5, 0, 0, 0, 0, -1, 2, 0, 0, 0, 0);
    settle(dut, tfp);

    tick(dut, tfp);

    dut->in_valid = 0;
    settle(dut, tfp);

    expect_output(dut, 1, 5, 0, 0, 0, 0, 131070, 0, 0, 0, 0);
}

TEST(signed_mode_treats_negative_bit_patterns_as_signed)
{
    reset_dut(dut, tfp);

    dut->out_ready = 0;
    dut->in_valid = 1;
    drive_input(dut, 5, 0, 0, 1, 0, -1, 2, 0, 0, 0, 0);
    settle(dut, tfp);

    tick(dut, tfp);

    dut->in_valid = 0;
    settle(dut, tfp);

    expect_output(dut, 1, 5, 0, 0, 1, 0, -2, 0, 0, 0, 0);
}
