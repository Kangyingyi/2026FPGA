`timescale 1ns/1ps

module tb_top_smoke;
    reg clk=0, rst_n=0, ble_rx=1;
    reg [7:0] key_in=8'h00;
    wire ble_tx;
    wire [7:0] led_out;
    wire i2s_bclk, i2s_lrck, i2s_din, pa_en;
    tri1 adc_scl, adc_sda;
    reg saw_bclk=0;
    always #5 clk=~clk;
    always @(posedge clk) if (i2s_bclk) saw_bclk=1;

    top #(.DEBOUNCE_CYCLES(2), .UART_CLKS_PER_BIT(4)) dut (
        .sys_clk(clk), .rst_n(rst_n), .key_in(key_in), .BLE_RX(ble_rx), .BLE_TX(ble_tx),
        .OPTICAL_IN(1'b0), .led_out(led_out), .I2S_BCLK(i2s_bclk), .I2S_LRCK(i2s_lrck), .I2S_DIN(i2s_din), .PA_EN(pa_en)
    );

    initial begin
        repeat (3) @(negedge clk); rst_n=1;
        repeat (1000) @(negedge clk);
        if (dut.key_state !== 8'h00) $fatal(1, "untouched capacitive keys are active");
        key_in[0]=1'b1;
        repeat (5) @(negedge clk);
        if (dut.key_state[0] !== 1'b1) $fatal(1, "touch not recognized");
        key_in[0]=1'b0;
        repeat (5) @(negedge clk);
        if (dut.key_state !== 8'h00) $fatal(1, "release not recognized");
        if (!saw_bclk) $fatal(1, "I2S BCLK never toggled");
        if (led_out !== 8'hFF) $fatal(1, "inactive guide LEDs must be off: %h", led_out);
        if (ble_tx !== 1'b1) $fatal(1, "BLE TX not idle high");
        if (pa_en !== 1'b0) $fatal(1, "PA_EN not enabled-low");
        $display("TOP_SMOKE_PASS");
        $finish;
    end
endmodule
