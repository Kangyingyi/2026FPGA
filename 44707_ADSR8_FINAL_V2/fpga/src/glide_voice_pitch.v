`timescale 1ns/1ps

// One note begins below its nominal pitch, then slides linearly to 0 offset.
// Q8 fractional state makes the sub-Q15-per-sample ramp audible and smooth.
module glide_voice_pitch #(
    parameter signed [15:0] START_OFFSET_Q15 = -16'sd3577,
    parameter integer RAMP_STEP_Q8 = 153
) (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               sample_tick,
    input  wire               key_active,
    output wire signed [15:0] offset_q15
);
    localparam signed [23:0] START_Q8 = {START_OFFSET_Q15, 8'b0};
    localparam signed [23:0] STEP_Q8 = RAMP_STEP_Q8;

    reg signed [23:0] offset_q8;
    reg was_active;
    wire signed [23:0] next_q8 = offset_q8 + STEP_Q8;

    assign offset_q15 = offset_q8[23:8];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            offset_q8 <= 24'sd0;
            was_active <= 1'b0;
        end else if (sample_tick) begin
            if (!key_active) begin
                offset_q8 <= 24'sd0;
                was_active <= 1'b0;
            end else if (!was_active) begin
                offset_q8 <= START_Q8;
                was_active <= 1'b1;
            end else if (offset_q8 < 24'sd0) begin
                offset_q8 <= (next_q8 >= 24'sd0) ? 24'sd0 : next_q8;
            end
        end
    end
endmodule
