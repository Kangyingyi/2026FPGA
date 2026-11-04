`timescale 1ns/1ps

module led_guide (
    input  wire       guide_active,
    input  wire [2:0] target_pitch,
    output wire [7:0] led_out
);
    assign led_out = guide_active ? ~(8'b00000001 << target_pitch) : 8'hFF;
endmodule
