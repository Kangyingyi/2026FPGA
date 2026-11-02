`timescale 1ns/1ps

module tb_ui_metrics;
    reg clk=0, rst_n=0, de=1;
    reg [11:0] x=0;
    reg [10:0] y=0;
    reg [3:0] polyphony_count=0;
    reg [11:0] peak_bcd=12'h389;
    reg peak_valid=1;
    wire [7:0] wave_addr,spectrum_addr,r,g,b;
    always #5 clk=~clk;
    hdmi_ui dut (
        .clk(clk),.rst_n(rst_n),.de(de),.x(x),.y(y),
        .polyphony_count(polyphony_count),.key_state(8'h00),
        .spectrum_level(64'd0),.spectrum_dft_level(8'd0),
        .peak_bcd(peak_bcd),.peak_valid(peak_valid),
        .wave_sample(16'sd0),.wave_addr(wave_addr),
        .spectrum_addr(spectrum_addr),.rgb_r(r),.rgb_g(g),.rgb_b(b)
    );
    task pixel;
        input [11:0] px;
        input [10:0] py;
        input [23:0] color;
        begin
            @(negedge clk); x=px; y=py;
            repeat (2) @(posedge clk); #1;
            if ({r,g,b} !== color)
                $fatal(1,"pixel (%0d,%0d) got %h expected %h",px,py,{r,g,b},color);
        end
    endtask
    initial begin
        repeat (3) @(negedge clk); rst_n=1;
        polyphony_count=4;
        pixel(12'd70,11'd132,24'he8f1fb); // digit 4, row 4 col 2
        polyphony_count=0;
        pixel(12'd70,11'd132,24'h152337); // digit 0 is blank there
        pixel(12'd818,11'd92,24'he8f1fb); // PEAK begins with P
        peak_bcd=12'h389;
        pixel(12'd820,11'd116,24'he8f1fb); // 3, row 0 col 1
        peak_valid=0;
        pixel(12'd820,11'd116,24'h152337); // dash is blank on row 0
        $display("TB_UI_METRICS_PASS"); $finish;
    end
endmodule
