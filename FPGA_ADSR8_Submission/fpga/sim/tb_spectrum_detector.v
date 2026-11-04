`timescale 1ns/1ps

module tb_spectrum_detector;
    reg clk;
    reg rst_n;
    reg sample_tick;
    reg signed [15:0] audio_sample;
    wire [63:0] spectrum_level;
    wire frame_tick;
    wire frame_toggle;

    spectrum_detector dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .sample_tick    (sample_tick),
        .audio_sample   (audio_sample),
        .spectrum_level (spectrum_level),
        .frame_tick     (frame_tick),
        .frame_toggle   (frame_toggle)
    );

    localparam [31:0] STEP_C4 = 32'd23013218;
    localparam [31:0] STEP_D4 = 32'd25830607;
    reg [31:0] phase_c4;
    reg [31:0] phase_d4;
    integer frame_count;
    integer i;

    function signed [15:0] sine_value;
        input [4:0] index;
        begin
            case (index)
                0:sine_value=0; 1:sine_value=2346; 2:sine_value=4592; 3:sine_value=6668;
                4:sine_value=8485; 5:sine_value=9978; 6:sine_value=11087; 7:sine_value=11770;
                8:sine_value=12000; 9:sine_value=11770; 10:sine_value=11087; 11:sine_value=9978;
                12:sine_value=8485; 13:sine_value=6668; 14:sine_value=4592; 15:sine_value=2346;
                16:sine_value=0; 17:sine_value=-2346; 18:sine_value=-4592; 19:sine_value=-6668;
                20:sine_value=-8485; 21:sine_value=-9978; 22:sine_value=-11087; 23:sine_value=-11770;
                24:sine_value=-12000; 25:sine_value=-11770; 26:sine_value=-11087; 27:sine_value=-9978;
                28:sine_value=-8485; 29:sine_value=-6668; 30:sine_value=-4592; 31:sine_value=-2346;
                default:sine_value=0;
            endcase
        end
    endfunction

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (frame_tick)
            frame_count = frame_count + 1;
    end

    task drive_window;
        input integer use_c4;
        input integer use_d4;
        integer sample_value;
        integer n;
        begin
            for (n = 0; n < 1024; n = n + 1) begin
                sample_value = 0;
                if (use_c4 != 0)
                    sample_value = sample_value + sine_value(phase_c4[31:27]);
                if (use_d4 != 0)
                    sample_value = sample_value + sine_value(phase_d4[31:27]);
                @(negedge clk);
                audio_sample = sample_value / 2;
                sample_tick = 1'b1;
                @(negedge clk);
                sample_tick = 1'b0;
                phase_c4 = phase_c4 + STEP_C4;
                phase_d4 = phase_d4 + STEP_D4;
            end
            repeat (3) @(posedge clk);
        end
    endtask

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        sample_tick = 1'b0;
        audio_sample = 16'sd0;
        phase_c4 = 0;
        phase_d4 = 0;
        frame_count = 0;
        #12;
        rst_n = 1'b1;

        drive_window(1, 0);
        if (frame_count != 1)
            $fatal(1, "expected one published spectrum frame");
        if (frame_toggle !== 1'b1)
            $fatal(1, "first frame must toggle the publication flag");
        if (spectrum_level[7:0] <= spectrum_level[23:16])
            $fatal(1, "C4 energy must exceed D4 for C4-only input");

        drive_window(1, 1);
        if (frame_count != 2)
            $fatal(1, "expected two published spectrum frames");
        if (frame_toggle !== 1'b0)
            $fatal(1, "second frame must toggle the publication flag back");
        if (spectrum_level[7:0] == 0 || spectrum_level[15:8] == 0)
            $fatal(1, "C4+D4 input must publish two active bands");

        $display("TB_SPECTRUM_DETECTOR_PASS");
        $finish;
    end
endmodule
