`timescale 1ns/1ps
module pressure_gain (
    input wire [15:0] adc_value,
    input wire signed [15:0] audio_in,
    output wire signed [15:0] audio_out
);
    // ADC 26200 is about 3.3 V. Multiplying by 1.25 (shift/add) and
    // taking bits 14:7 approximates the 0..255 gain ramp without a
    // full-width combinational divider in the 50 MHz audio path.
    wire [17:0] scaled_pressure = {2'b00, adc_value} +
                                   ({2'b00, adc_value} >> 2);
    wire [7:0] gain_q8 = adc_value >= 16'd26200 ? 8'hFF :
                         scaled_pressure[14:7];
    wire signed [24:0] product = $signed(audio_in) * $signed({1'b0, gain_q8});
    assign audio_out = product >>> 8;
endmodule
