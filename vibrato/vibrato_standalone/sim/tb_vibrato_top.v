`timescale 1ns/1ps

// Touch input must reach real stereo I2S audio without another project.
module tb_vibrato_top;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg [7:0] key_in = 8'h00;
    wire bclk, lrck, din, pa_en;
    integer sys_cycles = 0, last_tick = -1, ticks = 0;
    reg bclk_seen = 1'b0, lrck_seen = 1'b0;
    reg old_bclk = 1'b0, old_lrck = 1'b1;
    reg [15:0] decoded_left;
    integer serial_nonzero = 0;
    integer bit_index, frame_index;

    always #5 clk = ~clk;

    vibrato_top #(.DEBOUNCE_CYCLES(4), .VIBRATO_RATE_HZ(10)) dut (
        .sys_clk(clk), .rst_n(rst_n), .key_in(key_in),
        .I2S_BCLK(bclk), .I2S_LRCK(lrck),
        .I2S_DIN(din), .PA_EN(pa_en)
    );

    task audio_tick;
        begin
            @(posedge dut.sample_tick);
            @(posedge clk);
            #1;
        end
    endtask

    task receive_left;
        begin
            @(negedge lrck);
            @(posedge bclk); // Philips I2S one-bit delay
            decoded_left = 16'h0000;
            for (bit_index = 0; bit_index < 16; bit_index = bit_index + 1) begin
                @(posedge bclk);
                #1;
                decoded_left = {decoded_left[14:0], din};
            end
            if (decoded_left !== dut.tx.left_hold)
                $fatal(1, "top I2S serial output differs from generated PCM");
            if (decoded_left != 16'h0000)
                serial_nonzero = serial_nonzero + 1;
        end
    endtask

    always @(posedge clk) begin
        if (rst_n) begin
            sys_cycles = sys_cycles + 1;
            if (bclk != old_bclk) bclk_seen = 1'b1;
            if (lrck != old_lrck) lrck_seen = 1'b1;
            old_bclk = bclk;
            old_lrck = lrck;
            if (dut.sample_tick) begin
                if (last_tick >= 0 && sys_cycles - last_tick != 1024)
                    $fatal(1, "wrong I2S frame period");
                last_tick = sys_cycles;
                ticks = ticks + 1;
            end
        end
    end

    initial begin
        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        audio_tick();
        if (dut.audio_sample !== 16'sd0 || pa_en !== 1'b0)
            $fatal(1, "silent idle or PA_EN polarity wrong");
        key_in = 8'h81;
        repeat (10) @(negedge clk);
        if (dut.key_state !== 8'h81)
            $fatal(1, "OUT1/OUT8 touch map wrong");
        repeat (12) audio_tick();
        if (dut.audio_sample === 16'sd0 ||
            dut.tx.left_hold !== dut.tx.right_hold ||
            !bclk_seen || !lrck_seen || ticks < 2)
            $fatal(1, "stereo I2S synthesizer not active");
        for (frame_index = 0; frame_index < 8; frame_index = frame_index + 1)
            receive_left();
        if (serial_nonzero == 0)
            $fatal(1, "top I2S DIN remained silent while keys were touched");
        key_in = 8'h00;
        repeat (10) @(negedge clk);
        audio_tick();
        if (dut.audio_sample !== 16'sd0)
            $fatal(1, "release must silence all voices");
        $display("TB_VIBRATO_TOP_PASS");
        $finish;
    end
endmodule
