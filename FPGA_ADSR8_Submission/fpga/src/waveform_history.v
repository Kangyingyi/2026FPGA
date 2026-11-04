`timescale 1ns/1ps

// 256-point audio history. Writes occur in the 50 MHz audio domain; reads
// are asynchronous so the video pixel clock can sample a selected point.
module waveform_history #(
    parameter integer DEPTH = 256
) (
    input  wire              audio_clk,
    input  wire              rst_n,
    input  wire              sample_tick,
    input  wire signed [15:0] audio_sample,
    input  wire [7:0]         read_addr,
    input  wire [7:0]         read_base_ptr,
    output wire signed [15:0] read_sample,
    output reg  [7:0]         write_ptr,
    output wire [7:0]         write_ptr_gray
);
    reg signed [15:0] sample_mem [0:DEPTH-1];
    integer i;

    always @(posedge audio_clk or negedge rst_n) begin
        if (!rst_n) begin
            write_ptr <= 8'd0;
            for (i = 0; i < DEPTH; i = i + 1)
                sample_mem[i] <= 16'sd0;
        end else if (sample_tick) begin
            sample_mem[write_ptr] <= audio_sample;
            write_ptr <= write_ptr + 8'd1;
        end
    end

    // write_ptr points to the oldest sample after the buffer has wrapped.
    // Adding the display index gives a chronological, naturally wrapping view.
    wire [7:0] chronological_addr = read_base_ptr + read_addr;
    assign read_sample = sample_mem[chronological_addr];
    assign write_ptr_gray = write_ptr ^ (write_ptr >> 1);
endmodule
