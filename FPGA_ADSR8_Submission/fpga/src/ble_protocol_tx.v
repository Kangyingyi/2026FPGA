`timescale 1ns/1ps

module ble_protocol_tx #(
    parameter integer MAX_PAYLOAD = 32
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        frame_start,
    input  wire [7:0]  frame_type,
    input  wire [15:0] frame_length,
    input  wire [255:0] frame_payload,
    output reg         busy,
    output wire        byte_valid,
    input  wire        byte_ready,
    output reg [7:0]   byte_out
);
    reg [5:0] byte_index;
    reg [7:0] checksum_latched;
    reg [7:0] type_latched;
    reg [15:0] length_latched;
    reg [255:0] payload_latched;
    reg [7:0] checksum_calc;
    integer k;

    always @* begin
        checksum_calc = frame_type + frame_length[7:0] + frame_length[15:8];
        if (frame_length >= 16'd1)  checksum_calc = checksum_calc + frame_payload[7:0];
        if (frame_length >= 16'd2)  checksum_calc = checksum_calc + frame_payload[15:8];
        if (frame_length >= 16'd3)  checksum_calc = checksum_calc + frame_payload[23:16];
        if (frame_length >= 16'd4)  checksum_calc = checksum_calc + frame_payload[31:24];
        if (frame_length >= 16'd5)  checksum_calc = checksum_calc + frame_payload[39:32];
        if (frame_length >= 16'd6)  checksum_calc = checksum_calc + frame_payload[47:40];
        if (frame_length >= 16'd7)  checksum_calc = checksum_calc + frame_payload[55:48];
        if (frame_length >= 16'd8)  checksum_calc = checksum_calc + frame_payload[63:56];
        if (frame_length >= 16'd9)  checksum_calc = checksum_calc + frame_payload[71:64];
        if (frame_length >= 16'd10) checksum_calc = checksum_calc + frame_payload[79:72];
        if (frame_length >= 16'd11) checksum_calc = checksum_calc + frame_payload[87:80];
        if (frame_length >= 16'd12) checksum_calc = checksum_calc + frame_payload[95:88];
        if (frame_length >= 16'd13) checksum_calc = checksum_calc + frame_payload[103:96];
        if (frame_length >= 16'd14) checksum_calc = checksum_calc + frame_payload[111:104];
        if (frame_length >= 16'd15) checksum_calc = checksum_calc + frame_payload[119:112];
        if (frame_length >= 16'd16) checksum_calc = checksum_calc + frame_payload[127:120];
        if (frame_length >= 16'd17) checksum_calc = checksum_calc + frame_payload[135:128];
        if (frame_length >= 16'd18) checksum_calc = checksum_calc + frame_payload[143:136];
        if (frame_length >= 16'd19) checksum_calc = checksum_calc + frame_payload[151:144];
        if (frame_length >= 16'd20) checksum_calc = checksum_calc + frame_payload[159:152];
        if (frame_length >= 16'd21) checksum_calc = checksum_calc + frame_payload[167:160];
        if (frame_length >= 16'd22) checksum_calc = checksum_calc + frame_payload[175:168];
        if (frame_length >= 16'd23) checksum_calc = checksum_calc + frame_payload[183:176];
        if (frame_length >= 16'd24) checksum_calc = checksum_calc + frame_payload[191:184];
        if (frame_length >= 16'd25) checksum_calc = checksum_calc + frame_payload[199:192];
        if (frame_length >= 16'd26) checksum_calc = checksum_calc + frame_payload[207:200];
        if (frame_length >= 16'd27) checksum_calc = checksum_calc + frame_payload[215:208];
        if (frame_length >= 16'd28) checksum_calc = checksum_calc + frame_payload[223:216];
        if (frame_length >= 16'd29) checksum_calc = checksum_calc + frame_payload[231:224];
        if (frame_length >= 16'd30) checksum_calc = checksum_calc + frame_payload[239:232];
        if (frame_length >= 16'd31) checksum_calc = checksum_calc + frame_payload[247:240];
        if (frame_length >= 16'd32) checksum_calc = checksum_calc + frame_payload[255:248];
    end

    assign byte_valid = busy;

    always @* begin
        case (byte_index)
            0: byte_out = 8'hA5;
            1: byte_out = type_latched;
            2: byte_out = length_latched[7:0];
            3: byte_out = length_latched[15:8];
            default: begin
                if (byte_index < (4 + length_latched)) byte_out = payload_latched[(byte_index-4)*8 +: 8];
                else byte_out = checksum_latched;
            end
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            busy            <= 1'b0;
            byte_index      <= 0;
            checksum_latched <= 0;
            type_latched    <= 0;
            length_latched  <= 0;
            payload_latched <= 0;
        end else begin
            if (!busy) begin
                if (frame_start) begin
                    busy             <= 1'b1;
                    byte_index       <= 0;
                    if (frame_length == 16'd0)
                        checksum_latched <= frame_type;
                    else if (frame_length == 16'd1)
                        checksum_latched <= frame_type + frame_length[7:0] + frame_payload[7:0];
                    else if (frame_length == 16'd2)
                        checksum_latched <= frame_type + frame_length[7:0] + frame_payload[7:0] + frame_payload[15:8];
                    else
                        checksum_latched <= checksum_calc;
                    type_latched     <= frame_type;
                    length_latched   <= frame_length;
                    payload_latched  <= frame_payload;
                end
            end else if (byte_ready) begin
                if (byte_index == (4 + length_latched)) busy <= 1'b0;
                else byte_index <= byte_index + 1'b1;
            end
        end
    end
endmodule
