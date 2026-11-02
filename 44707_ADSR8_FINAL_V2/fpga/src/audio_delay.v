`timescale 1ns/1ps

// Adapted from the user's delay.zip (delay/src/audio_delay.v).
// A ~200 ms repeating echo: 1/2 delayed signal in the output and
// 5/8 delayed signal in the delay line, including its quiet gate.
module audio_delay #(
    parameter integer DEPTH = 9766,
    parameter integer PTR_W = 14
) (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               sample_tick,
    input  wire               enable,
    input  wire signed [15:0] audio_in,
    output reg  signed [15:0] audio_out
);
    (* ram_style = "block" *) reg signed [15:0] ram [0:DEPTH-1];
    reg [PTR_W-1:0] wr_ptr, fill_count;
    reg signed [15:0] delayed_sample;
    wire [PTR_W-1:0] rd_ptr = (wr_ptr == DEPTH - 1) ?
                              {PTR_W{1'b0}} : wr_ptr + 1'b1;
    wire echo_valid = (fill_count == DEPTH);
    wire signed [18:0] dry = {{3{audio_in[15]}}, audio_in};
    wire signed [18:0] delayed = {{3{delayed_sample[15]}}, delayed_sample};
    wire signed [18:0] sum = dry + (echo_valid ? (delayed >>> 1) : 19'sd0);
    wire signed [18:0] write_value = dry +
                                    (echo_valid ? ((delayed >>> 1) + (delayed >>> 3)) : 19'sd0);
    wire signed [15:0] feedback_pcm = (write_value > 19'sd32767) ? 16'sh7fff :
                                      (write_value < -19'sd32768) ? 16'sh8000 :
                                      write_value[15:0];

    // Read the following address so block RAM never reads and writes the
    // same location. At the next sample, this is one ring traversal old.
    always @(posedge clk) begin
        if (sample_tick && enable) begin
            delayed_sample <= ram[rd_ptr];
            ram[wr_ptr] <= feedback_pcm;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
            fill_count <= 0;
            audio_out <= 0;
        end else if (!enable) begin
            wr_ptr <= 0;
            fill_count <= 0;
            audio_out <= 0;
        end else if (sample_tick) begin
            wr_ptr <= (wr_ptr == DEPTH - 1) ? 0 : wr_ptr + 1'b1;
            if (!echo_valid) fill_count <= fill_count + 1'b1;
            if (sum > 19'sd32767) audio_out <= 16'sh7fff;
            else if (sum < -19'sd32768) audio_out <= 16'sh8000;
            else if (sum < 19'sd24 && sum > -19'sd24) audio_out <= 0;
            else audio_out <= sum[15:0];
        end
    end
endmodule
