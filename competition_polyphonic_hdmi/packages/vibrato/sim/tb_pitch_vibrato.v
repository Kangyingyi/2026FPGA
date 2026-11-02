`timescale 1ns/1ps

// A standalone behavioral test: compile only this file and pitch_vibrato.v.
module tb_pitch_vibrato;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg sample_tick = 1'b0;
    reg enable = 1'b0;
    reg [3:0] rate_hz = 4'd10;
    reg [10:0] depth_q15 = 11'd1024;
    wire signed [15:0] delta_q15;
    integer n;

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

    initial begin
        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        tick();
        if (delta_q15 !== 16'sd0)
            $fatal(1, "disabled vibrato must be zero");
        enable = 1'b1;
        for (n = 0; n < 1221; n = n + 1) tick();
        if (delta_q15 < 16'sd900 || delta_q15 > 16'sd1024)
            $fatal(1, "quarter-cycle offset must approach +depth");
        for (n = 0; n < 1221; n = n + 1) tick();
        if (delta_q15 < -16'sd40 || delta_q15 > 16'sd40)
            $fatal(1, "half-cycle offset must return near zero");
        for (n = 0; n < 1221; n = n + 1) tick();
        if (delta_q15 > -16'sd900 || delta_q15 < -16'sd1024)
            $fatal(1, "three-quarter-cycle offset must approach -depth");
        depth_q15 = 11'd0;
        #1;
        if (delta_q15 !== 16'sd0)
            $fatal(1, "zero depth must produce zero pitch offset");
        enable = 1'b0;
        tick();
        depth_q15 = 11'd1024;
        if (delta_q15 !== 16'sd0)
            $fatal(1, "disabled vibrato must clear its output");
        enable = 1'b1;
        #1;
        if (delta_q15 !== 16'sd0)
            $fatal(1, "re-enabled vibrato must restart at phase zero");

        $display("TB_PITCH_VIBRATO_PACKAGE_PASS");
        $finish;
    end
endmodule
