`timescale 1ns/1ps

// Eight-voice additive DDS synthesizer.
// Each active key owns an independent phase accumulator. Samples are
// generated only on the I2S frame tick and summed after 1/8 scaling.
module polyphonic_dds (
    input  wire              clk,
    input  wire              rst_n,
    input  wire              sample_tick,
    input  wire [7:0]        key_state,
    input  wire signed [15:0] glide_target_q15,
    input  wire [3:0]        glide_speed,
    input  wire              vibrato_enable,
    input  wire [3:0]        vibrato_rate_hz,
    input  wire [10:0]       vibrato_depth_q15,
    output reg signed [15:0] sample
);

    localparam [31:0] STEP_C4 = 32'd23013218;
    localparam [31:0] STEP_D4 = 32'd25830607;
    localparam [31:0] STEP_E4 = 32'd28994561;
    localparam [31:0] STEP_F4 = 32'd30718596;
    localparam [31:0] STEP_G4 = 32'd34480685;
    localparam [31:0] STEP_A4 = 32'd38702809;
    localparam [31:0] STEP_B4 = 32'd43442144;
    localparam [31:0] STEP_C5 = 32'd46025557;

    wire signed [15:0] glide_q15;
    wire signed [15:0] vibrato_q15;
    pitch_glide glide_inst (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .target_q15(glide_target_q15), .speed(glide_speed),
        .current_q15(glide_q15)
    );
    pitch_vibrato vibrato_inst (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .enable(vibrato_enable), .rate_hz(vibrato_rate_hz),
        .depth_q15(vibrato_depth_q15), .delta_q15(vibrato_q15)
    );

    // Both effects use fractional frequency offsets, so their sum shifts
    // every active voice by the same musical interval without mixing voices.
    wire signed [16:0] offset_q15 =
        $signed({glide_q15[15], glide_q15}) +
        $signed({vibrato_q15[15], vibrato_q15});
    wire [16:0] ratio_q15 = 17'd32768 + offset_q15;
    wire [48:0] product0 = STEP_C4 * ratio_q15;
    wire [48:0] product1 = STEP_D4 * ratio_q15;
    wire [48:0] product2 = STEP_E4 * ratio_q15;
    wire [48:0] product3 = STEP_F4 * ratio_q15;
    wire [48:0] product4 = STEP_G4 * ratio_q15;
    wire [48:0] product5 = STEP_A4 * ratio_q15;
    wire [48:0] product6 = STEP_B4 * ratio_q15;
    wire [48:0] product7 = STEP_C5 * ratio_q15;
    wire [31:0] increment0 = product0[46:15];
    wire [31:0] increment1 = product1[46:15];
    wire [31:0] increment2 = product2[46:15];
    wire [31:0] increment3 = product3[46:15];
    wire [31:0] increment4 = product4[46:15];
    wire [31:0] increment5 = product5[46:15];
    wire [31:0] increment6 = product6[46:15];
    wire [31:0] increment7 = product7[46:15];

    reg [31:0] phase0;
    reg [31:0] phase1;
    reg [31:0] phase2;
    reg [31:0] phase3;
    reg [31:0] phase4;
    reg [31:0] phase5;
    reg [31:0] phase6;
    reg [31:0] phase7;

    reg signed [19:0] mix_sum;

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
                5'd16: sine_value = -16'sd0;
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

    wire signed [15:0] voice0 = key_state[0] ? (sine_value(phase0[31:27]) >>> 3) : 16'sd0;
    wire signed [15:0] voice1 = key_state[1] ? (sine_value(phase1[31:27]) >>> 3) : 16'sd0;
    wire signed [15:0] voice2 = key_state[2] ? (sine_value(phase2[31:27]) >>> 3) : 16'sd0;
    wire signed [15:0] voice3 = key_state[3] ? (sine_value(phase3[31:27]) >>> 3) : 16'sd0;
    wire signed [15:0] voice4 = key_state[4] ? (sine_value(phase4[31:27]) >>> 3) : 16'sd0;
    wire signed [15:0] voice5 = key_state[5] ? (sine_value(phase5[31:27]) >>> 3) : 16'sd0;
    wire signed [15:0] voice6 = key_state[6] ? (sine_value(phase6[31:27]) >>> 3) : 16'sd0;
    wire signed [15:0] voice7 = key_state[7] ? (sine_value(phase7[31:27]) >>> 3) : 16'sd0;

    always @* begin
        mix_sum = voice0 + voice1 + voice2 + voice3 +
                  voice4 + voice5 + voice6 + voice7;

        if (mix_sum > 20'sd32767)
            sample = 16'sh7fff;
        else if (mix_sum < -20'sd32768)
            sample = -16'sd32768;
        else
            sample = mix_sum[15:0];
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase0 <= 32'd0;
            phase1 <= 32'd0;
            phase2 <= 32'd0;
            phase3 <= 32'd0;
            phase4 <= 32'd0;
            phase5 <= 32'd0;
            phase6 <= 32'd0;
            phase7 <= 32'd0;
        end else if (sample_tick) begin
            phase0 <= key_state[0] ? phase0 + increment0 : 32'd0;
            phase1 <= key_state[1] ? phase1 + increment1 : 32'd0;
            phase2 <= key_state[2] ? phase2 + increment2 : 32'd0;
            phase3 <= key_state[3] ? phase3 + increment3 : 32'd0;
            phase4 <= key_state[4] ? phase4 + increment4 : 32'd0;
            phase5 <= key_state[5] ? phase5 + increment5 : 32'd0;
            phase6 <= key_state[6] ? phase6 + increment6 : 32'd0;
            phase7 <= key_state[7] ? phase7 + increment7 : 32'd0;
        end
    end

endmodule
