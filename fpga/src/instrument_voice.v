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
    // Values are in the 16-bit sample amplitude domain.  At the current
    // sample rate these give a short attack, audible decay, held sustain and
    // roughly 170 ms release at the current ~48.8 kHz audio sample rate.
    localparam [15:0] SUSTAIN_LEVEL = 16'd22937; // 70% of full scale
    localparam [15:0] ATTACK_STEP   = 16'd1024;
    localparam [15:0] DECAY_STEP    = 16'd96;
    localparam [15:0] RELEASE_STEP  = 16'd192;
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
            previous_active <= note_active;
            if (sample_tick) begin
                if (note_active) begin
                    if (!previous_active) begin
                        phase <= 0;
                        envelope <= 0;
                        env_state <= ENV_ATTACK;
                    end else begin
                        phase <= phase + phase_step;
                        case (env_state)
                            ENV_ATTACK: begin
                                if ({1'b0,envelope} + {1'b0,ATTACK_STEP} >= 17'd32767) begin
                                    envelope <= 16'd32767;
                                    env_state <= ENV_DECAY;
                                end else envelope <= envelope + ATTACK_STEP;
                            end
                            ENV_DECAY: begin
                                if (envelope <= SUSTAIN_LEVEL + DECAY_STEP) begin
                                    envelope <= SUSTAIN_LEVEL;
                                    env_state <= ENV_SUSTAIN;
                                end else envelope <= envelope - DECAY_STEP;
                            end
                            ENV_SUSTAIN: envelope <= SUSTAIN_LEVEL;
                            ENV_RELEASE: begin
                                // A new key press is handled above; this
                                // branch mainly covers a re-trigger race.
                                env_state <= ENV_ATTACK;
                            end
                            default: env_state <= ENV_ATTACK;
                        endcase
                    end
                end else begin
                    if (envelope > RELEASE_STEP) begin
                        envelope <= envelope - RELEASE_STEP;
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
