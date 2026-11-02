`timescale 1ns/1ps

module expressive_osc (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        sample_tick,
    input  wire        trigger,
    input  wire [2:0]  tone,
    input  wire [31:0] phase,
    output wire signed [15:0] sample
);
    wire signed [15:0] raw;
    timbre_rom rom(.phase(phase), .tone(tone), .value(raw));
    assign sample = raw;
endmodule
