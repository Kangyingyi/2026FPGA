`timescale 1ns/1ps

module ble_command_router (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        frame_valid,
    input  wire        frame_error,
    input  wire [7:0]  frame_type,
    input  wire [15:0] frame_length,
    input  wire [255:0] frame_payload,
    input  wire        score_valid,
    output reg         timbre_valid,
    output reg [2:0]   timbre_sel,
    output reg         octave_valid,
    output reg [1:0]   octave_sel,
    output reg         mode_valid,
    output reg [3:0]   mode_sel,
    output reg         score_begin,
    output reg         score_event_valid,
    output reg [2:0]   score_pitch,
    output reg [15:0]  score_duration,
    output reg         score_end,
    output reg         guide_start,
    output reg         guide_stop,
    output reg         record_start,
    output reg         record_stop,
    output reg         ack_valid,
    output reg [7:0]   ack_type,
    output reg [7:0]   ack_code
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            timbre_valid      <= 1'b0;
            timbre_sel        <= 0;
            octave_valid      <= 1'b0;
            octave_sel        <= 2'd1;
            mode_valid        <= 1'b0;
            mode_sel          <= 4'd0;
            score_begin       <= 1'b0;
            score_event_valid <= 1'b0;
            score_pitch       <= 0;
            score_duration    <= 0;
            score_end         <= 1'b0;
            guide_start       <= 1'b0;
            guide_stop        <= 1'b0;
            record_start      <= 1'b0;
            record_stop       <= 1'b0;
            ack_valid         <= 1'b0;
            ack_type          <= 0;
            ack_code          <= 0;
        end else begin
            timbre_valid      <= 1'b0;
            octave_valid      <= 1'b0;
            mode_valid        <= 1'b0;
            score_begin       <= 1'b0;
            score_event_valid <= 1'b0;
            score_end         <= 1'b0;
            guide_start       <= 1'b0;
            guide_stop        <= 1'b0;
            record_start      <= 1'b0;
            record_stop       <= 1'b0;
            ack_valid         <= 1'b0;
            if (frame_valid && !frame_error) begin
                ack_type <= frame_type;
                ack_code <= 8'd0;
                case (frame_type)
                    8'h10: begin
                        if (frame_length == 1 && frame_payload[7:0] < 8) begin
                            timbre_sel   <= frame_payload[2:0];
                            timbre_valid <= 1'b1;
                            ack_valid    <= 1'b1;
                        end else begin ack_code <= 8'd1; ack_valid <= 1'b1; end
                    end
                    8'h11: begin
                        if (frame_length == 1 && frame_payload[7:0] < 3) begin
                            octave_sel   <= frame_payload[1:0];
                            octave_valid <= 1'b1;
                            ack_valid    <= 1'b1;
                        end else begin ack_code <= 8'd1; ack_valid <= 1'b1; end
                    end
                    8'h12: begin
                        if (frame_length == 1 && frame_payload[7:0] < 9) begin
                            mode_sel   <= frame_payload[3:0];
                            mode_valid <= 1'b1;
                            ack_valid  <= 1'b1;
                        end else begin ack_code <= 8'd1; ack_valid <= 1'b1; end
                    end
                    8'h20: begin
                        if (frame_length == 0) begin score_begin <= 1'b1; ack_valid <= 1'b1; end
                        else begin ack_code <= 8'd1; ack_valid <= 1'b1; end
                    end
                    8'h21: begin
                        if (frame_length == 3 && frame_payload[2:0] < 8) begin
                            score_pitch        <= frame_payload[2:0];
                            score_duration     <= frame_payload[23:8];
                            score_event_valid  <= 1'b1;
                            ack_valid           <= 1'b1;
                        end else begin ack_code <= 8'd1; ack_valid <= 1'b1; end
                    end
                    8'h22: begin
                        if (frame_length == 0) begin score_end <= 1'b1; ack_valid <= 1'b1; end
                        else begin ack_code <= 8'd1; ack_valid <= 1'b1; end
                    end
                    8'h23: begin
                        if (frame_length == 0 && score_valid) begin guide_start <= 1'b1; ack_valid <= 1'b1; end
                        else begin ack_code <= 8'd1; ack_valid <= 1'b1; end
                    end
                    8'h24: begin
                        if (frame_length == 0) begin guide_stop <= 1'b1; ack_valid <= 1'b1; end
                        else begin ack_code <= 8'd1; ack_valid <= 1'b1; end
                    end
                    8'h30: begin
                        if (frame_length == 0) begin record_start <= 1'b1; ack_valid <= 1'b1; end
                        else begin ack_code <= 8'd1; ack_valid <= 1'b1; end
                    end
                    8'h31: begin
                        if (frame_length == 0) begin record_stop <= 1'b1; ack_valid <= 1'b1; end
                        else begin ack_code <= 8'd1; ack_valid <= 1'b1; end
                    end
                    default: begin ack_code <= 8'd2; ack_valid <= 1'b1; end
                endcase
            end
        end
    end
endmodule
