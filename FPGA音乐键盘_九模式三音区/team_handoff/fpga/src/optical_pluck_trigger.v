`timescale 1ns/1ps

// Synchronizes the optical-gate digital output and emits one clock pulse
// on each obstruction (rising edge).  The pictured LM393 module outputs
// low when the slot is clear and high when it is blocked.  The sensor is powered from 3.3 V,
// so its OUT signal is safe for the FPGA input.
module optical_pluck_trigger #(
    parameter integer LOCKOUT_CYCLES = 1_000_000  // 20 ms at 50 MHz
) (
    input  wire clk,
    input  wire rst_n,
    input  wire optical_in,
    input  wire sample_tick,
    output wire pluck_trigger
);
    reg sync_meta, sync_level, sync_previous;
    reg [20:0] lockout;
    reg pending;
    assign pluck_trigger = pending;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync_meta     <= 1'b0;
            sync_level    <= 1'b0;
            sync_previous <= 1'b0;
            lockout       <= 0;
            pending       <= 1'b0;
        end else begin
            sync_meta     <= optical_in;
            sync_level    <= sync_meta;
            sync_previous <= sync_level;
            if (lockout != 0) begin
                lockout <= lockout - 1'b1;
            end else if (sync_level && !sync_previous) begin
                pending <= 1'b1;
                lockout <= LOCKOUT_CYCLES;
            end

            // Hold the asynchronous edge until an audio sample boundary,
            // so the one-sample trigger cannot be missed between I2S ticks.
            if (sample_tick && pending) begin
                pending <= 1'b0;
            end
        end
    end
endmodule
