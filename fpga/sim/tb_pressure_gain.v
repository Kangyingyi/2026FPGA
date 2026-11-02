`timescale 1ns/1ps
module tb_pressure_gain;
    reg [15:0] adc_value;
    reg signed [15:0] audio_in;
    wire signed [15:0] audio_out;
    pressure_gain dut(.adc_value(adc_value),.audio_in(audio_in),.audio_out(audio_out));
    initial begin
        adc_value=0; audio_in=16'sd24000; #1;
        if(audio_out!==0) $fatal(1,"zero pressure");
        adc_value=16'd13100; #1;
        if(audio_out<16'sd11500 || audio_out>16'sd12500) $fatal(1,"mid gain %d",audio_out);
        adc_value=16'd26200; #1;
        if(audio_out<16'sd23700 || audio_out>16'sd24000) $fatal(1,"full gain %d",audio_out);
        audio_in=-16'sd24000; #1;
        if(audio_out>-16'sd23700 || audio_out<-16'sd24000) $fatal(1,"negative gain %d",audio_out);
        $display("PRESSURE_GAIN_PASS"); $finish;
    end
endmodule
