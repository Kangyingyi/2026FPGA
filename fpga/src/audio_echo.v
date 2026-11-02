`timescale 1ns/1ps
// FPGA HDL echo effect: dry signal plus a delayed copy with feedback.
// At the 48.8 kHz sample rate, DEPTH=14648 is approximately 300 ms.
module audio_echo #(
    parameter integer DEPTH = 14648,
    parameter integer PTR_W = 14
)(
    input  wire clk,
    input  wire rst_n,
    input  wire sample_tick,
    input  wire signed [15:0] audio_in,
    output reg  signed [15:0] audio_out
);
    (* ram_style = "block" *) reg signed [15:0] ram [0:DEPTH-1];
    reg [PTR_W-1:0] wr_ptr;
    reg [PTR_W-1:0] fill_count;
    reg signed [15:0] delayed_sample;
    reg signed [19:0] mix_value;
    reg signed [19:0] feedback_value;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr         <= 0;
            fill_count     <= 0;
            delayed_sample <= 0;
            mix_value      <= 0;
            feedback_value <= 0;
            audio_out      <= 0;
        end else if (sample_tick) begin
            // Read the sample at the delay tap before overwriting this location.
            delayed_sample <= ram[(wr_ptr == DEPTH-1) ? 0 : wr_ptr + 1'b1];

            if (fill_count < DEPTH) begin
                // Do not expose uninitialized RAM during startup.
                mix_value      = {{4{audio_in[15]}}, audio_in};
                feedback_value = {{4{audio_in[15]}}, audio_in};
                fill_count     <= fill_count + 1'b1;
            end else begin
                // Echo output: dry + 1/2 delayed. The delay line stores
                // dry + 1/2 delayed, creating progressively quieter repeats.
                mix_value      = {{4{audio_in[15]}}, audio_in} +
                                 ({{4{delayed_sample[15]}}, delayed_sample} >>> 1);
                feedback_value = {{4{audio_in[15]}}, audio_in} +
                                 ({{4{delayed_sample[15]}}, delayed_sample} >>> 1);
            end

            if (mix_value > 20'sd32767)
                audio_out <= 16'sh7fff;
            else if (mix_value < -20'sd32768)
                audio_out <= -16'sh8000;
            else if ((mix_value < 20'sd20) && (mix_value > -20'sd20))
                audio_out <= 16'sd0;
            else
                audio_out <= mix_value[15:0];

            if (feedback_value > 20'sd32767)
                ram[wr_ptr] <= 16'sh7fff;
            else if (feedback_value < -20'sd32768)
                ram[wr_ptr] <= -16'sh8000;
            else
                ram[wr_ptr] <= feedback_value[15:0];

            if (wr_ptr == DEPTH-1)
                wr_ptr <= 0;
            else
                wr_ptr <= wr_ptr + 1'b1;
        end
    end
endmodule
