`timescale 1ns/1ps

// Wrong overlap detection, note priority, direction, or ramp length fails here.
module tb_legato_pitch;
    localparam integer SLIDE_SAMPLES = 14648;
    localparam [31:0] C4 = 32'd23013218;
    localparam [31:0] D4 = 32'd25830607;
    localparam [31:0] C5 = 32'd46025557;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg sample_tick = 1'b0;
    reg [7:0] key_state = 8'h00;
    wire active;
    wire [31:0] step;
    reg [31:0] expected [0:7];
    reg [31:0] previous, midpoint, in_flight;
    integer i, n;

    always #5 clk = ~clk;

    legato_pitch #(.SLIDE_SAMPLES(SLIDE_SAMPLES)) dut (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .key_state(key_state), .active(active), .step(step)
    );

    task set_keys;
        input [7:0] value;
        begin
            @(negedge clk); key_state = value;
            @(posedge clk); #1;
        end
    endtask

    task tick;
        begin
            // Real I2S sample ticks are 1024 sys clocks apart; leave one
            // sys clock for a pipelined note-change coefficient.
            @(posedge clk); #1;
            @(negedge clk); sample_tick = 1'b1;
            @(posedge clk); #1;
            @(negedge clk); sample_tick = 1'b0;
        end
    endtask

    initial begin
        expected[0] = C4;
        expected[1] = D4;
        expected[2] = 32'd28994561;
        expected[3] = 32'd30718596;
        expected[4] = 32'd34480685;
        expected[5] = 32'd38702809;
        expected[6] = 32'd43442144;
        expected[7] = C5;
        repeat (2) @(negedge clk);
        rst_n = 1'b1;

        for (i = 0; i < 8; i = i + 1) begin
            set_keys(8'b1 << i);
            if (active !== 1'b1 || step !== expected[i])
                $fatal(1, "solo key %0d must start directly at its target", i+1);
            set_keys(8'h00);
            if (active !== 1'b0 || step !== 32'd0)
                $fatal(1, "solo key %0d did not release", i+1);
        end

        set_keys(8'h01);
        if (step !== C4) $fatal(1, "solo re-touch slid instead of direct C4");
        set_keys(8'h81);
        if (step !== C4) $fatal(1, "upslide did not begin at current C4");
        previous = step;
        for (n = 1; n <= SLIDE_SAMPLES; n = n + 1) begin
            tick();
            if (step < previous || step > C5)
                $fatal(1, "upslide not monotonic at tick %0d", n);
            if (n == SLIDE_SAMPLES/2) midpoint = step;
            if (n == SLIDE_SAMPLES-1 && step == C5)
                $fatal(1, "upslide completed before 300 ms");
            previous = step;
        end
        if (step !== C5 || midpoint < 32'd34518000 || midpoint > 32'd34521000)
            $fatal(1, "upslide endpoint or midpoint wrong");
        tick();
        if (step !== C5) $fatal(1, "upslide did not hold target");
        set_keys(8'h01);
        if (step !== C4) $fatal(1, "release C5 must return to held C4 instantly");
        tick();
        if (step !== C4) $fatal(1, "release return accidentally started glide");

        set_keys(8'h00);
        set_keys(8'h80);
        set_keys(8'h81);
        if (step !== C5) $fatal(1, "downslide did not begin at C5");
        previous = step;
        for (n = 1; n <= SLIDE_SAMPLES; n = n + 1) begin
            tick();
            if (step > previous || step < C4)
                $fatal(1, "downslide not monotonic at tick %0d", n);
            previous = step;
        end
        if (step !== C4) $fatal(1, "downslide missed C4 at tick 14648");

        set_keys(8'h00);
        set_keys(8'h01);
        set_keys(8'h81);
        for (n = 0; n < 100; n = n + 1) tick();
        in_flight = step;
        set_keys(8'h80); // Release old noncurrent C4.
        if (step !== in_flight)
            $fatal(1, "releasing noncurrent key changed audible pitch");
        tick();
        if (step <= in_flight)
            $fatal(1, "releasing noncurrent key interrupted glide");

        set_keys(8'h00);
        set_keys(8'h01);
        set_keys(8'h81);
        for (n = 0; n < 5000; n = n + 1) tick();
        in_flight = step;
        if (in_flight <= D4 || in_flight >= C5)
            $fatal(1, "interrupted glide did not reach a middle frequency");
        set_keys(8'h83); // D4 touched last; it is below the current pitch.
        if (step !== in_flight)
            $fatal(1, "third key jumped away from in-flight frequency");
        tick();
        if (step >= in_flight)
            $fatal(1, "third key did not start new downward slide");

        set_keys(8'h81); // Release current D4; held C5 resumes.
        if (step !== C5)
            $fatal(1, "release current D4 must return to held C5 directly");
        set_keys(8'h01);
        if (step !== C4)
            $fatal(1, "next release must return to held C4 directly");
        set_keys(8'h00);
        if (active !== 1'b0 || step !== 32'd0)
            $fatal(1, "all release must silence and clear glide");

        set_keys(8'h81); // Two new keys from silence: C5 wins, no slide.
        if (step !== C5) $fatal(1, "simultaneous highest key not direct");
        set_keys(8'h01);
        if (step !== C4) $fatal(1, "simultaneous lower key not retained for fallback");
        set_keys(8'h00);
        set_keys(8'h01);
        set_keys(8'h80); // Old key released in same event; no overlap.
        if (step !== C5) $fatal(1, "same-event nonoverlap incorrectly slid");

        set_keys(8'h00);
        set_keys(8'h01);
        set_keys(8'h03);
        set_keys(8'h07);
        previous = step;
        set_keys(8'h03);
        if (step !== D4) $fatal(1, "fallback did not pick newest held D4");
        set_keys(8'h01);
        if (step !== C4) $fatal(1, "fallback did not pick oldest held C4");
        set_keys(8'h00);

        $display("TB_LEGATO_PITCH_PASS");
        $finish;
    end
endmodule
