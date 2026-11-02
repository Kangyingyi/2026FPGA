`timescale 1ns/1ps

// A Philips I2S receiver must decode distinct left and right PCM exactly.
module tb_i2s_framing;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    wire bclk, lrck, din, tick;
    reg [15:0] received;
    integer i;

    always #5 clk = ~clk;

    i2s_tx dut (
        .clk(clk), .rst_n(rst_n),
        .sample_l(16'shA53C), .sample_r(16'sh36D2),
        .i2s_bclk(bclk), .i2s_lrck(lrck),
        .i2s_din(din), .sample_tick(tick)
    );

    task receive_channel;
        input [15:0] expected;
        begin
            @(posedge bclk); // one-bit delay after LRCK transition
            received = 16'h0000;
            for (i = 0; i < 16; i = i + 1) begin
                @(posedge bclk);
                #1;
                received = {received[14:0], din};
            end
            if (received !== expected)
                $fatal(1, "I2S receiver got %h, expected %h", received, expected);
        end
    endtask

    initial begin
        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        @(negedge lrck);
        receive_channel(16'hA53C);
        @(posedge lrck);
        receive_channel(16'h36D2);
        $display("TB_I2S_FRAMING_PASS");
        $finish;
    end
endmodule
