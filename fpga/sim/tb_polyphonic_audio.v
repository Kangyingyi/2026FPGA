`timescale 1ns/1ps

module tb_polyphonic_audio;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg sample_tick = 1'b0;
    reg [7:0] key_state = 0;
    reg [2:0] timbre_sel = 0;
    reg [1:0] octave_sel = 1;
    wire signed [15:0] sample;
    always #5 clk = ~clk;

    polyphonic_timbre dut (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick), .key_state(key_state),
        .timbre_sel(timbre_sel), .octave_sel(octave_sel), .sample(sample)
    );

    task automatic tick;
        begin
            @(negedge clk); sample_tick=1;
            @(negedge clk); sample_tick=0;
        end
    endtask

    integer i;
    reg signed [15:0] single_sample;
    initial begin
        repeat (3) @(negedge clk); rst_n=1;
        for (i=0; i<4; i=i+1) tick();
        if (sample !== 0) $fatal(1, "reset/no-key sample is not zero: %0d", sample);
        key_state=8'b00000001;
        for (i=0; i<12; i=i+1) tick();
        single_sample = sample;
        if (single_sample == 0) $fatal(1, "single key did not produce audio");
        key_state=8'b00000101;
        for (i=0; i<12; i=i+1) tick();
        if (sample == 0) $fatal(1, "two keys did not produce audio");
        timbre_sel=3'd5;
        for (i=0; i<12; i=i+1) tick();
        if (sample == 0) $fatal(1, "timbre change silenced audio");
        octave_sel = 0; #1;
        if (dut.v_0.phase_step !== 32'd23013218 >> 1)
            $fatal(1, "low octave phase step mismatch");
        octave_sel = 2; #1;
        if (dut.v_0.phase_step !== 32'd23013218 << 1)
            $fatal(1, "high octave phase step mismatch");
        $display("POLYPHONIC_AUDIO_PASS sample=%0d", sample);
        $finish;
    end
endmodule
