`timescale 1ns/1ps
module tb_top_mode_uart;
    reg clk=0, rst_n=0, rx=1;
    tri1 scl, sda;
    wire tx;
    wire [7:0] led;
    wire bclk, lrck, din, pa;
    reg [7:0] reply [0:6];
    integer j;
    always #10 clk=~clk;
    top #(.DEBOUNCE_CYCLES(2), .UART_CLKS_PER_BIT(8)) dut (
        .sys_clk(clk),.rst_n(rst_n),.key_in(8'h00),.BLE_RX(rx),.OPTICAL_IN(1'b0),
        .ADC_SCL(scl),.ADC_SDA(sda),.BLE_TX(tx),.led_out(led),
        .I2S_BCLK(bclk),.I2S_LRCK(lrck),.I2S_DIN(din),.PA_EN(pa)
    );
    task send_byte(input [7:0] value);
        begin
            @(negedge clk); rx=0;
            repeat(8) @(negedge clk);
            for (integer bit_no=0; bit_no<8; bit_no=bit_no+1) begin
                rx=value[bit_no]; repeat(8) @(negedge clk);
            end
            rx=1; repeat(8) @(negedge clk);
        end
    endtask
    task recv_byte(output reg [7:0] value);
        begin
            @(negedge tx);
            repeat(12) @(posedge clk); // middle of data bit zero
            for (integer bit_no=0; bit_no<8; bit_no=bit_no+1) begin
                value[bit_no]=tx;
                if (bit_no != 7) repeat(8) @(posedge clk);
            end
        end
    endtask
    task check_mode(input [7:0] mode);
      begin
        fork
            begin
                repeat(5) @(negedge clk);
                send_byte(8'hA5); send_byte(8'h12); send_byte(8'h01);
                send_byte(8'h00); send_byte(mode); send_byte(8'h13 + mode);
            end
            begin
                for (j=0; j<7; j=j+1) recv_byte(reply[j]);
            end
        join
        if (dut.mode_sel !== mode[3:0]) $fatal(1,"mode=%d expected=%d",dut.mode_sel,mode);
        if (reply[0]!==8'hA5 || reply[1]!==8'h7F || reply[2]!==8'h02 ||
            reply[3]!==8'h00 || reply[4]!==8'h12 || reply[5]!==8'h00 ||
            reply[6]!==8'h93) $fatal(1,"bad ACK %h %h %h %h %h %h %h",
                reply[0],reply[1],reply[2],reply[3],reply[4],reply[5],reply[6]);
      end
    endtask
    task check_octave(input [7:0] octave);
      begin
        fork
            begin
                repeat(5) @(negedge clk);
                send_byte(8'hA5); send_byte(8'h11); send_byte(8'h01);
                send_byte(8'h00); send_byte(octave); send_byte(8'h12 + octave);
            end
            begin
                for (j=0; j<7; j=j+1) recv_byte(reply[j]);
            end
        join
        if (dut.octave_sel !== octave[1:0]) $fatal(1,"octave=%d expected=%d",dut.octave_sel,octave);
        if (reply[0]!==8'hA5 || reply[1]!==8'h7F || reply[2]!==8'h02 ||
            reply[3]!==8'h00 || reply[4]!==8'h11 || reply[5]!==8'h00 ||
            reply[6]!==8'h92) $fatal(1,"bad octave ACK");
      end
    endtask
    task reject_octave;
      begin
        fork
            begin
                repeat(5) @(negedge clk);
                send_byte(8'hA5); send_byte(8'h11); send_byte(8'h01);
                send_byte(8'h00); send_byte(8'h03); send_byte(8'h15);
            end
            begin
                for (j=0; j<7; j=j+1) recv_byte(reply[j]);
            end
        join
        if (dut.octave_sel !== 2'd2) $fatal(1,"invalid octave changed selection");
        if (reply[4]!==8'h11 || reply[5]!==8'h01 || reply[6]!==8'h93)
            $fatal(1,"invalid octave was not rejected");
      end
    endtask
    initial begin
        #100; rst_n=1;
        if (dut.octave_sel !== 2'd1) $fatal(1,"default octave is not middle");
        check_mode(8'd3);
        check_mode(8'd6);
        check_mode(8'd7);
        check_mode(8'd8);
        check_octave(8'd0);
        check_octave(8'd1);
        check_octave(8'd2);
        reject_octave();
        $display("TOP_MODE_UART_PASS"); $finish;
    end
    initial begin #1_000_000; $fatal(1,"timeout"); end
endmodule
