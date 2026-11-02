`timescale 1ns/1ps

// 8 路数字输入同步、稳定状态和上升沿事件输出。
// 默认输入为高有效：TTP226 直接模式下未触摸为 0，触摸为 1。
module key_filter_8 #(
    parameter integer DEBOUNCE_CYCLES = 250000,
    parameter integer ACTIVE_LOW = 0
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] key_in,
    output reg  [7:0] key_state,
    output reg  [7:0] key_pressed
);
    localparam integer COUNT_W = (DEBOUNCE_CYCLES <= 1) ? 1 : $clog2(DEBOUNCE_CYCLES);
    reg [7:0] sync_ff1;
    reg [7:0] sync_ff2;
    reg [7:0] candidate;
    reg [COUNT_W-1:0] count;
    wire [7:0] pressed_level = ACTIVE_LOW ? ~sync_ff2 : sync_ff2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync_ff1   <= 8'h00;
            sync_ff2   <= 8'h00;
            candidate  <= 8'h00;
            count      <= {COUNT_W{1'b0}};
            key_state  <= 8'h00;
            key_pressed <= 8'h00;
        end else begin
            sync_ff1 <= key_in;
            sync_ff2 <= sync_ff1;
            key_pressed <= 8'h00;

            if (pressed_level != candidate) begin
                candidate <= pressed_level;
                count <= {COUNT_W{1'b0}};
            end else if (candidate != key_state) begin
                if (DEBOUNCE_CYCLES <= 1 || count == DEBOUNCE_CYCLES - 1) begin
                    key_pressed <= candidate & ~key_state;
                    key_state <= candidate;
                    count <= {COUNT_W{1'b0}};
                end else begin
                    count <= count + 1'b1;
                end
            end else begin
                count <= {COUNT_W{1'b0}};
            end
        end
    end
endmodule
