`timescale 1ns/1ps

module score_ram #(
    parameter integer DEPTH = 64
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        score_begin,
    input  wire        event_valid,
    input  wire [2:0]  event_pitch,
    input  wire [15:0] event_duration,
    input  wire        score_end,
    input  wire [5:0]  rd_index,
    output wire [2:0]  rd_pitch,
    output wire [15:0] rd_duration,
    output reg         score_valid,
    output reg [15:0]  score_length
);
    reg [2:0] pitch_mem [0:DEPTH-1];
    reg [15:0] duration_mem [0:DEPTH-1];
    reg [15:0] write_index;
    integer j;

    assign rd_pitch = (rd_index < DEPTH) ? pitch_mem[rd_index] : 3'd0;
    assign rd_duration = (rd_index < DEPTH) ? duration_mem[rd_index] : 16'd0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_index <= 0;
            score_valid <= 1'b0;
            score_length <= 0;
        end else begin
            if (score_begin) begin
                write_index <= 0;
                score_valid <= 1'b0;
                score_length <= 0;
            end else begin
                if (event_valid && write_index < DEPTH) begin
                    pitch_mem[write_index] <= event_pitch;
                    duration_mem[write_index] <= event_duration;
                    write_index <= write_index + 1'b1;
                end
                if (score_end) begin
                    score_length <= write_index + (event_valid && write_index < DEPTH);
                    score_valid <= (write_index != 0) || event_valid;
                end
            end
        end
    end
endmodule
