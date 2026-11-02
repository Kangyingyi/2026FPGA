`timescale 1ns/1ps

module polyphonic_timbre (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        sample_tick,
    input  wire [7:0]  key_state,
    input  wire [2:0]  timbre_sel,
    input  wire [1:0]  octave_sel,
    output reg signed [15:0] sample
);
    wire signed [15:0] v0, v1, v2, v3, v4, v5, v6, v7;
    integer mix;

    function [31:0] selected_step;
        input [31:0] middle_step;
        input [1:0] octave;
        begin
            case (octave)
                2'd0: selected_step = middle_step >> 1;
                2'd2: selected_step = middle_step << 1;
                default: selected_step = middle_step;
            endcase
        end
    endfunction

    // C4 D4 E4 F4 G4 A4 B4 C5, matching the glide/vibrato engines.
    instrument_voice v_0(.clk(clk), .rst_n(rst_n), .sample_tick(sample_tick), .note_active(key_state[0]), .tone_sel(timbre_sel), .phase_step(selected_step(32'd23013218, octave_sel)), .sample(v0));
    instrument_voice v_1(.clk(clk), .rst_n(rst_n), .sample_tick(sample_tick), .note_active(key_state[1]), .tone_sel(timbre_sel), .phase_step(selected_step(32'd25830607, octave_sel)), .sample(v1));
    instrument_voice v_2(.clk(clk), .rst_n(rst_n), .sample_tick(sample_tick), .note_active(key_state[2]), .tone_sel(timbre_sel), .phase_step(selected_step(32'd28994561, octave_sel)), .sample(v2));
    instrument_voice v_3(.clk(clk), .rst_n(rst_n), .sample_tick(sample_tick), .note_active(key_state[3]), .tone_sel(timbre_sel), .phase_step(selected_step(32'd30718596, octave_sel)), .sample(v3));
    instrument_voice v_4(.clk(clk), .rst_n(rst_n), .sample_tick(sample_tick), .note_active(key_state[4]), .tone_sel(timbre_sel), .phase_step(selected_step(32'd34480685, octave_sel)), .sample(v4));
    instrument_voice v_5(.clk(clk), .rst_n(rst_n), .sample_tick(sample_tick), .note_active(key_state[5]), .tone_sel(timbre_sel), .phase_step(selected_step(32'd38702809, octave_sel)), .sample(v5));
    instrument_voice v_6(.clk(clk), .rst_n(rst_n), .sample_tick(sample_tick), .note_active(key_state[6]), .tone_sel(timbre_sel), .phase_step(selected_step(32'd43442144, octave_sel)), .sample(v6));
    instrument_voice v_7(.clk(clk), .rst_n(rst_n), .sample_tick(sample_tick), .note_active(key_state[7]), .tone_sel(timbre_sel), .phase_step(selected_step(32'd46025557, octave_sel)), .sample(v7));

    always @* begin
        mix = ($signed(v0) + $signed(v1) + $signed(v2) + $signed(v3) +
               $signed(v4) + $signed(v5) + $signed(v6) + $signed(v7)) >>> 2;
        if (mix > 16'sd30000) sample = 16'sd30000;
        else if (mix < -16'sd30000) sample = -16'sd30000;
        else sample = mix[15:0];
    end
endmodule
