`timescale 1ns/1ps

// HTML-compatible continuous spectrum source.
//
// The monitor on the PC keeps the high byte of every 24th audio sample and
// calculates a 256-point spectrum.  This module keeps the same observation
// rate in hardware.  Two sample banks allow one 256-sample frame to be
// analysed while the other bank continues to capture the next frame.
//
// A time-multiplexed DFT evaluates bins 0..125 (0..about 1000 Hz at the
// decimated rate).  The result is a small dual-clock-friendly RAM: writes
// happen in sys_clk and read_level is an asynchronous pixel-side read port.
// The RAM is only changed after a complete bin is evaluated, and frame_toggle
// changes after the last bin, so the HDMI side never needs a wide CDC bus.
module spectrum_dft #(
    parameter integer SAMPLE_DECIMATION = 24,
    parameter integer BIN_COUNT          = 126
) (
    input  wire              clk,
    input  wire              rst_n,
    input  wire              sample_tick,
    input  wire signed [15:0] audio_sample,
    input  wire [7:0]        read_addr,
    output reg  [7:0]        read_level,
    output reg               frame_tick,
    output reg               frame_toggle,
    output reg               write_en,
    output reg  [7:0]        write_addr,
    output reg  [7:0]        write_level
);
    localparam [2:0] ST_IDLE  = 3'd0;
    localparam [2:0] ST_ACCUM = 3'd1;

    reg signed [7:0] sample_bank0 [0:255];
    reg signed [7:0] sample_bank1 [0:255];
    reg        [7:0] spectrum_mem [0:125];

    reg [7:0] decim_count;
    reg [7:0] write_index;
    reg       write_bank;
    reg       proc_bank;
    reg       busy;
    reg [2:0] state;
    reg [7:0] bin_index;
    reg [7:0] sample_index;
    reg [7:0] phase_counter;
    reg signed [39:0] accum_i;
    reg signed [39:0] accum_q;
    reg signed [7:0] sample_pipe;
    reg signed [15:0] coeff_cos_pipe;
    reg signed [15:0] coeff_sin_pipe;
    reg [7:0] sample_index_pipe;
    reg stage_a_valid;
    reg signed [31:0] product_i_q;
    reg signed [31:0] product_q_q;
    reg [7:0] product_index_q;
    reg stage_b_valid;
    reg input_done;

    integer reset_index;

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

    function [7:0] magnitude_to_level;
        input [41:0] magnitude;
        reg [41:0] scaled;
        begin
            // The input is the signed high byte, and the reference sine is
            // Q15-ish with a peak of 12000.  This fixed scale puts a full
            // scale a real single DDS voice (~6 high-byte counts) to a
            // visible peak without changing the frequency-bin calculation.
            scaled = magnitude >> 16;
            if (scaled > 42'd255)
                magnitude_to_level = 8'hff;
            else
                magnitude_to_level = scaled[7:0];
        end
    endfunction

    function [31:0] abs40;
        input signed [39:0] value;
        reg signed [40:0] extended;
        begin
            if (value < 0)
                extended = -value;
            else
                extended = value;
            if (extended[40])
                abs40 = 32'hffff_ffff;
            else if (|extended[39:32])
                abs40 = 32'hffff_ffff;
            else
                abs40 = extended[31:0];
        end
    endfunction

    always @* begin
        if (read_addr < BIN_COUNT)
            read_level = spectrum_mem[read_addr];
        else
            read_level = 8'd0;
    end

    reg signed [7:0] current_sample;
    reg [7:0] phase_index;
    reg signed [15:0] coeff_cos;
    reg signed [15:0] coeff_sin;
    reg signed [31:0] product_i_pipe;
    reg signed [31:0] product_q_pipe;
    reg signed [39:0] next_i;
    reg signed [39:0] next_q;
    reg [31:0] abs_i;
    reg [31:0] abs_q;
    reg [41:0] magnitude_now;
    reg [7:0] level_now;

    always @* begin
        if (proc_bank)
            current_sample = sample_bank1[sample_index];
        else
            current_sample = sample_bank0[sample_index];
        phase_index = phase_counter;
        coeff_sin = sine_value(phase_index[7:3]);
        coeff_cos = sine_value(phase_index[7:3] + 5'd8);
        product_i_pipe = sample_pipe * coeff_cos_pipe;
        product_q_pipe = sample_pipe * coeff_sin_pipe;
        next_i = accum_i + product_i_q;
        next_q = accum_q + product_q_q;
        abs_i = abs40(next_i);
        abs_q = abs40(next_q);
        magnitude_now = abs_i + abs_q;
        level_now = magnitude_to_level(magnitude_now);
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            decim_count <= 8'd0;
            write_index <= 8'd0;
            write_bank <= 1'b0;
            proc_bank <= 1'b0;
            busy <= 1'b0;
            state <= ST_IDLE;
            bin_index <= 8'd0;
            sample_index <= 8'd0;
            phase_counter <= 8'd0;
            accum_i <= 40'sd0;
            accum_q <= 40'sd0;
            sample_pipe <= 8'sd0;
            coeff_cos_pipe <= 16'sd0;
            coeff_sin_pipe <= 16'sd0;
            sample_index_pipe <= 8'd0;
            stage_a_valid <= 1'b0;
            product_i_q <= 32'sd0;
            product_q_q <= 32'sd0;
            product_index_q <= 8'd0;
            stage_b_valid <= 1'b0;
            input_done <= 1'b0;
            frame_tick <= 1'b0;
            frame_toggle <= 1'b0;
            write_en <= 1'b0;
            write_addr <= 8'd0;
            write_level <= 8'd0;
            for (reset_index = 0; reset_index < BIN_COUNT; reset_index = reset_index + 1)
                spectrum_mem[reset_index] <= 8'd0;
        end else begin
            frame_tick <= 1'b0;
            write_en <= 1'b0;

            // Decimate the real audio sample stream exactly like the HTML
            // telemetry path.  The high byte is the signed display sample.
            if (sample_tick) begin
                if (decim_count == SAMPLE_DECIMATION-1) begin
                    decim_count <= 8'd0;
                    if (write_bank)
                        sample_bank1[write_index] <= audio_sample[15:8];
                    else
                        sample_bank0[write_index] <= audio_sample[15:8];
                    if (write_index == 8'hff) begin
                        write_index <= 8'd0;
                        write_bank <= ~write_bank;
                        if (!busy) begin
                            busy <= 1'b1;
                            proc_bank <= write_bank;
                            state <= ST_ACCUM;
                            bin_index <= 8'd0;
                            sample_index <= 8'd0;
                            phase_counter <= 8'd0;
                            accum_i <= 40'sd0;
                            accum_q <= 40'sd0;
                            stage_a_valid <= 1'b0;
                            stage_b_valid <= 1'b0;
                            input_done <= 1'b0;
                        end
                    end else begin
                        write_index <= write_index + 1'b1;
                    end
                end else begin
                    decim_count <= decim_count + 1'b1;
                end
            end

            if (busy && (state == ST_ACCUM)) begin
                // Stage A: RAM read, phase LUT, and sample/coeff registers.
                // The phase is advanced by bin_index, avoiding a bin*sample
                // multiplier on the input side of the pipeline.
                if (!input_done) begin
                    sample_pipe <= current_sample;
                    coeff_cos_pipe <= coeff_cos;
                    coeff_sin_pipe <= coeff_sin;
                    sample_index_pipe <= sample_index;
                    stage_a_valid <= 1'b1;
                    phase_counter <= phase_counter + bin_index;
                    if (sample_index == 8'hff) begin
                        input_done <= 1'b1;
                    end else begin
                        sample_index <= sample_index + 1'b1;
                    end
                end else begin
                    stage_a_valid <= 1'b0;
                end

                // Stage B: registered multiplier output.
                if (stage_a_valid) begin
                    product_i_q <= product_i_pipe;
                    product_q_q <= product_q_pipe;
                    product_index_q <= sample_index_pipe;
                    stage_b_valid <= 1'b1;
                end else begin
                    stage_b_valid <= 1'b0;
                end

                // Stage C: accumulator and bin publication.
                if (stage_b_valid) begin
                    if (product_index_q == 8'hff) begin
                        spectrum_mem[bin_index] <= level_now;
                        write_en <= 1'b1;
                        write_addr <= bin_index;
                        write_level <= level_now;
                        accum_i <= 40'sd0;
                        accum_q <= 40'sd0;
                        sample_index <= 8'd0;
                        phase_counter <= 8'd0;
                        input_done <= 1'b0;
                        if (bin_index == BIN_COUNT-1) begin
                            busy <= 1'b0;
                            state <= ST_IDLE;
                            frame_tick <= 1'b1;
                            frame_toggle <= ~frame_toggle;
                        end else begin
                            bin_index <= bin_index + 1'b1;
                        end
                    end else begin
                        accum_i <= next_i;
                        accum_q <= next_q;
                    end
                end
            end
        end
    end
endmodule
