`timescale 1ns/1ps

// Unified UART telemetry for the standalone waveform monitor.
// Frame format: A5 | type | length | payload | checksum.
// Checksum: 5A XOR type XOR length XOR every payload byte.
// type 01 status: key_state, voice_count, raw_key_in.
// type 02 samples: sequence, followed by decimated signed samples.
module uart_telemetry #(
    parameter integer CLKS_PER_BIT         = 434,
    parameter integer STATUS_PERIOD_CYCLES = 500000,
    parameter integer SAMPLE_DECIMATION    = 24,
    parameter integer SAMPLES_PER_FRAME    = 32
) (
    input  wire              clk,
    input  wire              rst_n,
    input  wire [7:0]        raw_key_in,
    input  wire [7:0]        key_state,
    input  wire              sample_tick,
    input  wire signed [15:0] audio_sample,
    output wire              uart_tx
);

    localparam integer PERIOD_W = (STATUS_PERIOD_CYCLES <= 2) ? 1 : $clog2(STATUS_PERIOD_CYCLES);
    localparam integer DECIM_W  = (SAMPLE_DECIMATION <= 2) ? 1 : $clog2(SAMPLE_DECIMATION);
    localparam integer SAMPLE_W = (SAMPLES_PER_FRAME <= 2) ? 1 : $clog2(SAMPLES_PER_FRAME);
    localparam integer POS_W    = (SAMPLES_PER_FRAME <= 2) ? 4 : $clog2(SAMPLES_PER_FRAME + 5);

    reg [PERIOD_W-1:0] period_count;
    reg [DECIM_W-1:0]  sample_decim_count;
    reg [SAMPLE_W-1:0] sample_index;
    reg [7:0] sample_sequence;
    reg [7:0] sample_frame_sequence;
    reg [7:0] sample_xor_accum;
    reg [7:0] sample_frame_checksum;
    reg [7:0] sample_buffer [0:SAMPLES_PER_FRAME-1];
    reg       sample_frame_pending;

    reg       status_pending;
    reg [7:0] status_key_state;
    reg [7:0] status_raw_key_in;
    reg [3:0] status_voice_count;
    reg [7:0] status_checksum;

    reg       frame_active;
    reg       last_byte_in_flight;
    reg [7:0] frame_type;
    reg [7:0] frame_length;
    reg [7:0] frame_checksum;
    reg [POS_W-1:0] frame_pos;
    reg       tx_start;
    reg [7:0] tx_data;
    wire      tx_busy;
    wire [3:0] voice_count;
    wire [7:0] sampled_byte = audio_sample[15:8];

    assign voice_count = {3'd0, key_state[0]} + {3'd0, key_state[1]} +
                          {3'd0, key_state[2]} + {3'd0, key_state[3]} +
                          {3'd0, key_state[4]} + {3'd0, key_state[5]} +
                          {3'd0, key_state[6]} + {3'd0, key_state[7]};

    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) uart_tx_inst (
        .clk      (clk),
        .rst_n    (rst_n),
        .tx_start (tx_start),
        .tx_data  (tx_data),
        .tx       (uart_tx),
        .busy     (tx_busy)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            period_count         <= {PERIOD_W{1'b0}};
            sample_decim_count   <= {DECIM_W{1'b0}};
            sample_index         <= {SAMPLE_W{1'b0}};
            sample_sequence      <= 8'd0;
            sample_frame_sequence<= 8'd0;
            sample_xor_accum     <= 8'd0;
            sample_frame_checksum<= 8'd0;
            sample_frame_pending <= 1'b0;
            status_pending       <= 1'b0;
            status_key_state     <= 8'd0;
            status_raw_key_in    <= 8'd0;
            status_voice_count   <= 4'd0;
            status_checksum      <= 8'd0;
            frame_active         <= 1'b0;
            last_byte_in_flight  <= 1'b0;
            frame_type           <= 8'd0;
            frame_length         <= 8'd0;
            frame_checksum       <= 8'd0;
            frame_pos            <= {POS_W{1'b0}};
            tx_start             <= 1'b0;
            tx_data              <= 8'd0;
        end else begin
            tx_start <= 1'b0;

            if (STATUS_PERIOD_CYCLES <= 1 || period_count == STATUS_PERIOD_CYCLES - 1) begin
                period_count       <= {PERIOD_W{1'b0}};
                status_key_state   <= key_state;
                status_raw_key_in  <= raw_key_in;
                status_voice_count <= voice_count;
                status_checksum    <= 8'h5A ^ 8'h01 ^ 8'd3 ^ key_state ^
                                      {4'd0, voice_count} ^ raw_key_in;
                status_pending     <= 1'b1;
            end else begin
                period_count <= period_count + 1'b1;
            end

            if (sample_tick) begin
                if (SAMPLE_DECIMATION <= 1 || sample_decim_count == SAMPLE_DECIMATION - 1) begin
                    sample_decim_count <= {DECIM_W{1'b0}};
                    sample_buffer[sample_index] <= sampled_byte;
                    if (sample_index == SAMPLES_PER_FRAME - 1) begin
                        sample_frame_sequence <= sample_sequence;
                        sample_sequence       <= sample_sequence + 1'b1;
                        sample_frame_checksum <= 8'h5A ^ 8'h02 ^ (SAMPLES_PER_FRAME + 1) ^
                                                 sample_sequence ^ sample_xor_accum ^ sampled_byte;
                        sample_xor_accum      <= 8'd0;
                        sample_index          <= {SAMPLE_W{1'b0}};
                        sample_frame_pending  <= 1'b1;
                    end else begin
                        sample_xor_accum <= sample_xor_accum ^ sampled_byte;
                        sample_index     <= sample_index + 1'b1;
                    end
                end else begin
                    sample_decim_count <= sample_decim_count + 1'b1;
                end
            end

            if (!frame_active) begin
                if (status_pending) begin
                    frame_active        <= 1'b1;
                    frame_type          <= 8'h01;
                    frame_length        <= 8'd3;
                    frame_checksum      <= status_checksum;
                    frame_pos           <= {POS_W{1'b0}};
                    status_pending      <= 1'b0;
                end else if (sample_frame_pending) begin
                    frame_active        <= 1'b1;
                    frame_type          <= 8'h02;
                    frame_length        <= SAMPLES_PER_FRAME + 1;
                    frame_checksum      <= sample_frame_checksum;
                    frame_pos           <= {POS_W{1'b0}};
                    sample_frame_pending<= 1'b0;
                end
            end else if (last_byte_in_flight) begin
                if (!tx_busy) begin
                    last_byte_in_flight <= 1'b0;
                    frame_active        <= 1'b0;
                end
            end else if (!tx_busy && !tx_start) begin
                case (frame_pos)
                    0: tx_data <= 8'hA5;
                    1: tx_data <= frame_type;
                    2: tx_data <= frame_length;
                    3: begin
                        if (frame_type == 8'h01)
                            tx_data <= status_key_state;
                        else
                            tx_data <= sample_frame_sequence;
                    end
                    4: begin
                        if (frame_type == 8'h01)
                            tx_data <= {4'd0, status_voice_count};
                        else
                            tx_data <= sample_buffer[0];
                    end
                    5: begin
                        if (frame_type == 8'h01)
                            tx_data <= status_raw_key_in;
                        else
                            tx_data <= sample_buffer[1];
                    end
                    default: begin
                        if (frame_pos < frame_length + 3) begin
                            if (frame_type == 8'h02)
                                tx_data <= sample_buffer[frame_pos - 3 - 1];
                            else
                                tx_data <= 8'd0;
                        end else begin
                            tx_data <= frame_checksum;
                        end
                    end
                endcase
                tx_start <= 1'b1;
                if (frame_pos == frame_length + 3) begin
                    last_byte_in_flight <= 1'b1;
                end else begin
                    frame_pos <= frame_pos + 1'b1;
                end
            end
        end
    end

endmodule
