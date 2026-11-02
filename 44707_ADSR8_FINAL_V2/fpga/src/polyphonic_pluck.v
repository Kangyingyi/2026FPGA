`timescale 1ns/1ps

// Eight independent guitar-like pluck voices.  The selected key(s) choose
// the pitches; one optical trigger plucks all keys currently held down.
module polyphonic_pluck (
    input  wire              clk,
    input  wire              rst_n,
    input  wire              sample_tick,
    input  wire [7:0]        key_state,
    input  wire [1:0]        octave_sel,
    input  wire              pluck_trigger,
    output reg signed [15:0] sample
);
    wire signed [15:0] v0, v1, v2, v3, v4, v5, v6, v7;
    integer mix;
    wire t0 = pluck_trigger && key_state[0];
    wire t1 = pluck_trigger && key_state[1];
    wire t2 = pluck_trigger && key_state[2];
    wire t3 = pluck_trigger && key_state[3];
    wire t4 = pluck_trigger && key_state[4];
    wire t5 = pluck_trigger && key_state[5];
    wire t6 = pluck_trigger && key_state[6];
    wire t7 = pluck_trigger && key_state[7];

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

    pluck_voice v_0(.clk(clk),.rst_n(rst_n),.sample_tick(sample_tick),.trigger(t0),.phase_step(selected_step(32'd23013218, octave_sel)),.sample(v0));
    pluck_voice v_1(.clk(clk),.rst_n(rst_n),.sample_tick(sample_tick),.trigger(t1),.phase_step(selected_step(32'd25830607, octave_sel)),.sample(v1));
    pluck_voice v_2(.clk(clk),.rst_n(rst_n),.sample_tick(sample_tick),.trigger(t2),.phase_step(selected_step(32'd28994561, octave_sel)),.sample(v2));
    pluck_voice v_3(.clk(clk),.rst_n(rst_n),.sample_tick(sample_tick),.trigger(t3),.phase_step(selected_step(32'd30718596, octave_sel)),.sample(v3));
    pluck_voice v_4(.clk(clk),.rst_n(rst_n),.sample_tick(sample_tick),.trigger(t4),.phase_step(selected_step(32'd34480685, octave_sel)),.sample(v4));
    pluck_voice v_5(.clk(clk),.rst_n(rst_n),.sample_tick(sample_tick),.trigger(t5),.phase_step(selected_step(32'd38702809, octave_sel)),.sample(v5));
    pluck_voice v_6(.clk(clk),.rst_n(rst_n),.sample_tick(sample_tick),.trigger(t6),.phase_step(selected_step(32'd43442144, octave_sel)),.sample(v6));
    pluck_voice v_7(.clk(clk),.rst_n(rst_n),.sample_tick(sample_tick),.trigger(t7),.phase_step(selected_step(32'd46025557, octave_sel)),.sample(v7));

    always @* begin
        // Divide by four to leave headroom for a four-note chord.
        mix = ($signed(v0)+$signed(v1)+$signed(v2)+$signed(v3)+
               $signed(v4)+$signed(v5)+$signed(v6)+$signed(v7)) >>> 2;
        if (mix > 16'sd30000) sample = 16'sd30000;
        else if (mix < -16'sd30000) sample = -16'sd30000;
        else sample = mix[15:0];
    end
endmodule
