`timescale 1ns/1ps

// A standalone behavioral test: compile only this file and pitch_glide.v.
module tb_pitch_glide;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg sample_tick = 1'b0;
    reg signed [15:0] target_q15 = 16'sd0;
    reg [3:0] speed = 4'd0;
    wire signed [15:0] current_q15;
    integer n;
    reg signed [15:0] previous;

    always #5 clk = ~clk;

    pitch_glide dut (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .target_q15(target_q15), .speed(speed), .current_q15(current_q15)
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
        target_q15 = 16'sd4015;
        speed = 4'd3;
        tick();
        if (current_q15 <= 0 || current_q15 >= 16'sd4015)
            $fatal(1, "smooth glide must start between zero and target");
        previous = current_q15;
        repeat (5) @(negedge clk);
        if (current_q15 !== previous)
            $fatal(1, "glide must hold its value between sample ticks");
        for (n = 0; n < 100; n = n + 1) tick();
        if (current_q15 <= previous || current_q15 >= 16'sd4015)
            $fatal(1, "glide must approach the positive target gradually");

        previous = current_q15;
        target_q15 = -16'sd3577;
        tick();
        if (current_q15 >= previous)
            $fatal(1, "negative target must reverse glide direction");
        speed = 4'd0;
        tick();
        if (current_q15 !== -16'sd3577)
            $fatal(1, "speed zero must jump directly to negative target");
        target_q15 = 16'sd10000;
        tick();
        if (current_q15 !== 16'sd4096)
            $fatal(1, "positive target must be bounded to 4096");
        target_q15 = 16'sd0;
        tick();
        if (current_q15 !== 16'sd0)
            $fatal(1, "zero target must restore nominal pitch");

        $display("TB_PITCH_GLIDE_PACKAGE_PASS");
        $finish;
    end
endmodule
