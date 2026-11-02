`timescale 1ns/1ps

module tb_ble_protocol;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg byte_valid = 1'b0;
    reg [7:0] byte_in = 0;
    reg score_valid = 1'b0;
    wire frame_valid;
    wire [7:0] frame_type;
    wire [15:0] frame_length;
    wire [255:0] frame_payload;
    wire frame_error;
    wire byte_ready;

    wire timbre_valid, score_begin, score_event_valid, score_end;
    wire guide_start, guide_stop, record_start, record_stop;
    wire [2:0] timbre_sel, score_pitch;
    wire [15:0] score_duration;
    wire ack_valid;
    wire [7:0] ack_type, ack_code;

    always #5 clk = ~clk;

    ble_protocol_rx #(.MAX_PAYLOAD(32), .FRAME_TIMEOUT_CYCLES(4)) parser (
        .clk(clk), .rst_n(rst_n), .byte_valid(byte_valid), .byte_ready(byte_ready),
        .byte_in(byte_in), .frame_valid(frame_valid), .frame_error(frame_error),
        .frame_type(frame_type), .frame_length(frame_length), .frame_payload(frame_payload)
    );
    ble_command_router router (
        .clk(clk), .rst_n(rst_n), .frame_valid(frame_valid), .frame_error(frame_error),
        .frame_type(frame_type), .frame_length(frame_length), .frame_payload(frame_payload),
        .score_valid(score_valid),
        .timbre_valid(timbre_valid), .timbre_sel(timbre_sel), .score_begin(score_begin),
        .score_event_valid(score_event_valid), .score_pitch(score_pitch),
        .score_duration(score_duration), .score_end(score_end), .guide_start(guide_start),
        .guide_stop(guide_stop), .record_start(record_start), .record_stop(record_stop),
        .ack_valid(ack_valid), .ack_type(ack_type), .ack_code(ack_code)
    );

    task automatic send_byte(input [7:0] value);
        begin
            @(negedge clk); byte_in = value; byte_valid = 1'b1;
            @(negedge clk); byte_valid = 1'b0;
        end
    endtask

    task automatic send_frame(input [7:0] typ, input integer len, input [255:0] payload, input bit corrupt);
        integer i;
        reg [7:0] checksum;
        begin
            checksum = typ + len[7:0] + len[15:8];
            for (i = 0; i < len; i = i + 1) checksum = checksum + payload[i*8 +: 8];
            if (corrupt) checksum = checksum ^ 8'h01;
            send_byte(8'hA5); send_byte(typ); send_byte(len[7:0]); send_byte(len[15:8]);
            for (i = 0; i < len; i = i + 1) send_byte(payload[i*8 +: 8]);
            send_byte(checksum);
        end
    endtask

    integer timbre_count = 0;
    integer score_count = 0;
    integer ack_count = 0;
    integer error_ack_count = 0;
    always @(posedge clk) begin
        if (timbre_valid) begin
            if (timbre_count == 0 && timbre_sel !== 3'd5) $fatal(1, "first timbre mismatch");
            if (timbre_count == 1 && timbre_sel !== 3'd7) $fatal(1, "recovered timbre mismatch");
            timbre_count = timbre_count + 1;
        end
        if (score_event_valid) begin
            score_count = score_count + 1;
            if (score_pitch !== 3'd2 || score_duration !== 16'd20) $fatal(1, "score event mismatch");
        end
        if (ack_valid) begin
            ack_count = ack_count + 1;
            if (ack_code !== 8'd0) error_ack_count = error_ack_count + 1;
        end
    end

    initial begin
        repeat (3) @(negedge clk);
        rst_n = 1'b1;
        send_frame(8'h10, 1, 256'h05, 1'b0);
        send_frame(8'h21, 3, 256'h001402, 1'b0);
        send_frame(8'h23, 0, 256'd0, 1'b0);
        send_byte(8'hA5); send_byte(8'h10); send_byte(8'h01); send_byte(8'h00);
        repeat (6) @(negedge clk);
        send_frame(8'h10, 1, 256'h07, 1'b0);
        send_frame(8'h10, 1, 256'h07, 1'b1);
        repeat (5) @(negedge clk);
        if (timbre_count != 2) $fatal(1, "truncated frame was not recovered, timbre count=%0d", timbre_count);
        if (score_count != 1) $fatal(1, "expected one score command, got %0d", score_count);
        if (ack_count != 4) $fatal(1, "expected four ACKs, got %0d", ack_count);
        if (error_ack_count != 1) $fatal(1, "guide start without score was not rejected");
        $display("BLE_PROTOCOL_PASS");
        $finish;
    end
endmodule
