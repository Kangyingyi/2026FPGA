`timescale 1ns/1ps

module tx_arbiter (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       ctrl_valid,
    output wire       ctrl_ready,
    input  wire [7:0] ctrl_byte,
    input  wire       record_valid,
    output wire       record_ready,
    input  wire [7:0] record_byte,
    input  wire       uart_ready,
    output wire       uart_valid,
    output wire [7:0] uart_byte
);
    // The ACK is seven bytes and the PCM frame is 71 bytes. Once a frame
    // starts, keep the UART granted to that producer until its last byte.
    localparam [1:0] IDLE=0, CTRL=1, RECORD=2;
    reg [1:0] owner;
    reg [6:0] remaining;
    wire select_ctrl = (owner == CTRL) || (owner == IDLE && ctrl_valid);
    wire select_record = (owner == RECORD) ||
                         (owner == IDLE && !ctrl_valid && record_valid);
    wire handshake = uart_valid && uart_ready;

    assign uart_valid = select_ctrl ? ctrl_valid : (select_record && record_valid);
    assign uart_byte = select_ctrl ? ctrl_byte : record_byte;
    assign ctrl_ready = select_ctrl && uart_ready;
    assign record_ready = select_record && uart_ready;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            owner <= IDLE;
            remaining <= 0;
        end else if (handshake) begin
            if (owner == IDLE) begin
                owner <= select_ctrl ? CTRL : RECORD;
                remaining <= select_ctrl ? 7'd6 : 7'd70;
            end else if (remaining == 7'd1) begin
                owner <= IDLE;
                remaining <= 0;
            end else begin
                remaining <= remaining - 1'b1;
            end
        end
    end
endmodule
