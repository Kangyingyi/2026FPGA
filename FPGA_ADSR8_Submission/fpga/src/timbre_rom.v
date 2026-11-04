`timescale 1ns/1ps

module timbre_rom (
    input  wire [31:0] phase,
    input  wire [2:0]  tone,
    output reg  signed [15:0] value
);
    wire signed [15:0] f1, f2, f3, f4;
    integer mix;
    sine_lut s1(.phase(phase), .value(f1));
    sine_lut s2(.phase(phase << 1), .value(f2));
    sine_lut s3(.phase(phase + (phase << 1)), .value(f3));
    sine_lut s4(.phase(phase << 3), .value(f4));

    always @* begin
        case (tone)
            3'd0: mix = f1 + (f2 >>> 2) + (f3 >>> 3);       // piano
            3'd1: mix = f1 + (f2 >>> 1);                     // electric piano
            3'd2: mix = f1 + (f3 >>> 1);                     // guitar
            3'd3: mix = (f1 >>> 1) + f4;                    // bell
            3'd4: mix = f1 + (f2 >>> 1) + (f3 >>> 2);       // organ
            3'd5: mix = f1 + (f2 >>> 2);                     // flute
            3'd6: mix = f1 + (f3 >>> 2) - (f2 >>> 3);       // clarinet
            3'd7: mix = (f1 >>> 1) + (f2 >>> 1) + (f4 >>> 3); // violin
            default: mix = f1;
        endcase
        if (mix > 20000) value = 16'sd20000;
        else if (mix < -20000) value = -16'sd20000;
        else value = mix[15:0];
    end
endmodule
