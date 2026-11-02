`timescale 1ns/1ps

// 1280x720@60Hz timing for a 74.25 MHz pixel clock.
module video_timing_720p (
    input  wire        clk,
    input  wire        rst_n,
    output wire        hs,
    output wire        vs,
    output wire        de,
    output wire [11:0] x,
    output wire [10:0] y
);
    localparam integer H_ACTIVE = 1280;
    localparam integer H_FP     = 110;
    localparam integer H_SYNC   = 40;
    localparam integer H_BP     = 220;
    localparam integer H_TOTAL  = 1650;
    localparam integer V_ACTIVE = 720;
    localparam integer V_FP     = 5;
    localparam integer V_SYNC   = 5;
    localparam integer V_BP     = 20;
    localparam integer V_TOTAL  = 750;

    reg [11:0] h_count;
    reg [10:0] v_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h_count <= 12'd0;
            v_count <= 11'd0;
        end else if (h_count == H_TOTAL - 1) begin
            h_count <= 12'd0;
            if (v_count == V_TOTAL - 1)
                v_count <= 11'd0;
            else
                v_count <= v_count + 11'd1;
        end else begin
            h_count <= h_count + 12'd1;
        end
    end

    assign de = rst_n && (h_count < H_ACTIVE) && (v_count < V_ACTIVE);
    assign hs = rst_n && (h_count >= H_ACTIVE + H_FP) &&
                (h_count < H_ACTIVE + H_FP + H_SYNC);
    assign vs = rst_n && (v_count >= V_ACTIVE + V_FP) &&
                (v_count < V_ACTIVE + V_FP + V_SYNC);
    assign x = h_count;
    assign y = v_count;
endmodule
