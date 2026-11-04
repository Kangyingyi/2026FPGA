`timescale 1ns/1ps

module record_sampler #(
    parameter integer AUDIO_HZ = 48828,
    parameter integer RECORD_HZ = 8000
) (
    input  wire              clk,
    input  wire              rst_n,
    input  wire              sample_tick,
    input  wire              record_enable,
    input  wire signed [15:0] audio_sample,
    output reg               pcm_valid,
    output reg signed [7:0]  pcm_sample
);
    integer accumulator;
    reg previous_enable;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            accumulator <= 0;
            previous_enable <= 1'b0;
            pcm_valid <= 1'b0;
            pcm_sample <= 0;
        end else begin
            pcm_valid <= 1'b0;
            previous_enable <= record_enable;
            if (!record_enable) begin
                accumulator <= 0;
            end else if (sample_tick) begin
                if (!previous_enable) begin
                    accumulator <= 0;
                end else if (accumulator + RECORD_HZ >= AUDIO_HZ) begin
                    accumulator <= accumulator + RECORD_HZ - AUDIO_HZ;
                    pcm_sample <= audio_sample[15:8];
                    pcm_valid <= 1'b1;
                end else begin
                    accumulator <= accumulator + RECORD_HZ;
                end
            end
        end
    end
endmodule
