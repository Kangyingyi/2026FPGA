`timescale 1ns/1ps

// Independent high-active TTP226 input synchronizers and debouncers.
module key_filter_8 #(
    parameter integer DEBOUNCE_CYCLES = 250000
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
    reg [COUNT_W-1:0] count [0:7];

    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin: channel
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    sync_ff1[i]   <= 1'b0;
                    sync_ff2[i]   <= 1'b0;
                    candidate[i]  <= 1'b0;
                    count[i]      <= {COUNT_W{1'b0}};
                    key_state[i]  <= 1'b0;
                    key_pressed[i] <= 1'b0;
                end else begin
                    sync_ff1[i] <= key_in[i];
                    sync_ff2[i] <= sync_ff1[i];
                    key_pressed[i] <= 1'b0;

                    if (sync_ff2[i] != candidate[i]) begin
                        candidate[i] <= sync_ff2[i];
                        count[i] <= {COUNT_W{1'b0}};
                    end else if (candidate[i] != key_state[i]) begin
                        if (DEBOUNCE_CYCLES <= 1 || count[i] == DEBOUNCE_CYCLES - 1) begin
                            key_pressed[i] <= candidate[i] & ~key_state[i];
                            key_state[i] <= candidate[i];
                            count[i] <= {COUNT_W{1'b0}};
                        end else begin
                            count[i] <= count[i] + 1'b1;
                        end
                    end else begin
                        count[i] <= {COUNT_W{1'b0}};
                    end
                end
            end
        end
    endgenerate
endmodule
