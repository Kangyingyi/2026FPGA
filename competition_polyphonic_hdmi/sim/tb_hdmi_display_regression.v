`timescale 1ns/1ps

module tb_hdmi_display_regression;
    reg clk = 0;
    reg rst_n = 0;
    reg de = 1;
    reg [11:0] x = 0;
    reg [10:0] y = 0;
    reg signed [15:0] wave_sample = 0;
    reg [7:0] spectrum_dft_level = 0;
    wire [7:0] wave_addr, spectrum_addr, r, g, b;

    always #5 clk = ~clk;

    hdmi_ui dut (
        .clk(clk), .rst_n(rst_n), .de(de), .x(x), .y(y),
        .polyphony_count(4'd4), .key_state(8'h0f),
        .spectrum_level(64'd0), .spectrum_dft_level(spectrum_dft_level),
        .wave_sample(wave_sample), .wave_addr(wave_addr),
        .spectrum_addr(spectrum_addr), .rgb_r(r), .rgb_g(g), .rgb_b(b)
    );

    task expect_white;
        input [11:0] px;
        input [10:0] py;
        begin
            x = px; y = py;
            repeat (2) @(posedge clk);
            #1;
            if ({r,g,b} !== 24'he8f1fb)
                $fatal(1, "missing glyph pixel at (%0d,%0d): %h", px, py, {r,g,b});
        end
    endtask

    task expect_wave;
        input signed [15:0] sample_value;
        input [10:0] expected_y;
        begin
            x = 12'd100; y = expected_y; wave_sample = sample_value;
            repeat (2) @(posedge clk);
            #1;
            if ({r,g,b} !== 24'h35d8c0)
                $fatal(1, "wave sample %0d missing at y=%0d: %h", sample_value, expected_y, {r,g,b});
        end
    endtask

    initial begin
        #12; rst_n = 1;
        // The second glyph in every heading must render, including the z in Hz.
        expect_white(12'd66,  11'd92);  // POLY: O, row 0 col 1
        expect_white(12'd294, 11'd92);  // KEY: E, row 0 col 0
        expect_white(12'd566, 11'd92);  // SAMPLE: A, row 0 col 1
        expect_white(12'd818, 11'd92);  // PEAK: P, row 0 col 0
        expect_white(12'd98,  11'd582); // 0 Hz: z, row 2 col 1
        expect_white(12'd550, 11'd92);  // SAMPLE: S, row 0 col 1
        expect_white(12'd834, 11'd92);  // PEAK: E, row 0 col 0
        expect_white(12'd110, 11'd410); // FREQ BAND: Q, row 0 col 1
        expect_white(12'd584, 11'd126); // 48.8K: decimal point

        // Remove the old PCM-volume annotation from the waveform panel.
        x = 12'd32; y = 11'd222;
        repeat (2) @(posedge clk); #1;
        if ({r,g,b} !== 24'h152337)
            $fatal(1, "waveform volume label still visible: %h", {r,g,b});

        // A typical single-voice value should occupy much of the plot height.
        expect_wave(16'sd2048, 11'd227);
        expect_wave(-16'sd2048, 11'd355);
        x = 12'd360; y = 11'd504; spectrum_dft_level = 8'd132;
        repeat (2) @(posedge clk); #1;
        if ({r,g,b} !== 24'hf1b84b)
            $fatal(1, "real-level spectrum peak not visible: %h", {r,g,b});
        $display("TB_HDMI_DISPLAY_REGRESSION_PASS");
        $finish;
    end
endmodule
