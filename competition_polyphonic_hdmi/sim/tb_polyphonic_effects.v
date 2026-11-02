`timescale 1ns/1ps

// Catches effects disconnected from the actual DDS or applied to one voice only.
module tb_polyphonic_effects;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg sample_tick = 1'b0;
    reg [7:0] key_state = 8'h81;
    reg signed [15:0] glide_target_q15 = 16'sd0;
    reg [3:0] glide_speed = 4'd0;
    reg vibrato_enable = 1'b0;
    reg [3:0] vibrato_rate_hz = 4'd10;
    reg [10:0] vibrato_depth_q15 = 11'd1024;
    wire signed [15:0] sample;

    localparam [31:0] STEP_C4 = 32'd23013218;
    localparam [31:0] STEP_C5 = 32'd46025557;

    always #5 clk = ~clk;

    polyphonic_dds dut (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .key_state(key_state), .sample(sample),
        .glide_target_q15(glide_target_q15), .glide_speed(glide_speed),
        .vibrato_enable(vibrato_enable), .vibrato_rate_hz(vibrato_rate_hz),
        .vibrato_depth_q15(vibrato_depth_q15)
    );

    task tick;
        begin
            @(negedge clk); sample_tick = 1'b1;
            @(negedge clk); sample_tick = 1'b0;
            #1;
        end
    endtask

    integer n;
    reg [31:0] phase0_before, phase7_before;
    reg [31:0] increment0, increment7;
    initial begin
        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        phase0_before = dut.phase0;
        phase7_before = dut.phase7;
        tick();
        if (dut.phase0 - phase0_before !== STEP_C4 ||
            dut.phase7 - phase7_before !== STEP_C5)
            $fatal(1, "disabled effects must retain exact C4/C5 increments");

        glide_target_q15 = 16'sd4015;
        tick(); // Update glide state.
        phase0_before = dut.phase0;
        phase7_before = dut.phase7;
        tick();
        increment0 = dut.phase0 - phase0_before;
        increment7 = dut.phase7 - phase7_before;
        if (increment0 <= STEP_C4 + 32'd2600000 ||
            increment7 <= STEP_C5 + 32'd5200000)
            $fatal(1, "positive glide must raise both active voices: %0d %0d", increment0, increment7);

        glide_target_q15 = 16'sd0;
        tick();
        vibrato_enable = 1'b1;
        for (n = 0; n < 1222; n = n + 1) tick();
        phase0_before = dut.phase0;
        tick();
        increment0 = dut.phase0 - phase0_before;
        if (increment0 <= STEP_C4)
            $fatal(1, "positive vibrato crest must raise DDS pitch");
        glide_target_q15 = 16'sd4015;
        tick();
        phase0_before = dut.phase0;
        tick();
        if (dut.phase0 - phase0_before <= increment0 + 32'd2500000)
            $fatal(1, "glide and vibrato must add independently");
        glide_target_q15 = 16'sd0;
        tick();
        for (n = 0; n < 2441; n = n + 1) tick();
        phase0_before = dut.phase0;
        tick();
        increment0 = dut.phase0 - phase0_before;
        if (increment0 >= STEP_C4)
            $fatal(1, "negative vibrato crest must lower DDS pitch");

        vibrato_enable = 1'b0;
        tick();
        phase0_before = dut.phase0;
        tick();
        if (dut.phase0 - phase0_before !== STEP_C4)
            $fatal(1, "turning effects off must restore nominal C4 pitch");
        $display("TB_POLYPHONIC_EFFECTS_PASS");
        $finish;
    end
endmodule
