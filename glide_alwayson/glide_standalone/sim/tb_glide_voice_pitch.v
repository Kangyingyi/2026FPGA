`timescale 1ns/1ps

// Wrong start, stalled ramp, no tick gating, or missing retrigger must fail.
module tb_glide_voice_pitch;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg sample_tick = 1'b0;
    reg key_active = 1'b0;
    wire signed [15:0] offset_q15;
    integer n;
    reg signed [15:0] held;

    always #5 clk = ~clk;

    glide_voice_pitch dut (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .key_active(key_active), .offset_q15(offset_q15)
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
        key_active = 1'b1;
        tick();
        if (offset_q15 !== -16'sd3577)
            $fatal(1, "new note must begin about 200 cents low");
        held = offset_q15;
        repeat (5) @(negedge clk);
        if (offset_q15 !== held)
            $fatal(1, "glide moved without sample_tick");
        for (n = 0; n < 3000; n = n + 1) tick();
        if (offset_q15 <= -16'sd1900 || offset_q15 >= -16'sd1600)
            $fatal(1, "midpoint of glide wrong: %0d", offset_q15);
        for (n = 0; n < 3500; n = n + 1) tick();
        if (offset_q15 !== 16'sd0)
            $fatal(1, "glide must finish exactly at target pitch");
        key_active = 1'b0;
        tick();
        if (offset_q15 !== 16'sd0)
            $fatal(1, "release must reset the offset");
        key_active = 1'b1;
        tick();
        if (offset_q15 !== -16'sd3577)
            $fatal(1, "second touch must restart the glide");
        $display("TB_GLIDE_VOICE_PITCH_PASS");
        $finish;
    end
endmodule
