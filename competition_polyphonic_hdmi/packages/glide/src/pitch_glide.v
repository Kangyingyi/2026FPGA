`timescale 1ns/1ps

// Global pitch glide. Q15 is a fractional frequency change: 0 is nominal,
// +4015 is about +200 cents, and -3577 is about -200 cents.
module pitch_glide (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               sample_tick,
    input  wire signed [15:0] target_q15,
    input  wire [3:0]         speed,
    output reg signed [15:0] current_q15
);
    // Bound the integration interface to approximately +/- two semitones.
    wire signed [15:0] bounded_target =
        (target_q15 > 16'sd4096) ? 16'sd4096 :
        (target_q15 < -16'sd4096) ? -16'sd4096 : target_q15;
    wire signed [16:0] error_q15 =
        $signed({bounded_target[15], bounded_target}) -
        $signed({current_q15[15], current_q15});
    wire [3:0] bounded_speed = (speed > 4'd6) ? 4'd6 : speed;
    wire [4:0] shift_count = {1'b0, bounded_speed} + 5'd7;
    wire signed [16:0] shifted = error_q15 >>> shift_count;
    wire signed [16:0] step_q15 =
        ((shifted == 0) && (error_q15 > 0)) ? 17'sd1 : shifted;
    wire signed [16:0] next_q15 =
        $signed({current_q15[15], current_q15}) + step_q15;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            current_q15 <= 16'sd0;
        else if (sample_tick) begin
            if (speed == 4'd0)
                current_q15 <= bounded_target;
            else if (error_q15 != 0)
                current_q15 <= next_q15[15:0];
        end
    end
endmodule
