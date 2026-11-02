`timescale 1ns/1ps

module uart_tx #(
    parameter integer CLKS_PER_BIT = 5208
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] data_in,
    input  wire       data_valid,
    output reg        tx,
    output reg        busy
);
    localparam integer COUNT_W = (CLKS_PER_BIT <= 2) ? 2 : $clog2(CLKS_PER_BIT);
    reg [COUNT_W:0] clk_count;
    reg [3:0] bit_count;
    reg [7:0] data_hold;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx        <= 1'b1;
            busy      <= 1'b0;
            clk_count <= 0;
            bit_count <= 0;
            data_hold <= 0;
        end else if (!busy) begin
            tx        <= 1'b1;
            clk_count <= 0;
            bit_count <= 0;
            if (data_valid) begin
                data_hold <= data_in;
                busy      <= 1'b1;
                tx        <= 1'b0;
            end
        end else if (clk_count == CLKS_PER_BIT - 1) begin
            clk_count <= 0;
            if (bit_count == 4'd9) begin
                busy <= 1'b0;
                tx   <= 1'b1;
            end else begin
                bit_count <= bit_count + 1'b1;
                case (bit_count)
                    4'd0: tx <= data_hold[0];
                    4'd1: tx <= data_hold[1];
                    4'd2: tx <= data_hold[2];
                    4'd3: tx <= data_hold[3];
                    4'd4: tx <= data_hold[4];
                    4'd5: tx <= data_hold[5];
                    4'd6: tx <= data_hold[6];
                    4'd7: tx <= data_hold[7];
                    default: tx <= 1'b1;
                endcase
            end
        end else begin
            clk_count <= clk_count + 1'b1;
        end
    end
endmodule
