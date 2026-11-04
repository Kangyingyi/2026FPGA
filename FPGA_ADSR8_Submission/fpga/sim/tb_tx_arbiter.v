`timescale 1ns/1ps
module tb_tx_arbiter;
    reg clk=0, rst_n=0, ctrl_valid=0, record_valid=0;
    reg [7:0] ctrl_byte=0, record_byte=0;
    wire ctrl_ready, record_ready, uart_valid;
    wire [7:0] uart_byte;
    integer ctrl_sent=0, record_sent=0, received=0;
    always #5 clk=~clk;
    tx_arbiter dut(.clk(clk),.rst_n(rst_n),.ctrl_valid(ctrl_valid),.ctrl_ready(ctrl_ready),
        .ctrl_byte(ctrl_byte),.record_valid(record_valid),.record_ready(record_ready),
        .record_byte(record_byte),.uart_ready(1'b1),.uart_valid(uart_valid),.uart_byte(uart_byte));
    always @(posedge clk) if (rst_n) begin
        if (uart_valid) begin
            if (received < 71) begin
                if (uart_byte !== (8'h40 + received)) $fatal(1,"audio interleaved at %d",received);
            end else if (uart_byte !== (8'hA0 + received - 71)) $fatal(1,"control corrupt at %d",received);
            received = received + 1;
        end
        if (record_valid && record_ready) begin
            record_sent = record_sent + 1;
            record_byte <= 8'h40 + record_sent;
            if (record_sent == 71) record_valid <= 0;
        end
        if (ctrl_valid && ctrl_ready) begin
            ctrl_sent = ctrl_sent + 1;
            ctrl_byte <= 8'hA0 + ctrl_sent;
            if (ctrl_sent == 7) ctrl_valid <= 0;
        end
    end
    initial begin
        #20; rst_n=1; record_valid=1; record_byte=8'h40;
        repeat(4) @(negedge clk);
        ctrl_valid=1; ctrl_byte=8'hA0;
        repeat(90) @(negedge clk);
        if (received != 78 || record_sent != 71 || ctrl_sent != 7)
            $fatal(1,"counts received=%d record=%d control=%d",received,record_sent,ctrl_sent);
        $display("TX_ARBITER_PASS"); $finish;
    end
endmodule
