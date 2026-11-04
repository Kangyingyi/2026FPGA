`timescale 1ns/1ps

module ble_protocol_rx #(
    parameter integer MAX_PAYLOAD = 32,
    parameter integer FRAME_TIMEOUT_CYCLES = 100000
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        byte_valid,
    output wire        byte_ready,
    input  wire [7:0]  byte_in,
    output reg         frame_valid,
    output reg         frame_error,
    output reg [7:0]   frame_type,
    output reg [15:0]  frame_length,
    output reg [255:0] frame_payload
);
    localparam [2:0] WAIT_MAGIC=3'd0, GET_TYPE=3'd1, GET_LEN0=3'd2,
                     GET_LEN1=3'd3, GET_PAYLOAD=3'd4, GET_CHECKSUM=3'd5;
    reg [2:0] state;
    reg [7:0] checksum;
    reg [5:0] payload_index;
    reg [31:0] timeout_count;

    assign byte_ready = 1'b1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= WAIT_MAGIC;
            checksum      <= 0;
            payload_index <= 0;
            frame_valid   <= 1'b0;
            frame_error   <= 1'b0;
            frame_type    <= 0;
            frame_length  <= 0;
            frame_payload <= 0;
            timeout_count <= 0;
        end else begin
            frame_valid <= 1'b0;
            frame_error <= 1'b0;
            if (byte_valid) begin
                timeout_count <= 0;
                case (state)
                    WAIT_MAGIC: begin
                        if (byte_in == 8'hA5) state <= GET_TYPE;
                    end
                    GET_TYPE: begin
                        frame_type <= byte_in;
                        checksum <= byte_in;
                        state <= GET_LEN0;
                    end
                    GET_LEN0: begin
                        frame_length[7:0] <= byte_in;
                        checksum <= checksum + byte_in;
                        state <= GET_LEN1;
                    end
                    GET_LEN1: begin
                        frame_length[15:8] <= byte_in;
                        checksum <= checksum + byte_in;
                        if ({byte_in, frame_length[7:0]} > MAX_PAYLOAD) begin
                            frame_error <= 1'b1;
                            state <= WAIT_MAGIC;
                        end else if ({byte_in, frame_length[7:0]} == 0) begin
                            state <= GET_CHECKSUM;
                        end else begin
                            payload_index <= 0;
                            state <= GET_PAYLOAD;
                        end
                    end
                    GET_PAYLOAD: begin
                        frame_payload[payload_index*8 +: 8] <= byte_in;
                        checksum <= checksum + byte_in;
                        if (payload_index == frame_length - 1) state <= GET_CHECKSUM;
                        else payload_index <= payload_index + 1'b1;
                    end
                    GET_CHECKSUM: begin
                        state <= WAIT_MAGIC;
                        if (byte_in == checksum) frame_valid <= 1'b1;
                        else frame_error <= 1'b1;
                    end
                    default: state <= WAIT_MAGIC;
                endcase
            end else if (state != WAIT_MAGIC) begin
                if (timeout_count >= FRAME_TIMEOUT_CYCLES - 1) begin
                    state <= WAIT_MAGIC;
                    timeout_count <= 0;
                    frame_error <= 1'b1;
                end else begin
                    timeout_count <= timeout_count + 1'b1;
                end
            end else begin
                timeout_count <= 0;
            end
        end
    end
endmodule
