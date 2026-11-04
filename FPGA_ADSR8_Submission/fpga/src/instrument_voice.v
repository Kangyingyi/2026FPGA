`timescale 1ns/1ps

module instrument_voice (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        sample_tick,
    input  wire        note_active,
    input  wire [2:0]  tone_sel,
    input  wire [31:0] phase_step,
    output reg signed [15:0] sample
);
    reg [31:0] phase;
    reg [15:0] envelope;
    reg        previous_active;
    reg [2:0]  env_state;
    localparam [2:0] ENV_IDLE=3'd0, ENV_ATTACK=3'd1, ENV_DECAY=3'd2,
                     ENV_SUSTAIN=3'd3, ENV_RELEASE=3'd4;
    // Steps per audio sample (~48828 Hz). Sustain is Q15 amplitude.
    reg [15:0] attack_step, decay_step, sustain_level, release_step;
    always @* begin
        case (tone_sel)
            3'd0: begin attack_step=336; decay_step=3; sustain_level=8192; release_step=1; end // piano
            3'd1: begin attack_step=168; decay_step=2; sustain_level=11469; release_step=1; end // e-piano
            3'd2: begin attack_step=671; decay_step=4; sustain_level=4915; release_step=1; end // guitar
            3'd3: begin attack_step=671; decay_step=1; sustain_level=0; release_step=1; end // bell
            3'd4: begin attack_step=134; decay_step=1; sustain_level=32767; release_step=14; end // organ
            3'd5: begin attack_step=17; decay_step=2; sustain_level=26214; release_step=4; end // flute
            3'd6: begin attack_step=27; decay_step=2; sustain_level=24575; release_step=4; end // clarinet
            default: begin attack_step=6; decay_step=1; sustain_level=27852; release_step=2; end // violin
        endcase
    end
    wire signed [15:0] raw_sample;
    // Keep the full product width explicit so Gowin does not silently
    // truncate the 17-bit envelope operand during synthesis.
    wire signed [32:0] product = $signed(raw_sample) * $signed({1'b0, envelope});
    wire signed [32:0] scaled = product >>> 15;
    wire signed [15:0] scaled_sample = scaled[15:0];

    expressive_osc osc(
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .trigger(note_active && !previous_active), .tone(tone_sel),
        .phase(phase), .sample(raw_sample)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase <= 0;
            envelope <= 0;
            previous_active <= 1'b0;
            env_state <= ENV_IDLE;
            sample <= 0;
        end else begin
            if (sample_tick) begin
                previous_active <= note_active;
                if (note_active) begin
                    if (!previous_active) begin
                        phase <= 0;
                        envelope <= 0;
                        env_state <= ENV_ATTACK;
                    end else begin
                        phase <= phase + phase_step;
                        case (env_state)
                            ENV_ATTACK: begin
                                if ({1'b0,envelope} + {1'b0,attack_step} >= 17'd32767) begin
                                    envelope <= 16'd32767;
                                    env_state <= ENV_DECAY;
                                end else envelope <= envelope + attack_step;
                            end
                            ENV_DECAY: begin
                                if (envelope <= sustain_level + decay_step) begin
                                    envelope <= sustain_level;
                                    env_state <= ENV_SUSTAIN;
                                end else envelope <= envelope - decay_step;
                            end
                            ENV_SUSTAIN: envelope <= sustain_level;
                            ENV_RELEASE: begin
                                // A new key press is handled above; this
                                // branch mainly covers a re-trigger race.
                                env_state <= ENV_ATTACK;
                            end
                            default: env_state <= ENV_ATTACK;
                        endcase
                    end
                end else begin
                    if (envelope != 0) phase <= phase + phase_step;
                    if (envelope > release_step) begin
                        envelope <= envelope - release_step;
                        env_state <= ENV_RELEASE;
                    end else begin
                        envelope <= 0;
                        phase <= 0;
                        env_state <= ENV_IDLE;
                    end
                end
                sample <= scaled_sample;
            end else if (!note_active && envelope == 0) begin
                sample <= 0;
            end
        end
    end
endmodule
