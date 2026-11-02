`timescale 1ns/1ps

module tb_top_hdmi_integration;
    reg clk = 0, rst_n = 0, ble_rx = 1;
    reg [7:0] key_in = 0;
    tri1 adc_scl, adc_sda;
    wire ble_tx, i2s_bclk, i2s_lrck, i2s_din, pa_en;
    wire [7:0] led_out;
    wire tmds_clk_n_0, tmds_clk_p_0, hpd_en;
    wire [2:0] tmds_d_n_0, tmds_d_p_0;
    integer samples_seen = 0;
    integer nonzero_seen = 0;
    reg [7:0] previous_ptr;
    reg signed [15:0] expected_sample;

    always #5 clk = ~clk;

    top #(.DEBOUNCE_CYCLES(2), .UART_CLKS_PER_BIT(4)) dut (
        .sys_clk(clk), .rst_n(rst_n), .key_in(key_in),
        .BLE_RX(ble_rx), .BLE_TX(ble_tx), .OPTICAL_IN(1'b0),
        .ADC_SCL(adc_scl), .ADC_SDA(adc_sda), .led_out(led_out),
        .I2S_BCLK(i2s_bclk), .I2S_LRCK(i2s_lrck),
        .I2S_DIN(i2s_din), .PA_EN(pa_en),
        .tmds_clk_n_0(tmds_clk_n_0), .tmds_clk_p_0(tmds_clk_p_0),
        .tmds_d_n_0(tmds_d_n_0), .tmds_d_p_0(tmds_d_p_0),
        .hpd_en(hpd_en)
    );

    always @(posedge clk) begin
        if (rst_n && dut.sample_tick) begin
            previous_ptr = dut.hdmi_monitor_inst.waveform_history_inst.write_ptr;
            expected_sample = dut.audio_pressure;
            #1;
            if (dut.hdmi_monitor_inst.waveform_history_inst.sample_mem[previous_ptr] !== expected_sample)
                $fatal(1, "HDMI waveform does not capture the final I2S sample");
            samples_seen = samples_seen + 1;
            if (expected_sample != 0) nonzero_seen = nonzero_seen + 1;
        end
    end

    initial begin
        force dut.pressure_adc = 16'd26200;
        repeat (3) @(negedge clk);
        rst_n = 1;
        key_in[0] = 1;
        repeat (15000) @(negedge clk);
        if (samples_seen < 5 || nonzero_seen == 0)
            $fatal(1, "No live keyboard samples reached HDMI history");
        if (hpd_en !== 1'b1) $fatal(1, "HDMI HPD is disabled");
        $display("TOP_HDMI_INTEGRATION_PASS");
        $finish;
    end
endmodule
