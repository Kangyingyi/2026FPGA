`timescale 1ns/1ps

module guide_controller (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0]  key_pressed,
    input  wire        score_valid,
    input  wire [15:0] score_length,
    output reg  [5:0]  rd_index,
    input  wire [2:0]  rd_pitch,
    input  wire        score_begin,
    input  wire        score_event_valid,
    input  wire        score_end,
    input  wire        guide_start,
    input  wire        guide_stop,
    output reg         guide_active,
    output reg [2:0]   target_pitch
);
    reg loading_target;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_index      <= 0;
            guide_active  <= 1'b0;
            target_pitch  <= 0;
            loading_target <= 1'b0;
        end else if (guide_stop || score_begin) begin
            rd_index      <= 0;
            guide_active  <= 1'b0;
            loading_target <= 1'b0;
        end else if (guide_start && score_valid && score_length != 0) begin
            rd_index      <= 0;
            target_pitch  <= rd_pitch;
            guide_active  <= 1'b1;
            loading_target <= 1'b0;
        end else if (guide_active) begin
            if (loading_target) begin
                target_pitch <= rd_pitch;
                loading_target <= 1'b0;
            end else if (key_pressed[target_pitch]) begin
                if (rd_index + 1 >= score_length) begin
                    guide_active <= 1'b0;
                end else begin
                    rd_index <= rd_index + 1'b1;
                    loading_target <= 1'b1;
                end
            end
        end
    end
endmodule
