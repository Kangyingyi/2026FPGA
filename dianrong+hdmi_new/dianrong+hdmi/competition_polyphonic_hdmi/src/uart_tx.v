`timescale 1ns/1ps

// 8N1 UART transmitter. The default divider gives approximately 115200 baud
// from the 50 MHz system clock (50,000,000 / 434 = 115207 baud).
module uart_tx #(
    parameter integer CLKS_PER_BIT = 434
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tx_start,
    input  wire [7:0] tx_data,
    output reg        tx,
    output reg        busy
);

    localparam integer COUNT_W = (CLKS_PER_BIT <= 2) ? 1 : $clog2(CLKS_PER_BIT);
    reg [COUNT_W-1:0] baud_count;
    reg [3:0]         bit_index;
    reg [7:0]         data_latched;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_count   <= {COUNT_W{1'b0}};
            bit_index    <= 4'd0;
            data_latched <= 8'h00;
            tx           <= 1'b1;
            busy         <= 1'b0;
        end else if (!busy) begin
            tx <= 1'b1;
            if (tx_start) begin
                data_latched <= tx_data;
                baud_count   <= {COUNT_W{1'b0}};
                bit_index    <= 4'd0;
                tx           <= 1'b0;
                busy         <= 1'b1;
            end
        end else if (baud_count == CLKS_PER_BIT - 1) begin
            baud_count <= {COUNT_W{1'b0}};
            if (bit_index < 4'd8) begin
                tx        <= data_latched[bit_index];
                bit_index <= bit_index + 4'd1;
            end else begin
                tx   <= 1'b1;
                busy <= 1'b0;
            end
        end else begin
            baud_count <= baud_count + 1'b1;
        end
    end

endmodule
