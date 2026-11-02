`timescale 1ns/1ps

// End-to-end audio sample path with real one-cycle I2S-style sample ticks.
// System clocks are compressed between ticks to keep simulation short; the
// DDS phase step and 24:1 DFT decimation are the same as on the board.
module tb_spectrum_from_dds;
    reg clk = 0;
    reg rst_n = 0;
    reg sample_tick = 0;
    reg [7:0] key_state = 8'h03;
    wire signed [15:0] audio_sample;
    reg [7:0] read_addr = 0;
    wire [7:0] read_level;
    wire frame_toggle;
    integer n, c4, d4, quiet;

    always #5 clk = ~clk;

    polyphonic_dds synth (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .key_state(key_state), .sample(audio_sample),
        .glide_target_q15(16'sd0), .glide_speed(4'd0),
        .vibrato_enable(1'b0), .vibrato_rate_hz(4'd0),
        .vibrato_depth_q15(11'd0)
    );

    spectrum_dft #(.SAMPLE_DECIMATION(24), .BIN_COUNT(126)) dft (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .audio_sample(audio_sample), .read_addr(read_addr),
        .read_level(read_level), .frame_tick(), .frame_toggle(frame_toggle),
        .write_en(), .write_addr(), .write_level()
    );

    initial begin
        #1500000;
        $fatal(1, "DDS-to-spectrum frame timeout");
    end

    initial begin
        #20; rst_n = 1;
        for (n = 0; n < 256*24; n = n + 1) begin
            @(negedge clk); sample_tick = 1;
            @(negedge clk); sample_tick = 0;
            repeat (6) @(negedge clk);
        end
        wait (frame_toggle == 1);
        #20;
        read_addr = 8'd33; #1; c4 = read_level;
        read_addr = 8'd37; #1; d4 = read_level;
        read_addr = 8'd10; #1; quiet = read_level;
        if (c4 < 45 || d4 < 45 || c4 <= quiet+30 || d4 <= quiet+30)
            $fatal(1, "DDS spectrum peaks missing: C4=%0d D4=%0d quiet=%0d", c4, d4, quiet);
        $display("TB_SPECTRUM_FROM_DDS_PASS C4=%0d D4=%0d quiet=%0d", c4, d4, quiet);
        $finish;
    end
endmodule
