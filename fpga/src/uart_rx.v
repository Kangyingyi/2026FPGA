`timescale 1ns/1ps

module uart_rx #(
    parameter integer CLKS_PER_BIT = 5208
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx,
    input  wire       data_ready,
    output reg [7:0]  data_out,
    output reg        data_valid,
    output reg        overrun,
    output reg        framing_error
);
    localparam integer COUNT_W = (CLKS_PER_BIT <= 2) ? 2 : $clog2(CLKS_PER_BIT);
    localparam integer HALF_BIT = (CLKS_PER_BIT / 2);
    localparam [1:0] IDLE = 2'd0, START = 2'd1, DATA = 2'd2, STOP = 2'd3;
    reg [1:0] state;
    reg [COUNT_W:0] clk_count;
    reg [2:0] bit_count;
    reg [7:0] shift_data;
    reg rx_meta, rx_sync;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_meta        <= 1'b1;
            rx_sync        <= 1'b1;
            state          <= IDLE;
            clk_count      <= 0;
            bit_count      <= 0;
            shift_data     <= 0;
            data_out       <= 0;
            data_valid     <= 1'b0;
            overrun        <= 1'b0;
            framing_error  <= 1'b0;
        end else begin
            rx_meta       <= rx;
            rx_sync       <= rx_meta;
            data_valid   <= 1'b0;
            overrun      <= 1'b0;
            framing_error <= 1'b0;

            case (state)
                IDLE: begin
                    clk_count <= 0;
                    bit_count <= 0;
                    if (!rx_sync) state <= START;
                end
                START: begin
                    if (clk_count == HALF_BIT - 1) begin
                        clk_count <= 0;
                        if (!rx_sync) state <= DATA;
                        else state <= IDLE;
                    end else clk_count <= clk_count + 1'b1;
                end
                DATA: begin
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= 0;
                        shift_data[bit_count] <= rx_sync;
                        if (bit_count == 3'd7) state <= STOP;
                        else bit_count <= bit_count + 1'b1;
                    end else clk_count <= clk_count + 1'b1;
                end
                STOP: begin
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= 0;
                        state <= IDLE;
                        if (!rx_sync) begin
                            framing_error <= 1'b1;
                        end else if (data_valid && !data_ready) begin
                            overrun <= 1'b1;
                        end else begin
                            data_out   <= shift_data;
                            data_valid <= 1'b1;
                        end
                    end else clk_count <= clk_count + 1'b1;
                end
                default: state <= IDLE;
            endcase

            if (data_valid && data_ready) data_valid <= 1'b0;
        end
    end
endmodule
