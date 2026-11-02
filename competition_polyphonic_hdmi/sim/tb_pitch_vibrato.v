`timescale 1ns/1ps

// Catches a static detune in place of vibrato and a nonzero disabled effect.
module tb_pitch_vibrato;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg sample_tick = 1'b0;
    reg enable = 1'b0;
    reg [3:0] rate_hz = 4'd10;
    reg [10:0] depth_q15 = 11'd1024;
    wire signed [15:0] delta_q15;

    always #5 clk = ~clk;

    pitch_vibrato dut (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .enable(enable), .rate_hz(rate_hz),
        .depth_q15(depth_q15), .delta_q15(delta_q15)
    );

    task tick;
        begin
            @(negedge clk); sample_tick = 1'b1;
            @(negedge clk); sample_tick = 1'b0;
            #1;
        end
    endtask

    integer n;
    initial begin
        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        tick();
        if (delta_q15 !== 16'sd0) $fatal(1, "disabled vibrato must be zero");
        enable = 1'b1;
        for (n = 0; n < 1221; n = n + 1) tick();
        if (delta_q15 < 16'sd900 || delta_q15 > 16'sd1024)
            $fatal(1, "quarter cycle must rise near +depth, got %0d", delta_q15);
        for (n = 0; n < 1221; n = n + 1) tick();
        if (delta_q15 < -16'sd40 || delta_q15 > 16'sd40)
            $fatal(1, "half cycle must return near zero, got %0d", delta_q15);
        for (n = 0; n < 1221; n = n + 1) tick();
        if (delta_q15 > -16'sd900 || delta_q15 < -16'sd1024)
            $fatal(1, "three-quarter cycle must fall near -depth, got %0d", delta_q15);
        enable = 1'b0;
        tick();
        if (delta_q15 !== 16'sd0) $fatal(1, "disabled vibrato must clear pitch offset");
        $display("TB_PITCH_VIBRATO_PASS");
        $finish;
    end
endmodule
