`timescale 1ns/1ps

module tb_record_stream;
    reg clk=0, rst_n=0, record_enable=0;
    reg sample_tick=0;
    reg signed [15:0] audio_sample=0;
    wire pcm_valid;
    wire signed [7:0] pcm_sample;
    wire tx_valid, tx_busy;
    wire [7:0] tx_byte;
    integer i, tx_count=0;
    reg [7:0] captured [0:70];

    always #5 clk=~clk;
    record_sampler #(.AUDIO_HZ(4), .RECORD_HZ(1)) sampler (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick), .record_enable(record_enable),
        .audio_sample(audio_sample), .pcm_valid(pcm_valid), .pcm_sample(pcm_sample)
    );
    record_packetizer packetizer (
        .clk(clk), .rst_n(rst_n), .record_start(record_enable), .record_stop(1'b0),
        .pcm_valid(pcm_valid), .pcm_sample(pcm_sample), .tx_valid(tx_valid),
        .tx_ready(1'b1), .tx_byte(tx_byte), .busy(tx_busy)
    );

    always @(posedge clk) begin
        if (tx_valid) begin
            captured[tx_count] = tx_byte;
            tx_count = tx_count + 1;
        end
    end

    task automatic one_audio_tick(input integer sample_number);
        begin
            @(negedge clk); audio_sample = sample_number <<< 8; sample_tick=1;
            @(negedge clk); sample_tick=0;
        end
    endtask

    initial begin
        repeat (3) @(negedge clk); rst_n=1; record_enable=1;
        for (i=0; i<256; i=i+1) one_audio_tick(i/4);
        repeat (100) @(negedge clk);
        if (tx_count != 71) $fatal(1, "expected 71 frame bytes, got %0d", tx_count);
        if (captured[0] !== 8'hA5 || captured[1] !== 8'h41 || captured[2] !== 8'h42 || captured[3] !== 0)
            $fatal(1, "record frame header mismatch");
        if (captured[4] !== 0 || captured[5] !== 0 || captured[6] !== 0 || captured[69] !== 8'h3F)
            $fatal(1, "record payload mismatch: seq=%h %h first=%h last=%h", captured[4], captured[5], captured[6], captured[69]);
        if (captured[70] !== 8'h63) $fatal(1, "record checksum mismatch: %h", captured[70]);
        $display("RECORD_STREAM_PASS");
        $finish;
    end
endmodule
