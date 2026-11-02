`timescale 1ns/1ps

// Strongest measured non-DC DFT bin, converted to its approximate bin-centre
// frequency.  A result changes only after an entire 256-sample DFT frame.
// The 48.828125-kHz audio rate / 24 / 256 gives 7.9473 Hz per bin.
module spectrum_peak_metric (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        write_en,
    input  wire [7:0]  write_addr,
    input  wire [7:0]  write_level,
    input  wire        frame_tick,
    output reg  [11:0] peak_bcd,
    output reg         peak_valid,
    output reg         frame_toggle
);
    localparam [2:0] ST_IDLE=0, ST_MULT=1, ST_FREQ=2,
                     ST_HUNDREDS=3, ST_TENS=4, ST_PUBLISH=5;
    reg [2:0] state;
    reg [7:0] max_level, max_bin, pending_bin;
    reg pending_valid;
    reg [15:0] correction, base_hz;
    reg [11:0] remaining_hz;
    reg [3:0] hundreds, tens;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= ST_IDLE;
            max_level <= 0; max_bin <= 0;
            pending_bin <= 0; pending_valid <= 0;
            correction <= 0; base_hz <= 0; remaining_hz <= 0;
            hundreds <= 0; tens <= 0;
            peak_bcd <= 0; peak_valid <= 0; frame_toggle <= 0;
        end else begin
            if (write_en && (write_addr != 0) && (write_level > max_level)) begin
                max_level <= write_level;
                max_bin <= write_addr;
            end
            if (frame_tick) begin
                // The DFT publishes bin 125 and frame_tick in the same
                // cycle. Include that write before closing the frame.
                if (write_en && (write_addr != 0) && (write_level > max_level)) begin
                    pending_bin <= write_addr;
                    pending_valid <= (write_level > 8'd4);
                end else begin
                    pending_bin <= max_bin;
                    pending_valid <= (max_level > 8'd4);
                end
                max_level <= 0;
                max_bin <= 0;
                state <= ST_MULT;
            end else begin
                case (state)
                    ST_MULT: begin
                        // 8*n - round(27*n/512) approximates 7.9473*n
                        // within one hertz for all displayed bins 1..125.
                        base_hz <= {5'd0,pending_bin,3'd0};
                        correction <= ({8'd0,pending_bin} << 4) +
                                      ({8'd0,pending_bin} << 3) +
                                      ({8'd0,pending_bin} << 1) +
                                      pending_bin + 16'd256;
                        state <= ST_FREQ;
                    end
                    ST_FREQ: begin
                        remaining_hz <= base_hz - (correction >> 9);
                        hundreds <= 0; tens <= 0;
                        state <= ST_HUNDREDS;
                    end
                    ST_HUNDREDS: begin
                        if (remaining_hz >= 12'd100) begin
                            remaining_hz <= remaining_hz - 12'd100;
                            hundreds <= hundreds + 1'b1;
                        end else state <= ST_TENS;
                    end
                    ST_TENS: begin
                        if (remaining_hz >= 12'd10) begin
                            remaining_hz <= remaining_hz - 12'd10;
                            tens <= tens + 1'b1;
                        end else state <= ST_PUBLISH;
                    end
                    ST_PUBLISH: begin
                        peak_bcd <= {hundreds,tens,remaining_hz[3:0]};
                        peak_valid <= pending_valid;
                        frame_toggle <= ~frame_toggle;
                        state <= ST_IDLE;
                    end
                    default: state <= ST_IDLE;
                endcase
            end
        end
    end
endmodule
