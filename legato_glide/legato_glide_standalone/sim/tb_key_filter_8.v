`timescale 1ns/1ps

// A shared vector counter would let chatter on OUT1 delay stable OUT2.
module tb_key_filter_8;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg [7:0] key_in = 8'h00;
    wire [7:0] key_state;
    wire [7:0] key_pressed;
    integer presses [0:7];
    integer i;
    integer j;

    always #5 clk = ~clk;

    key_filter_8 #(.DEBOUNCE_CYCLES(4)) dut (
        .clk(clk), .rst_n(rst_n), .key_in(key_in),
        .key_state(key_state), .key_pressed(key_pressed)
    );

    always @(posedge clk) begin
        #1;
        if (rst_n)
            for (j = 0; j < 8; j = j + 1)
                if (key_pressed[j]) presses[j] = presses[j] + 1;
    end

    task cycles;
        input integer n;
        integer c;
        begin
            for (c = 0; c < n; c = c + 1) begin
                @(posedge clk);
                #2;
            end
        end
    endtask

    initial begin
        for (i = 0; i < 8; i = i + 1) presses[i] = 0;
        cycles(2);
        if (key_state !== 8'h00 || key_pressed !== 8'h00)
            $fatal(1, "reset did not clear keys");
        rst_n = 1'b1;

        @(negedge clk); key_in[0] = 1'b1;
        cycles(9);
        if (key_state[0] !== 1'b1 || presses[0] != 1)
            $fatal(1, "stable OUT1 not confirmed exactly once");
        cycles(7);
        if (presses[0] != 1)
            $fatal(1, "held OUT1 repeated key_pressed pulse");

        @(negedge clk); key_in[0] = 1'b0;
        cycles(9);
        if (key_state[0] !== 1'b0)
            $fatal(1, "OUT1 release not confirmed");
        @(negedge clk); key_in[0] = 1'b1;
        cycles(2);
        @(negedge clk); key_in[0] = 1'b0;
        cycles(9);
        if (key_state[0] !== 1'b0 || presses[0] != 1)
            $fatal(1, "short bounce was treated as a press");

        @(negedge clk); key_in[1] = 1'b1;
        for (i = 0; i < 8; i = i + 1) begin
            key_in[0] = ~key_in[0];
            cycles(2);
        end
        if (key_state[1] !== 1'b1 || presses[1] != 1)
            $fatal(1, "OUT1 chatter delayed stable OUT2");

        @(negedge clk); key_in = 8'h84;
        cycles(9);
        if (key_state !== 8'h84 || presses[2] != 1 || presses[7] != 1)
            $fatal(1, "simultaneous OUT3/OUT8 not independent");

        $display("TB_KEY_FILTER_8_PASS");
        $finish;
    end
endmodule
