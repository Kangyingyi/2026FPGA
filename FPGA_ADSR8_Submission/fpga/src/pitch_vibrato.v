`timescale 1ns/1ps

// Triangle-wave pitch vibrato, updated once per 48.828125 kHz audio sample.
// The output is a signed Q15 fractional frequency change.
module pitch_vibrato (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               sample_tick,
    input  wire               enable,
    input  wire [3:0]         rate_hz,
    input  wire [10:0]        depth_q15,
    output wire signed [15:0] delta_q15
);
    // round(2^32 / 48828.125) = 87961 phase units per sample per hertz.
    localparam [31:0] STEP_PER_HZ = 32'd87961;
    reg [31:0] phase;
    wire [3:0] bounded_rate = (rate_hz > 4'd12) ? 4'd12 : rate_hz;
    wire [31:0] phase_step = STEP_PER_HZ * bounded_rate;
    wire [7:0] p = phase[31:24];
    reg signed [9:0] triangle;
    wire signed [21:0] product = $signed({1'b0, depth_q15}) * triangle;
    wire signed [21:0] scaled = product >>> 7;

    always @* begin
        if (p < 8'd64)
            triangle = $signed({1'b0, p}) <<< 1;
        else if (p < 8'd128)
            triangle = (9'sd128 - $signed({1'b0, p})) <<< 1;
        else if (p < 8'd192)
            triangle = -(($signed({1'b0, p}) - 9'sd128) <<< 1);
        else
            triangle = ($signed({2'b00, p}) - 10'sd256) <<< 1;
    end

    assign delta_q15 = enable ? scaled[15:0] : 16'sd0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            phase <= 32'd0;
        else if (sample_tick) begin
            if (!enable || bounded_rate == 4'd0)
                phase <= 32'd0;
            else
                phase <= phase + phase_step;
        end
    end
endmodule
