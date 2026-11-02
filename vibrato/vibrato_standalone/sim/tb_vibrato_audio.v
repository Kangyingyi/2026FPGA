`timescale 1ns/1ps

// Real DDS increments must follow an independent 10 Hz vibrato test cycle.
module tb_vibrato_audio;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg sample_tick = 1'b0;
    reg [7:0] key_state = 8'h00;
    wire signed [15:0] sample;
    integer n;
    reg [31:0] previous0, previous7;
    localparam [31:0] STEP_C4 = 32'd23013218;
    localparam [31:0] STEP_C5 = 32'd46025557;

    always #5 clk = ~clk;

    vibrato_dds #(.RATE_HZ(10), .DEPTH_Q15(1024)) dut (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .key_state(key_state), .sample(sample)
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
        if (sample !== 16'sd0)
            $fatal(1, "no touched note must be silent");
        key_state = 8'h01;
        for (n = 0; n < 1222; n = n + 1) tick();
        previous0 = dut.phase[0];
        tick();
        if (dut.phase[0] - previous0 <= STEP_C4)
            $fatal(1, "positive vibrato crest must increase C4 frequency");
        for (n = 0; n < 2441; n = n + 1) tick();
        previous0 = dut.phase[0];
        tick();
        if (dut.phase[0] - previous0 >= STEP_C4)
            $fatal(1, "negative vibrato crest must decrease C4 frequency");

        key_state = 8'h81;
        previous0 = dut.phase[0];
        tick();
        tick();
        if (dut.phase[0] === previous0 || dut.phase[7] === 32'd0)
            $fatal(1, "held C4 and new C5 must have separate active phases");
        previous7 = dut.phase[7];
        tick();
        if (dut.phase[7] - previous7 >= STEP_C5)
            $fatal(1, "shared negative LFO must also affect C5");
        key_state = 8'h00;
        tick();
        if (sample !== 16'sd0 || dut.phase[0] !== 32'd0 ||
            dut.phase[7] !== 32'd0 || dut.delta_q15 !== 16'sd0)
            $fatal(1, "all released notes must silence and reset LFO");
        key_state = 8'h01;
        #1;
        if (dut.delta_q15 !== 16'sd0)
            $fatal(1, "new phrase must restart vibrato at center pitch");
        tick();
        previous0 = dut.phase[0];
        if (previous0 !== STEP_C4)
            $fatal(1, "first new-phrase sample must start at nominal C4 pitch");

        $display("TB_VIBRATO_AUDIO_PASS");
        $finish;
    end
endmodule
