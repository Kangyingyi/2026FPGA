`timescale 1ns/1ps

// Verify every touch bit drives the intended nominal DDS note.
module tb_note_map;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg sample_tick = 1'b0;
    reg [7:0] key_state = 8'h00;
    wire signed [15:0] sample;
    reg [31:0] expected [0:7];
    integer k;

    always #5 clk = ~clk;

    vibrato_dds #(.DEPTH_Q15(11'd0)) dut (
        .clk(clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .key_state(key_state), .sample(sample)
    );

    task tick;
        begin
            @(negedge clk); sample_tick = 1'b1;
            @(negedge clk); sample_tick = 1'b0;
            #1;
        end
    endtask

    initial begin
        expected[0] = 32'd23013218; // C4
        expected[1] = 32'd25830607; // D4
        expected[2] = 32'd28994561; // E4
        expected[3] = 32'd30718596; // F4
        expected[4] = 32'd34480685; // G4
        expected[5] = 32'd38702809; // A4
        expected[6] = 32'd43442144; // B4
        expected[7] = 32'd46025557; // C5
        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        for (k = 0; k < 8; k = k + 1) begin
            key_state = 8'b1 << k;
            tick();
            if (dut.phase[k] !== expected[k])
                $fatal(1, "key %0d wrong note step: %0d", k+1, dut.phase[k]);
            key_state = 8'h00;
            tick();
            if (dut.phase[k] !== 32'd0 || sample !== 16'sd0)
                $fatal(1, "key %0d did not release", k+1);
        end
        $display("TB_NOTE_MAP_PASS");
        $finish;
    end
endmodule
