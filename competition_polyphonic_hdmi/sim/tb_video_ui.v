`timescale 1ns/1ps

module tb_video_ui;
    reg clk;
    reg rst_n;
    reg de;
    reg [11:0] x;
    reg [10:0] y;
    reg [3:0] polyphony_count;
    reg [7:0] key_state;
    reg [63:0] spectrum_level;
    reg [7:0] spectrum_dft_level;
    reg signed [15:0] wave_sample;
    wire [7:0] wave_addr;
    wire [7:0] spectrum_addr;
    wire [7:0] r;
    wire [7:0] g;
    wire [7:0] b;

    always #5 clk = ~clk;

    hdmi_ui dut (
        .clk              (clk),
        .rst_n            (rst_n),
        .de              (de),
        .x               (x),
        .y               (y),
        .polyphony_count (polyphony_count),
        .key_state       (key_state),
        .spectrum_level  (spectrum_level),
        .spectrum_dft_level(spectrum_dft_level),
        .wave_sample     (wave_sample),
        .wave_addr       (wave_addr),
        .spectrum_addr   (spectrum_addr),
        .rgb_r           (r),
        .rgb_g           (g),
        .rgb_b           (b)
    );

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        de = 1'b0;
        x = 12'd0;
        y = 11'd0;
        polyphony_count = 4'd0;
        key_state = 8'd0;
        spectrum_level = 64'd0;
        spectrum_dft_level = 8'd0;
        wave_sample = 16'sd0;
        #12;
        rst_n = 1'b1;
        repeat (2) @(posedge clk);
        #1;
        if ({r,g,b} !== 24'h000000)
            $fatal(1, "blanking must output black");

        de = 1'b1;
        x = 12'd50;
        y = 11'd120;
        repeat (2) @(posedge clk); #1;
        if ({r,g,b} === 24'h000000)
            $fatal(1, "dashboard card must be visible");

        x = 12'd580;
        y = 11'd300;
        wave_sample = 16'sd12000;
        repeat (2) @(posedge clk); #1;
        if (wave_addr !== 8'd133)
            $fatal(1, "wave address mapping=%d expected=133", wave_addr);

        x = 12'd100;
        y = 11'd500;
        spectrum_dft_level = 8'd0;
        repeat (2) @(posedge clk); #1;
        if ({r,g,b} === 24'h000000)
            $fatal(1, "spectrum panel must render its background/grid");

        x = 12'd100;
        y = 11'd470;
        spectrum_dft_level = 8'd200;
        repeat (2) @(posedge clk); #1;
        if (spectrum_addr !== 8'd5)
            $fatal(1, "continuous spectrum address mapping=%d expected=5", spectrum_addr);
        if ({r,g,b} === 24'h152337)
            $fatal(1, "active continuous spectrum must change pixel color");

        // The 0-1000 Hz axis must span the full DFT RAM, including C4/D4.
        x = 12'd361; y = 11'd470;
        repeat (2) @(posedge clk); #1;
        if (spectrum_addr !== 8'd33)
            $fatal(1, "C4 frequency address=%0d expected=33", spectrum_addr);
        x = 12'd639;
        repeat (2) @(posedge clk); #1;
        if (spectrum_addr !== 8'd62)
            $fatal(1, "500 Hz address=%0d expected=62", spectrum_addr);
        x = 12'd1229;
        repeat (2) @(posedge clk); #1;
        if (spectrum_addr !== 8'd124)
            $fatal(1, "1000 Hz address=%0d expected=124", spectrum_addr);

        x = 12'd50;
        y = 11'd580;
        repeat (2) @(posedge clk); #1;
        if ({r,g,b} === 24'h0b1220)
            $fatal(1, "frequency axis label must render");

        x = 12'd4;
        y = 11'd226;
        repeat (2) @(posedge clk); #1;
        if ({r,g,b} !== 24'h0b1220)
            $fatal(1, "waveform panel should not show an amplitude label");

        $display("TB_VIDEO_UI_PASS");
        $finish;
    end
endmodule
