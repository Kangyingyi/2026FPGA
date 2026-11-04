`timescale 1ns/1ps
module tb_audio_delay;
    reg clk=0, rst_n=0, sample_tick=0, enable=0;
    reg signed [15:0] audio_in=0;
    wire signed [15:0] audio_out;
    always #5 clk=~clk;
    audio_delay #(.DEPTH(4), .PTR_W(3)) dut (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .enable(enable), .audio_in(audio_in), .audio_out(audio_out)
    );
    task tick(input signed [15:0] value);
        begin
            @(negedge clk); audio_in=value; sample_tick=1;
            @(negedge clk); sample_tick=0;
        end
    endtask
    initial begin
        repeat(2) @(negedge clk); rst_n=1; enable=1;
        tick(16'sd1000);
        if(audio_out!==16'sd1000) $fatal(1,"dry signal=%0d",audio_out);
        tick(0); tick(0); tick(0);
        tick(0); if(audio_out!==16'sd500) $fatal(1,"first echo=%0d",audio_out);
        tick(0); tick(0); tick(0);
        tick(0); if(audio_out!==16'sd312) $fatal(1,"feedback echo=%0d",audio_out);
        @(negedge clk); enable=0;
        tick(0); if(audio_out!==0) $fatal(1,"disable did not clear output");
        $display("AUDIO_DELAY_PASS"); $finish;
    end
endmodule
