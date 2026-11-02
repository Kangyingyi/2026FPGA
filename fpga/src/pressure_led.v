`timescale 1ns/1ps

// Display the ADS1115 pressure level on the active-low PMOD-LED8.
// At 0 V all eight LEDs are on.  As the pressure increases, LEDs
// led_out[0] through led_out[7] turn off one at a time.
module pressure_led #(
    parameter integer ADC_MAX = 26200
) (
    input  wire [15:0] adc_value,
    output wire [7:0]  led_out
);
    reg [7:0] led_reg;

    always @* begin
        // Active-low LED: 0 means on, 1 means off.  The thresholds are
        // ADC_MAX/8, 2*ADC_MAX/8, ..., 7*ADC_MAX/8.  Written as a ladder
        // so synthesis does not infer a run-time divider.
        if (adc_value < (ADC_MAX/8))       led_reg = 8'b0000_0000;
        else if (adc_value < (ADC_MAX*2/8)) led_reg = 8'b0000_0001;
        else if (adc_value < (ADC_MAX*3/8)) led_reg = 8'b0000_0011;
        else if (adc_value < (ADC_MAX*4/8)) led_reg = 8'b0000_0111;
        else if (adc_value < (ADC_MAX*5/8)) led_reg = 8'b0000_1111;
        else if (adc_value < (ADC_MAX*6/8)) led_reg = 8'b0001_1111;
        else if (adc_value < (ADC_MAX*7/8)) led_reg = 8'b0011_1111;
        else if (adc_value < ADC_MAX)       led_reg = 8'b0111_1111;
        else                                led_reg = 8'b1111_1111;
    end

    assign led_out = led_reg;
endmodule
