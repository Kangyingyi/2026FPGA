`timescale 1ns/1ps

// Red test for the HTML-compatible decimated DFT.  The input is presented
// as a signed high-byte audio sample held for 24 audio sample ticks.  A 33-bin
// tone and a 37-bin tone represent approximately C4 and D4 at the HTML
// monitor's 2034.5 Hz analysis rate.
module tb_spectrum_dft;
    reg clk;
    reg rst_n;
    reg sample_tick;
    reg signed [15:0] audio_sample;
    reg [7:0] read_addr;
    wire [7:0] read_level;
    wire frame_toggle;
    wire frame_tick;
    wire write_en;
    wire [7:0] write_addr;
    wire [7:0] write_level;

    always #5 clk = ~clk;

    initial begin
        #5000000;
        $display("DEBUG timeout busy=%b state=%0d write_index=%0d decim=%0d bin=%0d sample=%0d toggle=%b", dut.busy, dut.state, dut.write_index, dut.decim_count, dut.bin_index, dut.sample_index, frame_toggle);
        $fatal(1, "spectrum frame did not complete");
    end

    spectrum_dft #(
        .SAMPLE_DECIMATION(24),
        .BIN_COUNT(126)
    ) dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .sample_tick  (sample_tick),
        .audio_sample (audio_sample),
        .read_addr    (read_addr),
        .read_level   (read_level),
        .frame_tick   (frame_tick),
        .frame_toggle (frame_toggle),
        .write_en     (write_en),
        .write_addr   (write_addr),
        .write_level  (write_level)
    );

    integer n;
    integer k;
    integer tone8;
    integer measured_c4;
    integer measured_d4;
    integer measured_quiet;
    real pi;
    real value;

    task send_decimated_sample;
        input integer signed_value;
        begin
            audio_sample = signed_value <<< 8;
            sample_tick = 1'b1;
            repeat (24) @(posedge clk);
            sample_tick = 1'b0;
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        sample_tick = 1'b0;
        audio_sample = 16'sd0;
        read_addr = 8'd0;
        pi = 3.14159265358979323846;
        #20;
        rst_n = 1'b1;

        // A two-tone frame.  The first tone is bin 33 and the second is bin
        // 37, matching the expected C4/D4 neighborhood at 2034.5 Hz.
        for (n = 0; n < 256; n = n + 1) begin
            value = 72.0 * $sin(2.0*pi*33.0*n/256.0)
                  + 58.0 * $sin(2.0*pi*37.0*n/256.0);
            send_decimated_sample($rtoi(value));
        end

        wait (frame_toggle == 1'b1);
        #20;
        read_addr = 8'd33; #1; measured_c4 = read_level;
        read_addr = 8'd37; #1; measured_d4 = read_level;
        read_addr = 8'd10; #1; measured_quiet = read_level;
        if (measured_c4 < 80 || measured_d4 < 60)
            $fatal(1, "C4/D4 bins too small: %0d/%0d", measured_c4, measured_d4);
        if (measured_c4 <= measured_quiet || measured_d4 <= measured_quiet)
            $fatal(1, "tone bins not above quiet bin: %0d/%0d vs %0d", measured_c4, measured_d4, measured_quiet);

        $display("TB_SPECTRUM_DFT_PASS C4=%0d D4=%0d quiet=%0d", measured_c4, measured_d4, measured_quiet);
        $finish;
    end
endmodule
