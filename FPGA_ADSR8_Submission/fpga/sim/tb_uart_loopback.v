`timescale 1ns/1ps

module tb_uart_loopback;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg tx_start = 1'b0;
    reg [7:0] tx_data = 8'h00;
    wire tx_line;
    wire tx_busy;
    wire [7:0] rx_data;
    wire rx_valid;
    wire rx_overrun;
    wire rx_framing_error;

    always #5 clk = ~clk;

    uart_tx #(.CLKS_PER_BIT(4)) tx (
        .clk(clk), .rst_n(rst_n), .data_in(tx_data), .data_valid(tx_start),
        .tx(tx_line), .busy(tx_busy)
    );
    uart_rx #(.CLKS_PER_BIT(4)) rx (
        .clk(clk), .rst_n(rst_n), .rx(tx_line), .data_ready(1'b1),
        .data_out(rx_data), .data_valid(rx_valid), .overrun(rx_overrun),
        .framing_error(rx_framing_error)
    );

    task automatic send_byte(input [7:0] value);
        begin
            @(negedge clk);
            while (tx_busy) @(negedge clk);
            tx_data = value;
            tx_start = 1'b1;
            @(negedge clk);
            tx_start = 1'b0;
        end
    endtask

    integer received = 0;
    always @(posedge clk) begin
        if (rx_valid) begin
            $display("RX byte %h at %0t", rx_data, $time);
            if (received == 0 && rx_data !== 8'hA5) $fatal(1, "first byte mismatch: %h", rx_data);
            if (received == 1 && rx_data !== 8'h3C) $fatal(1, "second byte mismatch: %h", rx_data);
            received = received + 1;
        end
    end

    initial begin
        repeat (3) @(negedge clk);
        rst_n = 1'b1;
        send_byte(8'hA5);
        send_byte(8'h3C);
        repeat (100) @(negedge clk);
        if (received != 2) $fatal(1, "expected 2 bytes, got %0d", received);
        if (rx_overrun || rx_framing_error) $fatal(1, "unexpected UART error");
        $display("UART_LOOPBACK_PASS");
        $finish;
    end
endmodule
