`timescale 1ns/1ps

// TTP226 -> single-voice Legato pitch glide -> stereo Philips I2S.
module legato_top #(
    parameter integer DEBOUNCE_CYCLES = 250000,
    parameter integer SLIDE_SAMPLES = 14648
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
    wire active;
    wire [31:0] step;
    wire signed [15:0] audio_sample;
    wire sample_tick;

    key_filter_8 #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)) keys (
        .clk(sys_clk), .rst_n(rst_n), .key_in(key_in),
        .key_state(key_state), .key_pressed()
    );

    legato_pitch #(.SLIDE_SAMPLES(SLIDE_SAMPLES)) pitch (
        .clk(sys_clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .key_state(key_state), .active(active), .step(step)
    );

    legato_dds synth (
        .clk(sys_clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .active(active), .step(step), .sample(audio_sample)
    );

    i2s_tx tx (
        .clk(sys_clk), .rst_n(rst_n),
        .sample_l(audio_sample), .sample_r(audio_sample),
        .i2s_bclk(I2S_BCLK), .i2s_lrck(I2S_LRCK),
        .i2s_din(I2S_DIN), .sample_tick(sample_tick)
    );

    assign PA_EN = 1'b0;
endmodule
