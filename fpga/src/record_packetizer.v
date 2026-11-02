`timescale 1ns/1ps

module record_packetizer (
    input  wire              clk,
    input  wire              rst_n,
    input  wire              record_start,
    input  wire              record_stop,
    input  wire              pcm_valid,
    input  wire signed [7:0] pcm_sample,
    output wire              tx_valid,
    input  wire              tx_ready,
    output reg  [7:0]       tx_byte,
    output reg              busy
);
    reg [7:0] samples [0:63];
    reg [5:0] sample_count;
    reg [6:0] tx_index;
    reg [15:0] frame_sequence;
    reg packet_pending;
    reg previous_record_start;
    reg [7:0] checksum;
    integer i;

    assign tx_valid = busy;

    always @* begin
        checksum = 8'h41 + 8'h42 + frame_sequence[7:0] + frame_sequence[15:8];
        for (i = 0; i < 64; i = i + 1) checksum = checksum + samples[i];
        case (tx_index)
            7'd0: tx_byte = 8'hA5;
            7'd1: tx_byte = 8'h41;
            7'd2: tx_byte = 8'h42;
            7'd3: tx_byte = 8'h00;
            7'd4: tx_byte = frame_sequence[7:0];
            7'd5: tx_byte = frame_sequence[15:8];
            7'd70: tx_byte = checksum;
            default: tx_byte = samples[tx_index - 6];
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sample_count <= 0;
            tx_index <= 0;
            frame_sequence <= 0;
            packet_pending <= 1'b0;
            previous_record_start <= 1'b0;
            busy <= 1'b0;
            for (i = 0; i < 64; i = i + 1) samples[i] <= 0;
        end else begin
            previous_record_start <= record_start;
            if (record_start && !previous_record_start) begin
                sample_count <= 0;
                frame_sequence <= 0;
                packet_pending <= 1'b0;
                busy <= 1'b0;
            end
            if (record_start && pcm_valid && !busy && !packet_pending) begin
                samples[sample_count] <= pcm_sample;
                if (sample_count == 6'd63) begin
                    sample_count <= 0;
                    packet_pending <= 1'b1;
                end else sample_count <= sample_count + 1'b1;
            end
            if (record_stop && record_start && !busy && !packet_pending && sample_count != 0) begin
                for (i = 0; i < 64; i = i + 1)
                    if (i >= sample_count) samples[i] <= 0;
                sample_count <= 0;
                packet_pending <= 1'b1;
            end
            if (!busy && packet_pending) begin
                busy <= 1'b1;
                tx_index <= 0;
                packet_pending <= 1'b0;
            end else if (busy && tx_ready) begin
                if (tx_index == 7'd70) begin
                    busy <= 1'b0;
                    frame_sequence <= frame_sequence + 1'b1;
                end else tx_index <= tx_index + 1'b1;
            end
        end
    end
endmodule
