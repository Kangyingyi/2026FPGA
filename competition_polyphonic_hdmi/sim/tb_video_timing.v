`timescale 1ns/1ps

module tb_video_timing;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    wire hs;
    wire vs;
    wire de;
    wire [11:0] x;
    wire [10:0] y;

    video_timing_720p dut (
        .clk (clk),
        .rst_n(rst_n),
        .hs  (hs),
        .vs  (vs),
        .de  (de),
        .x   (x),
        .y   (y)
    );

    always #5 clk = ~clk;

    integer active_pixels;
    integer i;
    initial begin
        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);
        if (de !== 1'b1 || x !== 12'd0 || y !== 11'd0)
            $fatal(1, "active video did not start at x=0,y=0");

        active_pixels = 0;
        for (i = 0; i < 1650; i = i + 1) begin
            @(posedge clk);
            if (de) active_pixels = active_pixels + 1;
        end
        if (active_pixels !== 1280)
            $fatal(1, "line active pixel count=%d expected=1280", active_pixels);

        $display("TB_VIDEO_TIMING_PASS");
        $finish;
    end
endmodule
