`timescale 1ns/1ps

module tb_ui_data;
    reg  [7:0] key_state;
    wire [3:0] polyphony_count;
    wire [7:0] active_notes;
    wire [15:0] freq_hz0;
    wire [15:0] freq_hz1;
    wire [15:0] freq_hz2;
    wire [15:0] freq_hz3;
    wire [15:0] freq_hz4;
    wire [15:0] freq_hz5;
    wire [15:0] freq_hz6;
    wire [15:0] freq_hz7;

    ui_data dut (
        .key_state      (key_state),
        .polyphony_count(polyphony_count),
        .active_notes   (active_notes),
        .freq_hz0       (freq_hz0),
        .freq_hz1       (freq_hz1),
        .freq_hz2       (freq_hz2),
        .freq_hz3       (freq_hz3),
        .freq_hz4       (freq_hz4),
        .freq_hz5       (freq_hz5),
        .freq_hz6       (freq_hz6),
        .freq_hz7       (freq_hz7)
    );

    task check_count;
        input [7:0] keys;
        input [3:0] expected_count;
        begin
            key_state = keys;
            #1;
            if (polyphony_count !== expected_count)
                $fatal(1, "key_state=%h count=%d expected=%d", keys, polyphony_count, expected_count);
            if (active_notes !== keys)
                $fatal(1, "active_notes=%h expected=%h", active_notes, keys);
        end
    endtask

    initial begin
        key_state = 8'h00;
        #1;
        if (freq_hz0 !== 16'd262 || freq_hz1 !== 16'd294 ||
            freq_hz2 !== 16'd330 || freq_hz3 !== 16'd349 ||
            freq_hz4 !== 16'd392 || freq_hz5 !== 16'd440 ||
            freq_hz6 !== 16'd494 || freq_hz7 !== 16'd523)
            $fatal(1, "frequency table mismatch");

        check_count(8'h00, 4'd0);
        check_count(8'h01, 4'd1);
        check_count(8'h0f, 4'd4);
        check_count(8'h55, 4'd4);
        check_count(8'hff, 4'd8);

        $display("TB_UI_DATA_PASS");
        $finish;
    end
endmodule
