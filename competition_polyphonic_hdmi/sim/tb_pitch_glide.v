`timescale 1ns/1ps

// Catches reversed pitch direction, instant-only changes, and a ramp that stalls.
module tb_pitch_glide;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg sample_tick = 1'b0;
    reg signed [15:0] target_q15 = 16'sd0;
    reg [3:0] speed = 4'd0;
    wire signed [15:0] current_q15;

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

    integer n;
    reg signed [15:0] before_reverse;
    initial begin
        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        target_q15 = 16'sd4015; // approximately +200 cents
        speed = 4'd3;
        tick();
        if (current_q15 <= 0 || current_q15 >= target_q15)
            $fatal(1, "positive glide must start smoothly, got %0d", current_q15);
        for (n = 0; n < 100; n = n + 1) tick();
        if (current_q15 <= 0 || current_q15 >= target_q15)
            $fatal(1, "glide must still be between endpoints, got %0d", current_q15);

        before_reverse = current_q15;
        target_q15 = -16'sd3577; // approximately -200 cents
        tick();
        if (current_q15 >= before_reverse)
            $fatal(1, "negative target must reverse the glide");

        speed = 4'd0;
        tick();
        if (current_q15 !== -16'sd3577)
            $fatal(1, "zero speed must snap to the target, got %0d", current_q15);
        target_q15 = 16'sd0;
        tick();
        if (current_q15 !== 16'sd0)
            $fatal(1, "zero target must restore nominal pitch");
        $display("TB_PITCH_GLIDE_PASS");
        $finish;
    end
endmodule
