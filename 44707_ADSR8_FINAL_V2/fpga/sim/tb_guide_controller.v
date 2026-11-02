`timescale 1ns/1ps

module tb_guide_controller;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg [7:0] key_in = 8'hFF;
    reg score_begin = 0, score_event_valid = 0, score_end = 0;
    reg guide_start = 0, guide_stop = 0;
    reg [2:0] score_pitch = 0;
    reg [15:0] score_duration = 0;
    wire [7:0] key_state, key_pressed;
    wire score_valid;
    wire [15:0] score_length;
    wire [5:0] rd_index;
    wire [2:0] rd_pitch;
    wire [15:0] rd_duration;
    wire guide_active;
    wire [2:0] target_pitch;
    wire [7:0] led_out;

    always #5 clk = ~clk;

    key_filter_8 #(.DEBOUNCE_CYCLES(2)) keys (
        .clk(clk), .rst_n(rst_n), .key_in(key_in), .key_state(key_state), .key_pressed(key_pressed)
    );
    score_ram #(.DEPTH(8)) score (
        .clk(clk), .rst_n(rst_n), .score_begin(score_begin), .event_valid(score_event_valid),
        .event_pitch(score_pitch), .event_duration(score_duration), .score_end(score_end),
        .rd_index(rd_index), .rd_pitch(rd_pitch), .rd_duration(rd_duration),
        .score_valid(score_valid), .score_length(score_length)
    );
    guide_controller guide (
        .clk(clk), .rst_n(rst_n), .key_pressed(key_pressed), .score_valid(score_valid),
        .score_length(score_length), .rd_index(rd_index), .rd_pitch(rd_pitch),
        .score_begin(score_begin), .score_event_valid(score_event_valid), .score_end(score_end),
        .guide_start(guide_start), .guide_stop(guide_stop), .guide_active(guide_active),
        .target_pitch(target_pitch)
    );
    led_guide leds (.guide_active(guide_active), .target_pitch(target_pitch), .led_out(led_out));

    task automatic add_event(input [2:0] p);
        begin
            @(negedge clk); score_pitch=p; score_duration=16'd10; score_event_valid=1;
            @(negedge clk); score_event_valid=0;
        end
    endtask
    task automatic press(input integer n);
        begin
            @(negedge clk); key_in[n]=1'b0;
            repeat (5) @(negedge clk);
            key_in[n]=1'b1;
            repeat (5) @(negedge clk);
        end
    endtask

    initial begin
        repeat (3) @(negedge clk); rst_n=1;
        @(negedge clk); score_begin=1;
        @(negedge clk); score_begin=0;
        add_event(3'd0); add_event(3'd3);
        @(negedge clk); score_end=1;
        @(negedge clk); score_end=0;
        repeat (2) @(negedge clk);
        guide_start=1;
        @(negedge clk); guide_start=0;
        repeat (2) @(negedge clk);
        if (led_out !== 8'b11111110) $fatal(1, "first guide LED mismatch: %b", led_out);
        press(1);
        if (led_out !== 8'b11111110) $fatal(1, "wrong key advanced the guide: %b", led_out);
        press(0);
        repeat (2) @(negedge clk);
        if (led_out !== 8'b11110111) $fatal(1, "second guide LED mismatch: %b", led_out);
        press(3);
        repeat (2) @(negedge clk);
        if (led_out !== 8'hFF) $fatal(1, "guide did not finish with LEDs off: %b", led_out);
        $display("GUIDE_CONTROLLER_PASS");
        $finish;
    end
endmodule
