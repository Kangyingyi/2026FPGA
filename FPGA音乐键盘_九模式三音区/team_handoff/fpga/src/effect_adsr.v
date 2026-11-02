`timescale 1ns/1ps

// Lightweight envelope for the imported sine-only glide and vibrato demos.
// The pressure/ADSR baseline keeps its original per-voice envelope.
module effect_adsr (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               sample_tick,
    input  wire               gate,
    input  wire signed [15:0] audio_in,
    output wire signed [15:0] audio_out
);
    localparam [2:0] IDLE=0, ATTACK=1, DECAY=2, SUSTAIN=3, RELEASE=4;
    reg [2:0] state;
    reg [15:0] level;
    wire signed [32:0] product = $signed(audio_in) * $signed({1'b0, level});
    assign audio_out = product >>> 15;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            level <= 0;
        end else if (sample_tick) begin
            if (!gate) begin
                if (level > 16'd4) begin level <= level - 16'd4; state <= RELEASE; end
                else begin level <= 0; state <= IDLE; end
            end else begin
                case (state)
                    IDLE: begin level <= 0; state <= ATTACK; end
                    ATTACK: begin
                        if (level >= 16'd31743) begin level <= 16'd32767; state <= DECAY; end
                        else level <= level + 16'd1024;
                    end
                    DECAY: begin
                        if (level <= 16'd23033) begin level <= 16'd22937; state <= SUSTAIN; end
                        else level <= level - 16'd96;
                    end
                    RELEASE: state <= ATTACK;
                    default: level <= 16'd22937;
                endcase
            end
        end
    end
endmodule
