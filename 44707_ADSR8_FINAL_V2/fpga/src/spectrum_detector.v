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

    reg [31:0] phase0, phase1, phase2, phase3;
    reg [31:0] phase4, phase5, phase6, phase7;
    reg signed [39:0] i0, q0, i1, q1, i2, q2, i3, q3;
    reg signed [39:0] i4, q4, i5, q5, i6, q6, i7, q7;
    reg [9:0] sample_count;
    reg signed [15:0] sample_reg;
    reg signed [15:0] sin0_reg, cos0_reg, sin1_reg, cos1_reg;
    reg signed [15:0] sin2_reg, cos2_reg, sin3_reg, cos3_reg;
    reg signed [15:0] sin4_reg, cos4_reg, sin5_reg, cos5_reg;
    reg signed [15:0] sin6_reg, cos6_reg, sin7_reg, cos7_reg;
    reg signed [31:0] p0i_reg, p0q_reg, p1i_reg, p1q_reg;
    reg signed [31:0] p2i_reg, p2q_reg, p3i_reg, p3q_reg;
    reg signed [31:0] p4i_reg, p4q_reg, p5i_reg, p5q_reg;
    reg signed [31:0] p6i_reg, p6q_reg, p7i_reg, p7q_reg;
    reg product_start;
    reg product_pending;

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

    wire signed [15:0] sin0 = sine_value(phase0[31:27]);
    wire signed [15:0] cos0 = sine_value(phase0[31:27] + 5'd8);
    wire signed [15:0] sin1 = sine_value(phase1[31:27]);
    wire signed [15:0] cos1 = sine_value(phase1[31:27] + 5'd8);
    wire signed [15:0] sin2 = sine_value(phase2[31:27]);
    wire signed [15:0] cos2 = sine_value(phase2[31:27] + 5'd8);
    wire signed [15:0] sin3 = sine_value(phase3[31:27]);
    wire signed [15:0] cos3 = sine_value(phase3[31:27] + 5'd8);
    wire signed [15:0] sin4 = sine_value(phase4[31:27]);
    wire signed [15:0] cos4 = sine_value(phase4[31:27] + 5'd8);
    wire signed [15:0] sin5 = sine_value(phase5[31:27]);
    wire signed [15:0] cos5 = sine_value(phase5[31:27] + 5'd8);
    wire signed [15:0] sin6 = sine_value(phase6[31:27]);
    wire signed [15:0] cos6 = sine_value(phase6[31:27] + 5'd8);
    wire signed [15:0] sin7 = sine_value(phase7[31:27]);
    wire signed [15:0] cos7 = sine_value(phase7[31:27] + 5'd8);

    // The phase/LUT values and sample are registered before entering the
    // eight parallel multipliers. This removes the phase->LUT->multiplier
    // path from the 50 MHz timing endpoint.
    wire signed [31:0] p0i = sample_reg * cos0_reg;
    wire signed [31:0] p0q = sample_reg * sin0_reg;
    wire signed [31:0] p1i = sample_reg * cos1_reg;
    wire signed [31:0] p1q = sample_reg * sin1_reg;
    wire signed [31:0] p2i = sample_reg * cos2_reg;
    wire signed [31:0] p2q = sample_reg * sin2_reg;
    wire signed [31:0] p3i = sample_reg * cos3_reg;
    wire signed [31:0] p3q = sample_reg * sin3_reg;
    wire signed [31:0] p4i = sample_reg * cos4_reg;
    wire signed [31:0] p4q = sample_reg * sin4_reg;
    wire signed [31:0] p5i = sample_reg * cos5_reg;
    wire signed [31:0] p5q = sample_reg * sin5_reg;
    wire signed [31:0] p6i = sample_reg * cos6_reg;
    wire signed [31:0] p6q = sample_reg * sin6_reg;
    wire signed [31:0] p7i = sample_reg * cos7_reg;
    wire signed [31:0] p7q = sample_reg * sin7_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase0 <= 0; phase1 <= 0; phase2 <= 0; phase3 <= 0;
            phase4 <= 0; phase5 <= 0; phase6 <= 0; phase7 <= 0;
            i0 <= 0; q0 <= 0; i1 <= 0; q1 <= 0;
            i2 <= 0; q2 <= 0; i3 <= 0; q3 <= 0;
            i4 <= 0; q4 <= 0; i5 <= 0; q5 <= 0;
            i6 <= 0; q6 <= 0; i7 <= 0; q7 <= 0;
            sample_count <= 0;
            spectrum_level <= 64'd0;
            frame_tick <= 1'b0;
            frame_toggle <= 1'b0;
            p0i_reg <= 0; p0q_reg <= 0; p1i_reg <= 0; p1q_reg <= 0;
            p2i_reg <= 0; p2q_reg <= 0; p3i_reg <= 0; p3q_reg <= 0;
            p4i_reg <= 0; p4q_reg <= 0; p5i_reg <= 0; p5q_reg <= 0;
            p6i_reg <= 0; p6q_reg <= 0; p7i_reg <= 0; p7q_reg <= 0;
            sample_reg <= 0;
            sin0_reg <= 0; cos0_reg <= 0; sin1_reg <= 0; cos1_reg <= 0;
            sin2_reg <= 0; cos2_reg <= 0; sin3_reg <= 0; cos3_reg <= 0;
            sin4_reg <= 0; cos4_reg <= 0; sin5_reg <= 0; cos5_reg <= 0;
            sin6_reg <= 0; cos6_reg <= 0; sin7_reg <= 0; cos7_reg <= 0;
            product_start <= 1'b0;
            product_pending <= 1'b0;
        end else begin
            frame_tick <= 1'b0;
            // The three stages are valid pipelines, so a new sample may be
            // captured while the previous sample is being multiplied and
            // the sample before that is being accumulated.
            product_start   <= sample_tick;
            product_pending <= product_start;
            if (sample_tick) begin
                // First register the actual sample and the eight LUT
                // coefficients. The multiplier stage runs one clock later.
                sample_reg <= audio_sample;
                sin0_reg <= sin0; cos0_reg <= cos0; sin1_reg <= sin1; cos1_reg <= cos1;
                sin2_reg <= sin2; cos2_reg <= cos2; sin3_reg <= sin3; cos3_reg <= cos3;
                sin4_reg <= sin4; cos4_reg <= cos4; sin5_reg <= sin5; cos5_reg <= cos5;
                sin6_reg <= sin6; cos6_reg <= cos6; sin7_reg <= sin7; cos7_reg <= cos7;
                product_start <= 1'b1;
                phase0 <= phase0 + STEP_C4; phase1 <= phase1 + STEP_D4;
                phase2 <= phase2 + STEP_E4; phase3 <= phase3 + STEP_F4;
                phase4 <= phase4 + STEP_G4; phase5 <= phase5 + STEP_A4;
                phase6 <= phase6 + STEP_B4; phase7 <= phase7 + STEP_C5;
            end
            if (product_start) begin
                // Register multiplier outputs before the accumulator add.
                p0i_reg <= p0i; p0q_reg <= p0q; p1i_reg <= p1i; p1q_reg <= p1q;
                p2i_reg <= p2i; p2q_reg <= p2q; p3i_reg <= p3i; p3q_reg <= p3q;
                p4i_reg <= p4i; p4q_reg <= p4q; p5i_reg <= p5i; p5q_reg <= p5q;
                p6i_reg <= p6i; p6q_reg <= p6q; p7i_reg <= p7i; p7q_reg <= p7q;
            end
            if (product_pending) begin
                product_pending <= 1'b0;
                if (sample_count == 10'h3ff) begin
                    spectrum_level[7:0]   <= level_from_iq(i0 + p0i_reg, q0 + p0q_reg);
                    spectrum_level[15:8]  <= level_from_iq(i1 + p1i_reg, q1 + p1q_reg);
                    spectrum_level[23:16] <= level_from_iq(i2 + p2i_reg, q2 + p2q_reg);
                    spectrum_level[31:24] <= level_from_iq(i3 + p3i_reg, q3 + p3q_reg);
                    spectrum_level[39:32] <= level_from_iq(i4 + p4i_reg, q4 + p4q_reg);
                    spectrum_level[47:40] <= level_from_iq(i5 + p5i_reg, q5 + p5q_reg);
                    spectrum_level[55:48] <= level_from_iq(i6 + p6i_reg, q6 + p6q_reg);
                    spectrum_level[63:56] <= level_from_iq(i7 + p7i_reg, q7 + p7q_reg);
                    i0 <= 0; q0 <= 0; i1 <= 0; q1 <= 0;
                    i2 <= 0; q2 <= 0; i3 <= 0; q3 <= 0;
                    i4 <= 0; q4 <= 0; i5 <= 0; q5 <= 0;
                    i6 <= 0; q6 <= 0; i7 <= 0; q7 <= 0;
                    sample_count <= 0;
                    frame_tick <= 1'b1;
                    frame_toggle <= ~frame_toggle;
                end else begin
                    i0 <= i0 + p0i_reg; q0 <= q0 + p0q_reg;
                    i1 <= i1 + p1i_reg; q1 <= q1 + p1q_reg;
                    i2 <= i2 + p2i_reg; q2 <= q2 + p2q_reg;
                    i3 <= i3 + p3i_reg; q3 <= q3 + p3q_reg;
                    i4 <= i4 + p4i_reg; q4 <= q4 + p4q_reg;
                    i5 <= i5 + p5i_reg; q5 <= q5 + p5q_reg;
                    i6 <= i6 + p6i_reg; q6 <= q6 + p6q_reg;
                    i7 <= i7 + p7i_reg; q7 <= q7 + p7q_reg;
                    sample_count <= sample_count + 1'b1;
                end
            end
        end
    end
endmodule
