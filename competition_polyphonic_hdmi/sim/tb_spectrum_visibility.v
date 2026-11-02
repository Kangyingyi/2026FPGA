`timescale 1ns/1ps

// Video-domain integration: a completed DFT remains visible after the
// frame event toggles back to zero on the next analysis frame.
module tb_spectrum_visibility;
    reg sys_clk = 0;
    reg rst_n = 0;
    // TTP226 direct-mode inputs are active high; idle is all zero.
    reg [7:0] key_in = 8'h00;
    wire I2S_BCLK, I2S_LRCK, I2S_DIN, PA_EN, UART_TX;
    wire tmds_clk_n_0, tmds_clk_p_0, hpd_en;
    wire [2:0] tmds_d_n_0, tmds_d_p_0;

    always #5 sys_clk = ~sys_clk;

    top_hdmi dut (
        .sys_clk(sys_clk), .rst_n(rst_n), .key_in(key_in),
        .I2S_BCLK(I2S_BCLK), .I2S_LRCK(I2S_LRCK),
        .I2S_DIN(I2S_DIN), .PA_EN(PA_EN), .UART_TX(UART_TX),
        .tmds_clk_n_0(tmds_clk_n_0), .tmds_clk_p_0(tmds_clk_p_0),
        .tmds_d_n_0(tmds_d_n_0), .tmds_d_p_0(tmds_d_p_0),
        .hpd_en(hpd_en)
    );

    initial begin
        #20; rst_n = 1;
        repeat (5) @(posedge sys_clk);
        force dut.spectrum_dft_level_pixel = 8'd132;
        force dut.spectrum_dft_frame_toggle_audio = 1'b1;
        repeat (5) @(posedge sys_clk); #1;
        if (dut.hdmi_ui_inst.spectrum_dft_level !== 8'd132)
            $fatal(1, "first spectrum frame hidden");
        force dut.spectrum_dft_frame_toggle_audio = 1'b0;
        repeat (5) @(posedge sys_clk); #1;
        if (dut.hdmi_ui_inst.spectrum_dft_level !== 8'd132)
            $fatal(1, "second spectrum frame blanked after toggle returned to zero");
        force dut.video_x = 12'd361;
        force dut.video_y = 11'd470;
        force dut.video_de = 1'b1;
        repeat (5) @(posedge sys_clk); #1;
        if (dut.spectrum_addr !== 8'd33 || dut.spectrum_dft_addr !== 8'd33)
            $fatal(1, "HDMI frequency address not wired to DFT");
        $display("TB_SPECTRUM_VISIBILITY_PASS");
        $finish;
    end
endmodule

// Test-only clock and HDMI output adapters. The real audio/DFT/UI modules
// above are instantiated unchanged.
module TMDS_PLL(input clkin, output clkout0, output clkout1, output lock);
    assign clkout0 = clkin;
    assign clkout1 = clkin;
    assign lock = 1'b1;
endmodule

module DVI_TX_Top (
    input I_rst_n, I_serial_clk, I_rgb_clk, I_rgb_vs, I_rgb_hs, I_rgb_de,
    input [7:0] I_rgb_r, I_rgb_g, I_rgb_b,
    output O_tmds_clk_p, O_tmds_clk_n,
    output [2:0] O_tmds_data_p, O_tmds_data_n
);
    assign O_tmds_clk_p = 1'b0;
    assign O_tmds_clk_n = 1'b0;
    assign O_tmds_data_p = 3'b0;
    assign O_tmds_data_n = 3'b0;
endmodule
