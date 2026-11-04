`timescale 1ns/1ps

// FPGA-only plucked-string voice.  A trigger starts the phase at zero and
// excites a guitar-like harmonic wavetable.  The envelope then decays on
// every audio sample, giving a clear pluck and a natural tail.
module pluck_voice #(
    // At 48.8 kHz this gives about 1.7 s from full scale to silence.
    // The previous value 12 made the sound only about 56 ms long.
    parameter [15:0] DECAY_STEP  = 16'd4
) (
    input  wire              clk,
    input  wire              rst_n,
    input  wire              sample_tick,
    input  wire              trigger,
    input  wire [31:0]       phase_step,
    output reg signed [15:0] sample
);
    reg [31:0] phase;
    reg [15:0] envelope;
    wire signed [15:0] raw_sample;
    wire signed [32:0] product = $signed(raw_sample) * $signed({1'b0, envelope});
    wire signed [32:0] scaled = product >>> 15;

    // Tone 2 is the existing guitar harmonic mix.
    expressive_osc osc(
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .trigger(trigger), .tone(3'd2), .phase(phase), .sample(raw_sample)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase    <= 0;
            envelope <= 0;
            sample   <= 0;
        end else if (sample_tick) begin
            if (trigger) begin
                phase    <= 0;
                envelope <= 16'd32767;
            end else if (envelope > DECAY_STEP) begin
                phase    <= phase + phase_step;
                envelope <= envelope - DECAY_STEP;
            end else begin
                phase    <= 0;
                envelope <= 0;
            end
            sample <= scaled[15:0];
        end
    end
endmodule
