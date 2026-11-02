`timescale 1ns/1ps

module key_filter_8 #(
    parameter integer DEBOUNCE_CYCLES = 250000,
    parameter integer ACTIVE_LOW = 1
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] key_in,
    output reg  [7:0] key_state,
    output reg  [7:0] key_pressed
);
    reg [7:0] sync_meta, sync_key;
    reg [31:0] counters [0:7];
    wire [7:0] candidate = ACTIVE_LOW ? ~sync_key : sync_key;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync_meta  <= 8'hFF;
            sync_key   <= 8'hFF;
            key_state  <= 8'h00;
            key_pressed <= 8'h00;
            for (i = 0; i < 8; i = i + 1) counters[i] <= 0;
        end else begin
            sync_meta   <= key_in;
            sync_key    <= sync_meta;
            key_pressed <= 8'h00;
            for (i = 0; i < 8; i = i + 1) begin
                if (candidate[i] != key_state[i]) begin
                    if (counters[i] >= DEBOUNCE_CYCLES - 1) begin
                        key_state[i] <= candidate[i];
                        counters[i] <= 0;
                        if (candidate[i]) key_pressed[i] <= 1'b1;
                    end else counters[i] <= counters[i] + 1'b1;
                end else counters[i] <= 0;
            end
        end
    end
endmodule
