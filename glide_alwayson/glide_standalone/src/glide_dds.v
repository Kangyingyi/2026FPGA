`timescale 1ns/1ps

// Eight independent sine voices. Each voice slides into its own target note.
module glide_dds #(
    parameter signed [15:0] START_OFFSET_Q15 = -16'sd3577,
    parameter integer RAMP_STEP_Q8 = 153
) (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               sample_tick,
    input  wire [7:0]         key_state,
    output reg signed [15:0] sample
);
    function [31:0] base_step;
        input integer key_index;
        begin
            case (key_index)
                0: base_step = 32'd23013218; // C4
                1: base_step = 32'd25830607; // D4
                2: base_step = 32'd28994561; // E4
                3: base_step = 32'd30718596; // F4
                4: base_step = 32'd34480685; // G4
                5: base_step = 32'd38702809; // A4
                6: base_step = 32'd43442144; // B4
                7: base_step = 32'd46025557; // C5
                default: base_step = 32'd0;
            endcase
        end
    endfunction

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

    wire signed [15:0] voice [0:7];
    wire signed [15:0] offset_q15 [0:7];
    reg [31:0] phase [0:7];
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin: pitch
            localparam [31:0] NOTE_STEP = base_step(i);
            wire [16:0] ratio_q15 = 17'd32768 +
                $signed({offset_q15[i][15], offset_q15[i]});
            wire [48:0] product = NOTE_STEP * ratio_q15;
            wire [31:0] increment = product[46:15];

            glide_voice_pitch #(
                .START_OFFSET_Q15(START_OFFSET_Q15),
                .RAMP_STEP_Q8(RAMP_STEP_Q8)
            ) voice_pitch (
                .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick),
                .key_active(key_state[i]), .offset_q15(offset_q15[i])
            );

            assign voice[i] = key_state[i] ?
                (sine_value(phase[i][31:27]) >>> 3) : 16'sd0;

            always @(posedge clk or negedge rst_n) begin
                if (!rst_n)
                    phase[i] <= 32'd0;
                else if (sample_tick)
                    phase[i] <= key_state[i] ? phase[i] + increment : 32'd0;
            end
        end
    endgenerate

    integer j;
    reg signed [19:0] mix_sum;
    always @* begin
        mix_sum = 20'sd0;
        for (j = 0; j < 8; j = j + 1)
            mix_sum = mix_sum + voice[j];
        if (mix_sum > 20'sd32767)
            sample = 16'sh7fff;
        else if (mix_sum < -20'sd32768)
            sample = -16'sd32768;
        else
            sample = mix_sum[15:0];
    end
endmodule
