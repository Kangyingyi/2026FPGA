`timescale 1ns/1ps

// Simulation stand-ins for the Gowin PLL and encrypted DVI transmitter.
// Hardware builds use the real IP listed in ble_music_keyboard.gprj.
module TMDS_PLL (
    output wire lock,
    output wire clkout0,
    output wire clkout1,
    input wire clkin
);
    assign lock = 1'b1;
    assign clkout0 = clkin;
    assign clkout1 = clkin;
endmodule

module DVI_TX_Top (
    input wire I_rst_n,
    input wire I_serial_clk,
    input wire I_rgb_clk,
    input wire I_rgb_vs,
    input wire I_rgb_hs,
    input wire I_rgb_de,
    input wire [7:0] I_rgb_r,
    input wire [7:0] I_rgb_g,
    input wire [7:0] I_rgb_b,
    output wire O_tmds_clk_p,
    output wire O_tmds_clk_n,
    output wire [2:0] O_tmds_data_p,
    output wire [2:0] O_tmds_data_n
);
    assign O_tmds_clk_p = 1'b0;
    assign O_tmds_clk_n = 1'b0;
    assign O_tmds_data_p = 3'b000;
    assign O_tmds_data_n = 3'b000;
endmodule
