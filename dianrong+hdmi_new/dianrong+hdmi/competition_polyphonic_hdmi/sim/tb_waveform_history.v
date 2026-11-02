`timescale 1ns/1ps

module tb_waveform_history;
    reg clk;
    reg rst_n;
    reg sample_tick;
    reg signed [15:0] audio_sample;
    reg [7:0] read_addr;
    reg [7:0] read_base_ptr;
    wire signed [15:0] read_sample;
    wire [7:0] write_ptr;
    wire [7:0] write_ptr_gray;
    integer i;

    waveform_history dut (
        .audio_clk   (clk),
        .rst_n       (rst_n),
        .sample_tick (sample_tick),
        .audio_sample(audio_sample),
        .read_addr   (read_addr),
        .read_base_ptr(read_base_ptr),
        .read_sample (read_sample),
        .write_ptr   (write_ptr),
        .write_ptr_gray(write_ptr_gray)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        sample_tick = 1'b0;
        audio_sample = 16'sd0;
        read_addr = 8'd0;
        read_base_ptr = 8'd0;
        #15;
        rst_n = 1'b1;

        for (i = 0; i < 260; i = i + 1) begin
            audio_sample = i;
            sample_tick = 1'b1;
            @(posedge clk);
            sample_tick = 1'b0;
            @(posedge clk);
        end

        if (write_ptr !== 8'd4)
            $fatal(1, "write pointer should wrap to 4, got %d", write_ptr);
        if (write_ptr_gray !== 8'h06)
            $fatal(1, "gray write pointer should be 06, got %h", write_ptr_gray);

        read_base_ptr = write_ptr;
        for (i = 0; i < 256; i = i + 1) begin
            read_addr = i[7:0];
            #1;
            if (read_sample !== (i + 4))
                $fatal(1, "chronological sample %d expected %d got %d", i, i + 4, read_sample);
        end

        $display("TB_WAVEFORM_HISTORY_PASS");
        $finish;
    end
endmodule
