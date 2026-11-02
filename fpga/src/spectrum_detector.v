`timescale 1ns/1ps

// Eight fixed-frequency, sample-domain quadrature detectors.
// The input is the actual DDS audio sample, not the key bitmap. Each
// detector integrates 1024 samples and publishes one display level per frame.
module spectrum_detector (
    input  wire              clk,
    input  wire              rst_n,
    input  wire              sample_tick,
    input  wire signed [15:0] audio_sample,
    output reg  [63:0]       spectrum_level,
    output reg               frame_tick,
    output reg               frame_toggle
);
    localparam [31:0] STEP_C4 = 32'd23013218;
    localparam [31:0] STEP_D4 = 32'd25830607;
    localparam [31:0] STEP_E4 = 32'd28994561;
    localparam [31:0] STEP_F4 = 32'd30718596;
    localparam [31:0] STEP_G4 = 32'd34480685;
    localparam [31:0] STEP_A4 = 32'd38702809;
    localparam [31:0] STEP_B4 = 32'd43442144;
    localparam [31:0] STEP_C5 = 32'd46025557;

    // Eight parallel phase generators retain per-note state. The two DSP
    // multipliers below visit one note per system clock after each PCM tick.
    reg [31:0] phase [0:7];
    reg signed [39:0] accum_i [0:7];
    reg signed [39:0] accum_q [0:7];
    reg signed [15:0] sin_reg [0:7];
    reg signed [15:0] cos_reg [0:7];
    reg signed [15:0] sample_reg;
    reg [9:0] sample_count;
    reg busy;
    reg [2:0] issue_index;
    reg product_valid;
    reg [2:0] product_index_q;
    reg signed [31:0] product_i_q;
    reg signed [31:0] product_q_q;
    integer k;

    function [31:0] note_step;
        input [2:0] note;
        begin
            case (note)
                3'd0: note_step = STEP_C4;
                3'd1: note_step = STEP_D4;
                3'd2: note_step = STEP_E4;
                3'd3: note_step = STEP_F4;
                3'd4: note_step = STEP_G4;
                3'd5: note_step = STEP_A4;
                3'd6: note_step = STEP_B4;
                default: note_step = STEP_C5;
            endcase
        end
    endfunction
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

    function [7:0] level_from_iq;
        input signed [39:0] ivalue;
        input signed [39:0] qvalue;
        reg signed [40:0] i_abs;
        reg signed [40:0] q_abs;
        reg signed [41:0] magnitude;
        reg signed [41:0] scaled;
        begin
            if (ivalue < 0) i_abs = -ivalue;
            else i_abs = ivalue;
            if (qvalue < 0) q_abs = -qvalue;
            else q_abs = qvalue;
            magnitude = i_abs + q_abs;
            // A full-scale detector sees roughly 4e10 per 1024-sample
            // window; shift by 28 to map the measured energy into 0..255.
            scaled = magnitude >>> 28;
            if (scaled > 42'sd255) level_from_iq = 8'hff;
            else if (scaled < 0) level_from_iq = 8'h00;
            else level_from_iq = scaled[7:0];
        end
    endfunction

    wire signed [31:0] product_i = sample_reg * cos_reg[issue_index];
    wire signed [31:0] product_q = sample_reg * sin_reg[issue_index];
    wire signed [39:0] sum_i = accum_i[product_index_q] + product_i_q;
    wire signed [39:0] sum_q = accum_q[product_index_q] + product_q_q;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sample_reg <= 16'sd0;
            sample_count <= 10'd0;
            spectrum_level <= 64'd0;
            frame_tick <= 1'b0;
            frame_toggle <= 1'b0;
            busy <= 1'b0;
            issue_index <= 3'd0;
            product_valid <= 1'b0;
            product_index_q <= 3'd0;
            product_i_q <= 32'sd0;
            product_q_q <= 32'sd0;
            for (k = 0; k < 8; k = k + 1) begin
                phase[k] <= 32'd0;
                accum_i[k] <= 40'sd0;
                accum_q[k] <= 40'sd0;
                sin_reg[k] <= 16'sd0;
                cos_reg[k] <= 16'sd0;
            end
        end else begin
            frame_tick <= 1'b0;
            product_valid <= 1'b0;

            // Stage A: latch one PCM sample and all eight oscillator
            // coefficients. These values remain stable during the scan.
            if (sample_tick) begin
                sample_reg <= audio_sample;
                issue_index <= 3'd0;
                busy <= 1'b1;
                for (k = 0; k < 8; k = k + 1) begin
                    sin_reg[k] <= sine_value(phase[k][31:27]);
                    cos_reg[k] <= sine_value(phase[k][31:27] + 5'd8);
                    phase[k] <= phase[k] + note_step(k[2:0]);
                end
            end

            // Stage B: one I/Q multiplier pair handles the eight notes in
            // successive system clocks. Real audio ticks are 1024 clocks apart.
            if (busy) begin
                product_i_q <= product_i;
                product_q_q <= product_q;
                product_index_q <= issue_index;
                product_valid <= 1'b1;
                if (issue_index == 3'd7)
                    busy <= 1'b0;
                else
                    issue_index <= issue_index + 1'b1;
            end

            // Stage C: accumulate the registered product. Publish after the
            // eighth note of the 1024th audio sample has been accumulated.
            if (product_valid) begin
                accum_i[product_index_q] <= sum_i;
                accum_q[product_index_q] <= sum_q;
                if (product_index_q == 3'd7) begin
                    if (sample_count == 10'h3ff) begin
                        for (k = 0; k < 7; k = k + 1)
                            spectrum_level[k*8 +: 8] <= level_from_iq(accum_i[k], accum_q[k]);
                        spectrum_level[63:56] <= level_from_iq(sum_i, sum_q);
                        for (k = 0; k < 8; k = k + 1) begin
                            accum_i[k] <= 40'sd0;
                            accum_q[k] <= 40'sd0;
                        end
                        sample_count <= 10'd0;
                        frame_tick <= 1'b1;
                        frame_toggle <= ~frame_toggle;
                    end else begin
                        sample_count <= sample_count + 1'b1;
                    end
                end
            end
        end
    end
endmodule
