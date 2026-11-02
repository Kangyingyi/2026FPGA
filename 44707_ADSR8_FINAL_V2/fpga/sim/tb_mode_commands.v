`timescale 1ns/1ps
module tb_mode_commands;
    reg clk=0, rst_n=0, byte_valid=0;
    reg [7:0] byte_in=0;
    wire frame_valid, frame_error, mode_valid, ack_valid;
    wire [7:0] frame_type, ack_type, ack_code;
    wire [15:0] frame_length;
    wire [255:0] frame_payload;
    wire [3:0] mode_sel;
    integer mode_count=0, bad_count=0, ack_count=0;
    always #5 clk=~clk;

    ble_protocol_rx #(.MAX_PAYLOAD(32), .FRAME_TIMEOUT_CYCLES(100)) parser (
        .clk(clk), .rst_n(rst_n), .byte_valid(byte_valid), .byte_ready(), .byte_in(byte_in),
        .frame_valid(frame_valid), .frame_error(frame_error), .frame_type(frame_type),
        .frame_length(frame_length), .frame_payload(frame_payload)
    );
    ble_command_router router (
        .clk(clk), .rst_n(rst_n), .frame_valid(frame_valid), .frame_error(frame_error),
        .frame_type(frame_type), .frame_length(frame_length), .frame_payload(frame_payload),
        .score_valid(1'b0), .timbre_valid(), .timbre_sel(),
        .mode_valid(mode_valid), .mode_sel(mode_sel), .score_begin(), .score_event_valid(),
        .score_pitch(), .score_duration(), .score_end(), .guide_start(), .guide_stop(),
        .record_start(), .record_stop(), .ack_valid(ack_valid),
        .ack_type(ack_type), .ack_code(ack_code)
    );
    task send_byte(input [7:0] value);
        begin
            @(negedge clk); byte_in=value; byte_valid=1;
            @(negedge clk); byte_valid=0;
        end
    endtask
    task send_mode(input [7:0] mode);
        begin
            send_byte(8'hA5); send_byte(8'h12); send_byte(8'h01);
            send_byte(8'h00); send_byte(mode); send_byte(8'h13+mode);
        end
    endtask
    always @(posedge clk) begin
        if (mode_valid) begin
            mode_count=mode_count+1;
            if (mode_sel !== mode_count-1) $fatal(1,"mode %0d mismatch: %0d",mode_count-1,mode_sel);
        end
        if (ack_valid) begin
            ack_count=ack_count+1;
            if (ack_type !== 8'h12) $fatal(1,"wrong ACK type");
            if (ack_code != 0) bad_count=bad_count+1;
        end
    end
    integer i;
    initial begin
        repeat(3) @(negedge clk); rst_n=1;
        for(i=0;i<9;i=i+1) send_mode(i[7:0]);
        send_mode(8'd9);
        repeat(10) @(negedge clk);
        if (mode_count!=9 || ack_count!=10 || bad_count!=1)
            $fatal(1,"mode/ACK counts %0d %0d %0d",mode_count,ack_count,bad_count);
        $display("MODE_COMMANDS_PASS"); $finish;
    end
endmodule
