`timescale 1ns/1ps

// A 0 -> +2048 -> 0 PCM fixture: only the displayed pixels may be
// interpolated; the source still contains exactly these three samples.
module tb_waveform_interpolation;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg de = 1'b0;
    reg [11:0] x = 12'd0;
    reg [10:0] y = 11'd0;
    wire [7:0] wave_addr;
    wire [7:0] spectrum_addr;
    wire [7:0] r, g, b;
    wire signed [15:0] wave_sample =
        (wave_addr == 8'd1) ? 16'sd2048 : 16'sd0;

    always #5 clk = ~clk;

    hdmi_ui dut (
        .clk(clk), .rst_n(rst_n), .de(de), .x(x), .y(y),
        .polyphony_count(4'd0), .key_state(8'd0),
        .spectrum_level(64'd0), .spectrum_dft_level(8'd0),
        .wave_sample(wave_sample), .wave_addr(wave_addr),
        .spectrum_addr(spectrum_addr), .rgb_r(r), .rgb_g(g), .rgb_b(b)
    );

    task pixel;
        input [11:0] px;
        input [10:0] py;
        input expected_wave;
        begin
            @(negedge clk);
            x = px;
            y = py;
            @(posedge clk);
            #1;
            if (expected_wave && {r,g,b} == 24'h152337)
                $fatal(1, "missing interpolated waveform at x=%0d y=%0d rgb=%h", px, py, {r,g,b});
        end
    endtask

    initial begin
        #12;
        rst_n = 1'b1;
        de = 1'b1;
        // At sample 1, 2048 >>> 5 = +64 pixels. The four subpixels
        // between sample 0 (y=291) and sample 1 (y=227) are 16 apart.
        pixel(12'd48, 11'd291, 1'b0);
        pixel(12'd49, 11'd291, 1'b0);
        pixel(12'd50, 11'd291, 1'b0);
        pixel(12'd51, 11'd291, 1'b0);
        pixel(12'd52, 11'd291, 1'b0);
        pixel(12'd53, 11'd275, 1'b1);
        pixel(12'd54, 11'd259, 1'b1);
        pixel(12'd55, 11'd243, 1'b1);
        pixel(12'd56, 11'd227, 1'b1);
        pixel(12'd57, 11'd243, 1'b1);
        pixel(12'd58, 11'd259, 1'b1);
        pixel(12'd59, 11'd275, 1'b1);
        pixel(12'd60, 11'd291, 1'b1);
        $display("TB_WAVEFORM_INTERPOLATION_PASS");
        $finish;
    end
endmodule
