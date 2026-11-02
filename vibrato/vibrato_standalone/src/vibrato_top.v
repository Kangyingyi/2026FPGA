`timescale 1ns/1ps

// Standalone TTP226 -> 8-voice vibrato synth -> stereo I2S demonstrator.
module vibrato_top #(
    parameter integer DEBOUNCE_CYCLES = 250000,
    parameter [3:0] VIBRATO_RATE_HZ = 4'd5,
    parameter [10:0] VIBRATO_DEPTH_Q15 = 11'd1024
) (
    input  wire       sys_clk,
    input  wire       rst_n,
    input  wire [7:0] key_in,
    output wire       I2S_BCLK,
    output wire       I2S_LRCK,
    output wire       I2S_DIN,
    output wire       PA_EN
);
    wire [7:0] key_state;
    wire signed [15:0] audio_sample;
    wire sample_tick;

    key_filter_8 #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES), .ACTIVE_LOW(0)) keys (
        .clk(sys_clk), .rst_n(rst_n), .key_in(key_in),
        .key_state(key_state), .key_pressed()
    );

    vibrato_dds #(
        .RATE_HZ(VIBRATO_RATE_HZ),
        .DEPTH_Q15(VIBRATO_DEPTH_Q15)
    ) synth (
        .clk(sys_clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .key_state(key_state), .sample(audio_sample)
    );

    i2s_tx tx (
        .clk(sys_clk), .rst_n(rst_n),
        .sample_l(audio_sample), .sample_r(audio_sample),
        .i2s_bclk(I2S_BCLK), .i2s_lrck(I2S_LRCK),
        .i2s_din(I2S_DIN), .sample_tick(sample_tick)
    );

    assign PA_EN = 1'b0;
endmodule
