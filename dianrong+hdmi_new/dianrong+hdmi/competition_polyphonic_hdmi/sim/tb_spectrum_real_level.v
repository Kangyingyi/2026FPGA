`timescale 1ns/1ps

// A DDS voice is about 1500 PCM counts, or 5-6 in the high byte.
// Two real-level tones must both rise visibly above the HDMI plot baseline.
module tb_spectrum_real_level;
    reg clk = 0;
    reg rst_n = 0;
    reg sample_tick = 0;
    reg signed [15:0] audio_sample = 0;
    reg [7:0] read_addr = 0;
    wire [7:0] read_level;
    wire frame_toggle;
    integer n, c4_level, d4_level, quiet_level;
    real value;
    real pi = 3.14159265358979323846;

    always #5 clk = ~clk;

    spectrum_dft #(.SAMPLE_DECIMATION(24), .BIN_COUNT(126)) dut (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .audio_sample(audio_sample), .read_addr(read_addr),
        .read_level(read_level), .frame_tick(), .frame_toggle(frame_toggle),
        .write_en(), .write_addr(), .write_level()
    );

    initial begin
        #5000000;
        $fatal(1, "real-level DFT frame timeout");
    end

    initial begin
        #20; rst_n = 1;
        for (n = 0; n < 256; n = n + 1) begin
            value = 6.0 * $sin(2.0*pi*33.0*n/256.0)
                  + 5.0 * $sin(2.0*pi*37.0*n/256.0);
            audio_sample = $rtoi(value) <<< 8;
            sample_tick = 1;
            repeat (24) @(posedge clk);
            sample_tick = 0;
        end
        wait(frame_toggle == 1);
        #20;
        read_addr = 8'd33; #1; c4_level = read_level;
        read_addr = 8'd37; #1; d4_level = read_level;
        read_addr = 8'd10; #1; quiet_level = read_level;
        if (c4_level < 80 || d4_level < 60 ||
            c4_level <= quiet_level + 60 || d4_level <= quiet_level + 50)
            $fatal(1, "real DDS-level polyphonic peaks invisible: C4=%0d D4=%0d quiet=%0d", c4_level, d4_level, quiet_level);
        $display("TB_SPECTRUM_REAL_LEVEL_PASS C4=%0d D4=%0d quiet=%0d", c4_level, d4_level, quiet_level);
        $finish;
    end
endmodule
