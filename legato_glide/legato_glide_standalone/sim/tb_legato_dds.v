`timescale 1ns/1ps

// Detects silent DDS output and phase resets during a legato transition.
module tb_legato_dds;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg sample_tick = 1'b0;
    reg active = 1'b0;
    reg [31:0] step = 32'd23013218;
    wire signed [15:0] sample;
    reg [31:0] before_phase;
    integer i;

    always #5 clk = ~clk;

    legato_dds dut (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .active(active), .step(step), .sample(sample)
    );

    task tick;
        begin
            @(negedge clk); sample_tick = 1'b1;
            @(posedge clk); #1;
            @(negedge clk); sample_tick = 1'b0;
        end
    endtask

    initial begin
        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        tick();
        if (sample !== 16'sd0 || dut.phase !== 32'd0)
            $fatal(1, "idle DDS was not silent and reset");
        active = 1'b1;
        for (i = 0; i < 16; i = i + 1) tick();
        if (sample === 16'sd0)
            $fatal(1, "held note did not generate nonzero PCM");
        before_phase = dut.phase;
        step = 32'd46025557;
        tick();
        if (dut.phase !== before_phase + step)
            $fatal(1, "legato pitch change reset DDS phase");
        active = 1'b0;
        tick();
        if (sample !== 16'sd0 || dut.phase !== 32'd0)
            $fatal(1, "all-release did not silence and reset DDS");
        $display("TB_LEGATO_DDS_PASS");
        $finish;
    end
endmodule
