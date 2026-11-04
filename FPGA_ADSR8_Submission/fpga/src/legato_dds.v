`timescale 1ns/1ps

// One phase-continuous sine voice; only all-release resets the oscillator.
module legato_dds (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               sample_tick,
    input  wire               active,
    input  wire [31:0]        step,
    output wire signed [15:0] sample
);
    function signed [15:0] sine_value;
        input [4:0] index;
        begin
            case (index)
                5'd0 : sine_value =  16'sd0;
                5'd1 : sine_value =  16'sd2346;
                5'd2 : sine_value =  16'sd4592;
                5'd3 : sine_value =  16'sd6668;
                5'd4 : sine_value =  16'sd8485;
                5'd5 : sine_value =  16'sd9978;
                5'd6 : sine_value =  16'sd11087;
                5'd7 : sine_value =  16'sd11770;
                5'd8 : sine_value =  16'sd12000;
                5'd9 : sine_value =  16'sd11770;
                5'd10: sine_value =  16'sd11087;
                5'd11: sine_value =  16'sd9978;
                5'd12: sine_value =  16'sd8485;
                5'd13: sine_value =  16'sd6668;
                5'd14: sine_value =  16'sd4592;
                5'd15: sine_value =  16'sd2346;
                5'd16: sine_value =  16'sd0;
                5'd17: sine_value = -16'sd2346;
                5'd18: sine_value = -16'sd4592;
                5'd19: sine_value = -16'sd6668;
                5'd20: sine_value = -16'sd8485;
                5'd21: sine_value = -16'sd9978;
                5'd22: sine_value = -16'sd11087;
                5'd23: sine_value = -16'sd11770;
                5'd24: sine_value = -16'sd12000;
                5'd25: sine_value = -16'sd11770;
                5'd26: sine_value = -16'sd11087;
                5'd27: sine_value = -16'sd9978;
                5'd28: sine_value = -16'sd8485;
                5'd29: sine_value = -16'sd6668;
                5'd30: sine_value = -16'sd4592;
                5'd31: sine_value = -16'sd2346;
                default: sine_value = 16'sd0;
            endcase
        end
    endfunction

    reg [31:0] phase;
    assign sample = active ? sine_value(phase[31:27]) : 16'sd0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            phase <= 32'd0;
        else if (sample_tick)
            phase <= active ? phase + step : 32'd0;
    end
endmodule
