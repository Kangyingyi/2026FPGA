`timescale 1ns/1ps

// TTP226 direct-mode outputs are configured active-high through AHL=1.
// This test locks the required OUT1..OUT8 -> key_state[0]..[7] behavior.
module tb_key_filter_8_touch;
    reg        clk = 1'b0;
    reg        rst_n = 1'b0;
    reg [7:0]  touch_in = 8'h00;
    wire [7:0] key_state;
    wire [7:0] key_pressed;

    always #5 clk = ~clk;

    key_filter_8 #(
        .DEBOUNCE_CYCLES(3)
    ) dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .key_in     (touch_in),
        .key_state  (key_state),
        .key_pressed(key_pressed)
    );

    task wait_cycles;
        input integer cycles;
        integer i;
        begin
            for (i = 0; i < cycles; i = i + 1)
                @(posedge clk);
        end
    endtask

    initial begin
        wait_cycles(2);
        rst_n = 1'b1;
        wait_cycles(4);

        #1;
        if (key_state !== 8'h00)
            $fatal(1, "idle TTP226 inputs must produce key_state=0, got %h", key_state);

        touch_in = 8'b0000_0001;
        wait_cycles(6);
        #1;
        if (key_state !== 8'b0000_0001)
            $fatal(1, "OUT1 must map to key_state[0], got %h", key_state);

        touch_in = 8'b1000_0010;
        wait_cycles(6);
        #1;
        if (key_state !== 8'b1000_0010)
            $fatal(1, "OUT2/OUT8 must map to key_state[1]/[7], got %h", key_state);

        touch_in = 8'h00;
        wait_cycles(6);
        #1;
        if (key_state !== 8'h00)
            $fatal(1, "released TTP226 inputs must clear key_state, got %h", key_state);

        $display("TB_KEY_FILTER_8_TOUCH_PASS");
        $finish;
    end
endmodule
