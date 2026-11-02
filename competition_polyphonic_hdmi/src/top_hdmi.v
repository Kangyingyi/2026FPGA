`timescale 1ns/1ps

// Audio synthesizer plus a board-native HDMI monitor dashboard.
module top_hdmi #(
    parameter integer DEBOUNCE_CYCLES         = 250000,
    // TTP226 AHL=1 configuration: OUT1..OUT8 are active high.
    parameter integer ACTIVE_LOW              = 0,
    parameter integer UART_CLKS_PER_BIT       = 434,
    parameter integer TELEMETRY_PERIOD_CYCLES = 500000,
    parameter integer SAMPLE_DECIMATION       = 24,
    parameter integer SAMPLES_PER_FRAME       = 32
) (
    input  wire       sys_clk,
    input  wire       rst_n,
    input  wire [7:0] key_in,
    output wire       I2S_BCLK,
    output wire       I2S_LRCK,
    output wire       I2S_DIN,
    output wire       PA_EN,
    output wire       UART_TX,
    output wire       tmds_clk_n_0,
    output wire       tmds_clk_p_0,
    output wire [2:0] tmds_d_n_0,
    output wire [2:0] tmds_d_p_0,
    output wire       hpd_en
);
    wire signed [15:0] audio_sample;
    wire               sample_tick;
    wire [7:0]         key_state;
    wire [7:0]         key_pressed;
    wire [63:0]        spectrum_level_audio;
    wire               spectrum_frame_toggle_audio;
    wire [7:0]         spectrum_dft_level_pixel;
    wire [7:0]         spectrum_dft_addr;
    wire               spectrum_dft_frame_toggle_audio;
    wire               dft_write_en, dft_frame_tick;
    wire [7:0]         dft_write_addr, dft_write_level;
    wire [11:0]        peak_bcd_audio;
    wire               peak_valid_audio, peak_toggle_audio;

    // BLE control handoff: replace these constant sources with synchronous
    // registers from the Bluetooth command parser. No new board pins needed.
    wire signed [15:0] glide_target_q15 = 16'sd0;
    wire [3:0]         glide_speed = 4'd0;
    wire               vibrato_enable = 1'b0;
    wire [3:0]         vibrato_rate_hz = 4'd0;
    wire [10:0]        vibrato_depth_q15 = 11'd0;

    key_filter_8 #(
        .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES),
        .ACTIVE_LOW      (ACTIVE_LOW)
    ) key_filter_inst (
        .clk         (sys_clk),
        .rst_n       (rst_n),
        .key_in      (key_in),
        .key_state   (key_state),
        .key_pressed (key_pressed)
    );

    polyphonic_dds polyphonic_dds_inst (
        .clk        (sys_clk),
        .rst_n      (rst_n),
        .sample_tick(sample_tick),
        .key_state  (key_state),
        .glide_target_q15(glide_target_q15),
        .glide_speed(glide_speed),
        .vibrato_enable(vibrato_enable),
        .vibrato_rate_hz(vibrato_rate_hz),
        .vibrato_depth_q15(vibrato_depth_q15),
        .sample     (audio_sample)
    );

    spectrum_detector spectrum_detector_inst (
        .clk            (sys_clk),
        .rst_n          (rst_n),
        .sample_tick    (sample_tick),
        .audio_sample   (audio_sample),
        .spectrum_level (spectrum_level_audio),
        .frame_tick     (),
        .frame_toggle   (spectrum_frame_toggle_audio)
    );

    spectrum_dft #(
        .SAMPLE_DECIMATION(SAMPLE_DECIMATION),
        .BIN_COUNT         (126)
    ) spectrum_dft_inst (
        .clk          (sys_clk),
        .rst_n        (rst_n),
        .sample_tick  (sample_tick),
        .audio_sample (audio_sample),
        .read_addr    (spectrum_dft_addr),
        .read_level   (spectrum_dft_level_pixel),
        .frame_tick   (dft_frame_tick),
        .frame_toggle (spectrum_dft_frame_toggle_audio),
        .write_en     (dft_write_en),
        .write_addr   (dft_write_addr),
        .write_level  (dft_write_level)
    );

    spectrum_peak_metric spectrum_peak_metric_inst (
        .clk(sys_clk), .rst_n(rst_n),
        .write_en(dft_write_en), .write_addr(dft_write_addr),
        .write_level(dft_write_level), .frame_tick(dft_frame_tick),
        .peak_bcd(peak_bcd_audio), .peak_valid(peak_valid_audio),
        .frame_toggle(peak_toggle_audio)
    );

    assign PA_EN = 1'b0;

    uart_telemetry #(
        .CLKS_PER_BIT        (UART_CLKS_PER_BIT),
        .STATUS_PERIOD_CYCLES(TELEMETRY_PERIOD_CYCLES),
        .SAMPLE_DECIMATION   (SAMPLE_DECIMATION),
        .SAMPLES_PER_FRAME   (SAMPLES_PER_FRAME)
    ) uart_telemetry_inst (
        .clk         (sys_clk),
        .rst_n       (rst_n),
        .raw_key_in  (key_in),
        .key_state   (key_state),
        .sample_tick (sample_tick),
        .audio_sample(audio_sample),
        .uart_tx     (UART_TX)
    );

    i2s_tx i2s_tx_inst (
        .clk        (sys_clk),
        .rst_n      (rst_n),
        .sample_l   (audio_sample),
        .sample_r   (audio_sample),
        .i2s_bclk   (I2S_BCLK),
        .i2s_lrck   (I2S_LRCK),
        .i2s_din    (I2S_DIN),
        .sample_tick(sample_tick)
    );

    wire serial_clk;
    wire pixel_clk;
    wire tmds_pll_lock;

    TMDS_PLL u_tmds_pll (
        .clkin  (sys_clk),
        .clkout0(serial_clk),
        .clkout1(pixel_clk),
        .lock   (tmds_pll_lock)
    );

    reg [1:0] video_reset_pipe;
    always @(posedge pixel_clk or negedge rst_n) begin
        if (!rst_n)
            video_reset_pipe <= 2'b00;
        else
            video_reset_pipe <= {video_reset_pipe[0], tmds_pll_lock};
    end
    wire video_rst_n = video_reset_pipe[1];

    wire video_hs;
    wire video_vs;
    wire video_de;
    wire [11:0] video_x;
    wire [10:0] video_y;
    wire [7:0] wave_write_ptr_audio;
    wire [7:0] wave_write_ptr_gray_audio;

    video_timing_720p video_timing_inst (
        .clk  (pixel_clk),
        .rst_n(video_rst_n),
        .hs   (video_hs),
        .vs   (video_vs),
        .de   (video_de),
        .x    (video_x),
        .y    (video_y)
    );

    // Synchronize stable key states into the pixel-clock domain.
    reg [7:0] key_video_meta;
    reg [7:0] key_video;
    reg [63:0] spectrum_video;
    reg        spectrum_toggle_meta;
    reg        spectrum_toggle_video;
    reg        spectrum_toggle_seen;
    reg        spectrum_dft_toggle_meta;
    reg        spectrum_dft_toggle_video;
    reg        spectrum_dft_frame_seen;
    reg        spectrum_dft_ready_video;
    reg        peak_toggle_meta, peak_toggle_video, peak_toggle_seen;
    reg [11:0] peak_bcd_video;
    reg        peak_valid_video;
    reg [7:0] wave_ptr_gray_meta;
    reg [7:0] wave_ptr_gray_video;
    reg [7:0] wave_ptr_frame;

    function [7:0] gray_to_binary;
        input [7:0] gray;
        integer n;
        begin
            gray_to_binary[7] = gray[7];
            for (n = 6; n >= 0; n = n - 1)
                gray_to_binary[n] = gray_to_binary[n+1] ^ gray[n];
        end
    endfunction

    always @(posedge pixel_clk or negedge video_rst_n) begin
        if (!video_rst_n) begin
            key_video_meta <= 8'd0;
            key_video      <= 8'd0;
            spectrum_video      <= 64'd0;
            spectrum_toggle_meta <= 1'b0;
            spectrum_toggle_video <= 1'b0;
            spectrum_toggle_seen <= 1'b0;
            spectrum_dft_toggle_meta <= 1'b0;
            spectrum_dft_toggle_video <= 1'b0;
            spectrum_dft_frame_seen <= 1'b0;
            spectrum_dft_ready_video <= 1'b0;
            peak_toggle_meta <= 1'b0;
            peak_toggle_video <= 1'b0;
            peak_toggle_seen <= 1'b0;
            peak_bcd_video <= 12'd0;
            peak_valid_video <= 1'b0;
            wave_ptr_gray_meta <= 8'd0;
            wave_ptr_gray_video <= 8'd0;
            wave_ptr_frame <= 8'd0;
        end else begin
            key_video_meta <= key_state;
            key_video      <= key_video_meta;
            spectrum_toggle_meta <= spectrum_frame_toggle_audio;
            spectrum_toggle_video <= spectrum_toggle_meta;
            if (spectrum_toggle_video != spectrum_toggle_seen) begin
                // The audio-side payload is stable for the synchronizer
                // latency, so capture the complete bus at the event.
                spectrum_video <= spectrum_level_audio;
                spectrum_toggle_seen <= spectrum_toggle_video;
            end
            spectrum_dft_toggle_meta <= spectrum_dft_frame_toggle_audio;
            spectrum_dft_toggle_video <= spectrum_dft_toggle_meta;
            if (spectrum_dft_toggle_video != spectrum_dft_frame_seen) begin
                spectrum_dft_frame_seen <= spectrum_dft_toggle_video;
                spectrum_dft_ready_video <= 1'b1;
            end
            peak_toggle_meta <= peak_toggle_audio;
            peak_toggle_video <= peak_toggle_meta;
            if (peak_toggle_video != peak_toggle_seen) begin
                // The BCD/valid payload remains stable until the next
                // complete DFT frame, long after the event synchronizes.
                peak_bcd_video <= peak_bcd_audio;
                peak_valid_video <= peak_valid_audio;
                peak_toggle_seen <= peak_toggle_video;
            end
            wave_ptr_gray_meta <= wave_write_ptr_gray_audio;
            wave_ptr_gray_video <= wave_ptr_gray_meta;
            // Freeze the waveform base once per video frame.
            if ((video_x == 12'd0) && (video_y == 11'd0))
                wave_ptr_frame <= gray_to_binary(wave_ptr_gray_video);
        end
    end

    wire [3:0] polyphony_count;
    wire [7:0] active_notes;
    wire [15:0] freq_hz0, freq_hz1, freq_hz2, freq_hz3;
    wire [15:0] freq_hz4, freq_hz5, freq_hz6, freq_hz7;
    ui_data ui_data_inst (
        .key_state      (key_video),
        .polyphony_count(polyphony_count),
        .active_notes   (active_notes),
        .freq_hz0       (freq_hz0),
        .freq_hz1       (freq_hz1),
        .freq_hz2       (freq_hz2),
        .freq_hz3       (freq_hz3),
        .freq_hz4       (freq_hz4),
        .freq_hz5       (freq_hz5),
        .freq_hz6       (freq_hz6),
        .freq_hz7       (freq_hz7)
    );

    wire [7:0] wave_addr;
    wire [7:0] spectrum_addr;
    // Each HDMI column selects a DFT bin; both blocks must share this bus.
    assign spectrum_dft_addr = spectrum_addr;
    wire signed [15:0] wave_sample;
    waveform_history waveform_history_inst (
        .audio_clk  (sys_clk),
        .rst_n      (rst_n),
        .sample_tick(sample_tick),
        .audio_sample(audio_sample),
        .read_addr  (wave_addr),
        .read_base_ptr(wave_ptr_frame),
        .read_sample(wave_sample),
        .write_ptr  (wave_write_ptr_audio),
        .write_ptr_gray(wave_write_ptr_gray_audio)
    );

    wire [7:0] rgb_r;
    wire [7:0] rgb_g;
    wire [7:0] rgb_b;
    // Two-stage pixel pipeline.  Stage 1 isolates the timing generator from
    // the dashboard rasterizer; stage 2 isolates the rasterizer from the
    // TMDS encoder.  HS/VS/DE are delayed to keep the RGB and video timing
    // aligned at the DVI input.
    reg [11:0] ui_x_q;
    reg [10:0] ui_y_q;
    reg        ui_de_q;
    reg        video_hs_q1, video_hs_q2, video_hs_q3;
    reg        video_vs_q1, video_vs_q2, video_vs_q3;
    reg        video_de_q1, video_de_q2, video_de_q3;
    reg [7:0]  rgb_r_q;
    reg [7:0]  rgb_g_q;
    reg [7:0]  rgb_b_q;

    always @(posedge pixel_clk or negedge video_rst_n) begin
        if (!video_rst_n) begin
            ui_x_q      <= 12'd0;
            ui_y_q      <= 11'd0;
            ui_de_q     <= 1'b0;
            video_hs_q1 <= 1'b0;
            video_hs_q2 <= 1'b0;
            video_hs_q3 <= 1'b0;
            video_vs_q1 <= 1'b0;
            video_vs_q2 <= 1'b0;
            video_vs_q3 <= 1'b0;
            video_de_q1 <= 1'b0;
            video_de_q2 <= 1'b0;
            video_de_q3 <= 1'b0;
            rgb_r_q     <= 8'd0;
            rgb_g_q     <= 8'd0;
            rgb_b_q     <= 8'd0;
        end else begin
            ui_x_q      <= video_x;
            ui_y_q      <= video_y;
            ui_de_q     <= video_de;
            video_hs_q1 <= video_hs;
            video_hs_q2 <= video_hs_q1;
            video_hs_q3 <= video_hs_q2;
            video_vs_q1 <= video_vs;
            video_vs_q2 <= video_vs_q1;
            video_vs_q3 <= video_vs_q2;
            video_de_q1 <= video_de;
            video_de_q2 <= video_de_q1;
            video_de_q3 <= video_de_q2;
            rgb_r_q     <= rgb_r;
            rgb_g_q     <= rgb_g;
            rgb_b_q     <= rgb_b;
        end
    end

    hdmi_ui hdmi_ui_inst (
        .clk              (pixel_clk),
        .rst_n            (video_rst_n),
        .de              (ui_de_q),
        .x               (ui_x_q),
        .y               (ui_y_q),
        .polyphony_count (polyphony_count),
        .key_state       (key_video),
        .spectrum_level  (spectrum_video),
        .spectrum_dft_level(spectrum_dft_ready_video ? spectrum_dft_level_pixel : 8'd0),
        .peak_bcd        (peak_bcd_video),
        .peak_valid      (peak_valid_video),
        .wave_sample     (wave_sample),
        .wave_addr       (wave_addr),
        .spectrum_addr   (spectrum_addr),
        .rgb_r           (rgb_r),
        .rgb_g           (rgb_g),
        .rgb_b           (rgb_b)
    );

    DVI_TX_Top DVI_TX_Top_inst0 (
        .I_rst_n       (video_rst_n),
        .I_serial_clk  (serial_clk),
        .I_rgb_clk     (pixel_clk),
        .I_rgb_vs      (video_vs_q3),
        .I_rgb_hs      (video_hs_q3),
        .I_rgb_de      (video_de_q3),
        .I_rgb_r       (rgb_r_q),
        .I_rgb_g       (rgb_g_q),
        .I_rgb_b       (rgb_b_q),
        .O_tmds_clk_p  (tmds_clk_p_0),
        .O_tmds_clk_n  (tmds_clk_n_0),
        .O_tmds_data_p (tmds_d_p_0),
        .O_tmds_data_n (tmds_d_n_0)
    );

    assign hpd_en = 1'b1;
endmodule
