`timescale 1ns/1ps

module tb_protocol_tx;
    reg clk=0, rst_n=0, frame_start=0;
    reg [7:0] frame_type=8'h10;
    reg [15:0] frame_length=16'd1;
    reg [255:0] frame_payload=256'h05;
    wire busy, byte_valid;
    wire [7:0] byte_out;
    reg [7:0] captured [0:5];
    integer count=0;
    always #5 clk=~clk;

    ble_protocol_tx tx (
        .clk(clk), .rst_n(rst_n), .frame_start(frame_start), .frame_type(frame_type),
        .frame_length(frame_length), .frame_payload(frame_payload), .busy(busy),
        .byte_valid(byte_valid), .byte_ready(1'b1), .byte_out(byte_out)
    );

    always @(posedge clk) begin
        if (byte_valid) begin
            captured[count] = byte_out;
            count = count + 1;
            if (count == 2) begin
                frame_type = 8'h22;
                frame_length = 16'd0;
                frame_payload = 0;
            end
        end
    end

    initial begin
        repeat (3) @(negedge clk); rst_n=1;
        @(negedge clk); frame_start=1;
        @(negedge clk); frame_start=0;
        repeat (15) @(negedge clk);
        if (count != 6) $fatal(1, "expected six bytes, got %0d", count);
        if (captured[0] !== 8'hA5 || captured[1] !== 8'h10 || captured[2] !== 8'h01 ||
            captured[3] !== 8'h00 || captured[4] !== 8'h05 || captured[5] !== 8'h16)
            $fatal(1, "frame was not latched: %h %h %h %h %h %h", captured[0], captured[1], captured[2], captured[3], captured[4], captured[5]);
        $display("PROTOCOL_TX_PASS");
        $finish;
    end
endmodule
