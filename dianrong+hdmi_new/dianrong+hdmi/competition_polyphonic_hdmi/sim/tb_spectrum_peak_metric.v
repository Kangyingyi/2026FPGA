`timescale 1ns/1ps

module tb_spectrum_peak_metric;
    reg clk=0, rst_n=0, write_en=0, frame_tick=0;
    reg [7:0] write_addr=0, write_level=0;
    wire [11:0] peak_bcd;
    wire peak_valid, frame_toggle;
    always #5 clk=~clk;

    spectrum_peak_metric dut (
        .clk(clk), .rst_n(rst_n), .write_en(write_en),
        .write_addr(write_addr), .write_level(write_level),
        .frame_tick(frame_tick), .peak_bcd(peak_bcd),
        .peak_valid(peak_valid), .frame_toggle(frame_toggle)
    );

    task bin;
        input [7:0] addr, level;
        begin
            @(negedge clk); write_en=1; write_addr=addr; write_level=level;
            @(negedge clk); write_en=0;
        end
    endtask

    task end_frame;
        begin
            @(negedge clk); frame_tick=1;
            @(negedge clk); frame_tick=0;
            repeat (30) @(negedge clk);
        end
    endtask

    initial begin
        repeat (3) @(negedge clk); rst_n=1;
        bin(8'd33,8'd50); bin(8'd49,8'd80); bin(8'd125,8'd10);
        end_frame();
        if (!peak_valid || peak_bcd !== 12'h389 || frame_toggle !== 1'b1)
            $fatal(1,"49-bin peak expected 389 Hz, got %h valid=%b toggle=%b",peak_bcd,peak_valid,frame_toggle);
        bin(8'd33,8'd0); bin(8'd49,8'd0);
        end_frame();
        if (peak_valid || frame_toggle !== 1'b0)
            $fatal(1,"silence must clear previous peak");
        bin(8'd0,8'd200); bin(8'd33,8'd70);
        end_frame();
        if (!peak_valid || peak_bcd !== 12'h262 || frame_toggle !== 1'b1)
            $fatal(1,"DC must be ignored and bin 33 shown as 262 Hz, got %h",peak_bcd);
        // spectrum_dft publishes its final bin and frame_tick together.
        @(negedge clk); write_en=1; write_addr=8'd125;
        write_level=8'd100; frame_tick=1;
        @(negedge clk); write_en=0; frame_tick=0;
        repeat (30) @(negedge clk);
        if (!peak_valid || peak_bcd !== 12'h993 || frame_toggle !== 1'b0)
            $fatal(1,"simultaneous final-bin/frame event must show 993 Hz, got %h",peak_bcd);
        $display("TB_SPECTRUM_PEAK_METRIC_PASS"); $finish;
    end
endmodule
