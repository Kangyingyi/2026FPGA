`timescale 1ns/1ps

// Hardware-side values used by the HDMI monitor UI.
// Frequencies are rounded display values; DDS phase increments remain in
// polyphonic_dds.v and are not changed by this module.
module ui_data (
    input  wire [7:0]  key_state,
    output reg  [3:0]  polyphony_count,
    output wire [7:0]  active_notes,
    output wire [15:0] freq_hz0,
    output wire [15:0] freq_hz1,
    output wire [15:0] freq_hz2,
    output wire [15:0] freq_hz3,
    output wire [15:0] freq_hz4,
    output wire [15:0] freq_hz5,
    output wire [15:0] freq_hz6,
    output wire [15:0] freq_hz7
);

    assign active_notes = key_state;
    assign freq_hz0 = 16'd262;
    assign freq_hz1 = 16'd294;
    assign freq_hz2 = 16'd330;
    assign freq_hz3 = 16'd349;
    assign freq_hz4 = 16'd392;
    assign freq_hz5 = 16'd440;
    assign freq_hz6 = 16'd494;
    assign freq_hz7 = 16'd523;

    always @* begin
        polyphony_count = key_state[0] + key_state[1] + key_state[2] + key_state[3] +
                           key_state[4] + key_state[5] + key_state[6] + key_state[7];
    end
endmodule
