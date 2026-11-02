`timescale 1ns/1ps

// Compact synthesizable triangle approximation used as the wavetable carrier.
// The phase accumulator still gives exact pitch steps; this avoids a large ROM.
module sine_lut (
    input  wire [31:0] phase,
    output reg  signed [15:0] value
);
    integer p;
    integer wave_value;
    always @* begin
        p = phase[31:24];
        if (p < 64) wave_value = -16384 + (p << 9);
        else if (p < 128) wave_value = 16384 - ((p - 64) << 9);
        else if (p < 192) wave_value = -16384 + ((p - 128) << 9);
        else wave_value = 16384 - ((p - 192) << 9);
        value = wave_value[15:0];
    end
endmodule
