`timescale 1ns/1ps

// Real touch -> pitch -> DDS -> serialized PCM integration test.
module tb_legato_top;
    localparam [31:0] C4 = 32'd23013218;
    localparam [31:0] C5 = 32'd46025557;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg [7:0] key_in = 8'h00;
    wire bclk, lrck, din, pa_en;
    reg [15:0] decoded_left;
    integer bit_index, frame_index, serial_nonzero = 0;

    always #5 clk = ~clk;

    legato_top #(.DEBOUNCE_CYCLES(4)) dut (
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
                $fatal(1, "DIN does not match generated PCM");
            if (decoded_left != 16'h0000)
                serial_nonzero = serial_nonzero + 1;
        end
    endtask

    initial begin
        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        audio_tick();
        if (dut.audio_sample !== 16'sd0 || pa_en !== 1'b0)
            $fatal(1, "silent idle or PA_EN polarity wrong");
        key_in = 8'h01;
        repeat (10) @(negedge clk);
        if (dut.key_state !== 8'h01 || dut.step !== C4)
            $fatal(1, "OUT1 did not play direct C4");
        repeat (12) audio_tick();
        for (frame_index = 0; frame_index < 8; frame_index = frame_index + 1)
            receive_left();
        if (serial_nonzero == 0)
            $fatal(1, "touch produced no serial PCM");
        key_in = 8'h81;
        repeat (10) @(negedge clk);
        if (dut.key_state !== 8'h81 || dut.step !== C4)
            $fatal(1, "overlapping OUT8 did not start from C4");
        audio_tick();
        if (dut.step <= C4 || dut.step >= C5)
            $fatal(1, "overlapping OUT8 did not slide upward");
        key_in = 8'h01;
        repeat (10) @(negedge clk);
        if (dut.step !== C4)
            $fatal(1, "OUT8 release did not return directly to held OUT1");
        key_in = 8'h00;
        repeat (10) @(negedge clk);
        audio_tick();
        if (dut.audio_sample !== 16'sd0)
            $fatal(1, "all-release must silence PCM");
        $display("TB_LEGATO_TOP_PASS");
        $finish;
    end
endmodule
