`timescale 1ns/1ps

module top #(
    parameter integer DEBOUNCE_CYCLES = 250000,
    // 50 MHz / 391 = 127877 baud, matching this JDY-31's 128000 UART setting.
    parameter integer UART_CLKS_PER_BIT = 391
) (
    input  wire       sys_clk,
    input  wire       rst_n,
    input  wire [7:0] key_in,
    input  wire       BLE_RX,
    input  wire       OPTICAL_IN,
    output wire       BLE_TX,
    output wire [7:0] led_out,
    output wire       I2S_BCLK,
    output wire       I2S_LRCK,
    output wire       I2S_DIN,
    output wire       PA_EN,
    output wire       tmds_clk_n_0,
    output wire       tmds_clk_p_0,
    output wire [2:0] tmds_d_n_0,
    output wire [2:0] tmds_d_p_0,
    output wire       hpd_en
);
    wire [7:0] key_state, key_pressed;
    wire signed [15:0] audio_sample;
    reg signed [15:0] audio_sample_pipe;
    wire signed [15:0] audio_normal, audio_legato, audio_always;
    wire signed [15:0] audio_vibrato, audio_pluck, audio_delay;
    wire signed [15:0] audio_echo, audio_reverb, audio_chorus;
    wire signed [15:0] audio_legato_env, audio_always_env, audio_vibrato_env;
    wire signed [15:0] audio_pressure;
    wire sample_tick;
    wire [7:0] guide_led_out;
    wire [5:0] score_rd_index;
    wire [2:0] score_rd_pitch;
    wire [15:0] score_rd_duration;
    wire score_valid, guide_active;
    wire [15:0] score_length;
    wire [2:0] target_pitch;
    wire [2:0] timbre_command_sel;
    wire [1:0] octave_command_sel;
    wire [3:0] mode_command_sel;
    wire mode_valid;
    wire octave_valid;
    wire timbre_valid, score_begin, score_event_valid, score_end;
    wire guide_start, guide_stop, record_start_cmd, record_stop_cmd;
    wire [2:0] score_pitch;
    wire [15:0] score_duration;
    wire ack_valid, parser_frame_valid, parser_frame_error;
    wire [7:0] ack_type, ack_code, parser_frame_type;
    wire [15:0] parser_frame_length;
    wire [255:0] parser_frame_payload;
    wire uart_rx_valid, uart_rx_ready, uart_rx_overrun, uart_rx_framing_error;
    wire [7:0] uart_rx_data;
    reg [2:0] timbre_sel;
    reg [1:0] octave_sel;
    reg [3:0] mode_sel;
    reg record_active;

    reg ack_pending;
    reg [7:0] ack_type_latched, ack_code_latched;
    wire ctrl_frame_start;
    wire ctrl_tx_busy, ctrl_tx_valid, ctrl_tx_ready;
    wire [7:0] ctrl_tx_byte;
    wire record_tx_valid, record_tx_ready, record_tx_busy;
    wire [7:0] record_tx_byte;
    wire record_pcm_valid;
    wire signed [7:0] record_pcm_sample;
    wire uart_tx_busy;
    wire uart_tx_ready, uart_tx_valid;
    wire [7:0] uart_tx_byte;

    // Capacitive touch board: idle LOW, touched HIGH.
    key_filter_8 #(.DEBOUNCE_CYCLES(DEBOUNCE_CYCLES), .ACTIVE_LOW(0)) key_filter_inst (
        .clk(sys_clk), .rst_n(rst_n), .key_in(key_in), .key_state(key_state), .key_pressed(key_pressed)
    );

    uart_rx #(.CLKS_PER_BIT(UART_CLKS_PER_BIT)) ble_rx_inst (
        .clk(sys_clk), .rst_n(rst_n), .rx(BLE_RX), .data_ready(uart_rx_ready),
        .data_out(uart_rx_data), .data_valid(uart_rx_valid), .overrun(uart_rx_overrun), .framing_error(uart_rx_framing_error)
    );
    assign uart_rx_ready = 1'b1;
    ble_protocol_rx #(.MAX_PAYLOAD(32)) protocol_rx_inst (
        .clk(sys_clk), .rst_n(rst_n), .byte_valid(uart_rx_valid), .byte_ready(),
        .byte_in(uart_rx_data), .frame_valid(parser_frame_valid), .frame_error(parser_frame_error),
        .frame_type(parser_frame_type), .frame_length(parser_frame_length), .frame_payload(parser_frame_payload)
    );
    ble_command_router command_router_inst (
        .clk(sys_clk), .rst_n(rst_n), .frame_valid(parser_frame_valid), .frame_error(parser_frame_error),
        .frame_type(parser_frame_type), .frame_length(parser_frame_length), .frame_payload(parser_frame_payload),
        .score_valid(score_valid),
        .timbre_valid(timbre_valid), .timbre_sel(timbre_command_sel),
        .octave_valid(octave_valid), .octave_sel(octave_command_sel),
        .mode_valid(mode_valid), .mode_sel(mode_command_sel), .score_begin(score_begin),
        .score_event_valid(score_event_valid), .score_pitch(score_pitch), .score_duration(score_duration),
        .score_end(score_end), .guide_start(guide_start), .guide_stop(guide_stop),
        .record_start(record_start_cmd), .record_stop(record_stop_cmd), .ack_valid(ack_valid),
        .ack_type(ack_type), .ack_code(ack_code)
    );

    score_ram #(.DEPTH(64)) score_ram_inst (
        .clk(sys_clk), .rst_n(rst_n), .score_begin(score_begin), .event_valid(score_event_valid),
        .event_pitch(score_pitch), .event_duration(score_duration), .score_end(score_end),
        .rd_index(score_rd_index), .rd_pitch(score_rd_pitch), .rd_duration(score_rd_duration),
        .score_valid(score_valid), .score_length(score_length)
    );
    guide_controller guide_controller_inst (
        .clk(sys_clk), .rst_n(rst_n), .key_pressed(key_pressed), .score_valid(score_valid),
        .score_length(score_length), .rd_index(score_rd_index), .rd_pitch(score_rd_pitch),
        .score_begin(score_begin), .score_event_valid(score_event_valid), .score_end(score_end),
        .guide_start(guide_start), .guide_stop(guide_stop), .guide_active(guide_active),
        .target_pitch(target_pitch)
    );
    led_guide led_guide_inst(.guide_active(guide_active), .target_pitch(target_pitch), .led_out(guide_led_out));
    // Common-anode LEDs are off when score guidance is inactive.
    assign led_out = guide_active ? guide_led_out : 8'hFF;

    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            timbre_sel <= 0;
            octave_sel <= 2'd1;
            mode_sel <= 0;
            record_active <= 1'b0;
            ack_pending <= 1'b0;
            ack_type_latched <= 0;
            ack_code_latched <= 0;
        end else begin
            if (timbre_valid) timbre_sel <= timbre_command_sel[2:0];
            if (octave_valid) octave_sel <= octave_command_sel;
            if (mode_valid) mode_sel <= mode_command_sel;
            if (record_start_cmd) record_active <= 1'b1;
            if (record_stop_cmd) record_active <= 1'b0;
            if (ack_valid) begin
                ack_pending <= 1'b1;
                ack_type_latched <= ack_type;
                ack_code_latched <= ack_code;
            end else if (ack_pending && !ctrl_tx_busy) ack_pending <= 1'b0;
        end
    end
    assign ctrl_frame_start = ack_pending && !ctrl_tx_busy;

    wire [7:0] normal_keys = (mode_sel == 4'd0 || mode_sel == 4'd4 ||
                              mode_sel == 4'd6 || mode_sel == 4'd7 || mode_sel == 4'd8)
                             ? key_state : 8'd0;
    wire [7:0] legato_keys = (mode_sel == 3'd1) ? key_state : 8'd0;
    wire [7:0] always_keys = (mode_sel == 3'd2) ? key_state : 8'd0;
    wire [7:0] vibrato_keys = (mode_sel == 3'd3) ? key_state : 8'd0;
    wire [7:0] pluck_keys = (mode_sel == 3'd5) ? key_state : 8'd0;
    wire legato_active;
    wire [31:0] legato_step;
    wire pluck_trigger;

    polyphonic_timbre audio_engine (
        .clk(sys_clk), .rst_n(rst_n), .sample_tick(sample_tick), .key_state(normal_keys),
        .timbre_sel(timbre_sel), .octave_sel(octave_sel), .sample(audio_normal)
    );
    legato_pitch legato_controller (
        .clk(sys_clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .key_state(legato_keys), .active(legato_active), .step(legato_step)
    );
    legato_dds legato_engine (
        .clk(sys_clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .active(legato_active), .step((octave_sel == 2'd0) ? (legato_step >> 1) :
                                         (octave_sel == 2'd2) ? (legato_step << 1) : legato_step),
        .sample(audio_legato)
    );
    glide_dds always_glide_engine (
        .clk(sys_clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .key_state(always_keys), .octave_sel(octave_sel), .sample(audio_always)
    );
    vibrato_dds vibrato_engine (
        .clk(sys_clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .key_state(vibrato_keys), .octave_sel(octave_sel), .sample(audio_vibrato)
    );
    effect_adsr legato_envelope (
        .clk(sys_clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .gate(legato_active), .audio_in(audio_legato), .audio_out(audio_legato_env)
    );
    effect_adsr always_envelope (
        .clk(sys_clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .gate(|always_keys), .audio_in(audio_always), .audio_out(audio_always_env)
    );
    effect_adsr vibrato_envelope (
        .clk(sys_clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .gate(|vibrato_keys), .audio_in(audio_vibrato), .audio_out(audio_vibrato_env)
    );
    audio_delay echo_engine (
        .clk(sys_clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .enable(mode_sel == 3'd4), .audio_in(audio_normal), .audio_out(audio_delay)
    );
    // Teammate effects share the normal polyphonic source. Reset unselected
    // engines so tails from an earlier mode do not reappear on re-entry.
    audio_echo echo_fx (
        .clk(sys_clk), .rst_n(rst_n && mode_sel == 4'd6), .sample_tick(sample_tick),
        .audio_in(audio_normal), .audio_out(audio_echo)
    );
    audio_reverb reverb_fx (
        .clk(sys_clk), .rst_n(rst_n && mode_sel == 4'd7), .sample_tick(sample_tick),
        .voice_active(|normal_keys), .audio_in(audio_normal), .audio_out(audio_reverb)
    );
    audio_chorus chorus_fx (
        .clk(sys_clk), .rst_n(rst_n && mode_sel == 4'd8), .sample_tick(sample_tick),
        .audio_in(audio_normal), .audio_out(audio_chorus)
    );
    optical_pluck_trigger optical_trigger (
        .clk(sys_clk), .rst_n(rst_n), .optical_in(OPTICAL_IN),
        .sample_tick(sample_tick), .pluck_trigger(pluck_trigger)
    );
    polyphonic_pluck pluck_engine (
        .clk(sys_clk), .rst_n(rst_n), .sample_tick(sample_tick),
        .key_state(pluck_keys), .octave_sel(octave_sel),
        .pluck_trigger(pluck_trigger && mode_sel == 3'd5),
        .sample(audio_pluck)
    );
    assign audio_sample = (mode_sel == 3'd1) ? audio_legato_env :
                          (mode_sel == 3'd2) ? audio_always_env :
                          (mode_sel == 3'd3) ? audio_vibrato_env :
                          (mode_sel == 3'd4) ? audio_delay :
                          (mode_sel == 3'd5) ? audio_pluck :
                          (mode_sel == 4'd6) ? audio_echo :
                          (mode_sel == 4'd7) ? audio_reverb :
                          (mode_sel == 4'd8) ? audio_chorus : audio_normal;
    // Break the key/effect/mode path before pressure scaling and I2S capture.
    // One 50 MHz cycle is only 20 ns relative to the 48 kHz audio period.
    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) audio_sample_pipe <= 16'sd0;
        else audio_sample_pipe <= audio_sample;
    end
    // Fixed-volume audio; no external sensor is required.
    assign audio_pressure = audio_sample_pipe;
    i2s_tx i2s_tx_inst (
        .clk(sys_clk), .rst_n(rst_n), .sample_l(audio_pressure), .sample_r(audio_pressure),
        .i2s_bclk(I2S_BCLK), .i2s_lrck(I2S_LRCK), .i2s_din(I2S_DIN), .sample_tick(sample_tick)
    );
    hdmi_monitor hdmi_monitor_inst (
        .sys_clk(sys_clk), .rst_n(rst_n), .key_state(key_state),
        .sample_tick(sample_tick), .audio_sample(audio_pressure),
        .tmds_clk_n_0(tmds_clk_n_0), .tmds_clk_p_0(tmds_clk_p_0),
        .tmds_d_n_0(tmds_d_n_0), .tmds_d_p_0(tmds_d_p_0),
        .hpd_en(hpd_en)
    );
    record_sampler recorder_sampler (
        .clk(sys_clk), .rst_n(rst_n), .sample_tick(sample_tick), .record_enable(record_active),
        .audio_sample(audio_pressure), .pcm_valid(record_pcm_valid), .pcm_sample(record_pcm_sample)
    );
    record_packetizer recorder_packetizer (
        .clk(sys_clk), .rst_n(rst_n), .record_start(record_active), .record_stop(record_stop_cmd),
        .pcm_valid(record_pcm_valid), .pcm_sample(record_pcm_sample), .tx_valid(record_tx_valid),
        .tx_ready(record_tx_ready), .tx_byte(record_tx_byte), .busy(record_tx_busy)
    );

    ble_protocol_tx #(.MAX_PAYLOAD(32)) control_tx (
        .clk(sys_clk), .rst_n(rst_n), .frame_start(ctrl_frame_start), .frame_type(8'h7F),
        .frame_length(16'd2), .frame_payload({240'd0, ack_code_latched, ack_type_latched}),
        .busy(ctrl_tx_busy), .byte_valid(ctrl_tx_valid), .byte_ready(ctrl_tx_ready), .byte_out(ctrl_tx_byte)
    );
    tx_arbiter tx_arbiter_inst (
        .clk(sys_clk), .rst_n(rst_n), .ctrl_valid(ctrl_tx_valid), .ctrl_ready(ctrl_tx_ready),
        .ctrl_byte(ctrl_tx_byte), .record_valid(record_tx_valid), .record_ready(record_tx_ready),
        .record_byte(record_tx_byte), .uart_ready(uart_tx_ready), .uart_valid(uart_tx_valid), .uart_byte(uart_tx_byte)
    );
    uart_tx #(.CLKS_PER_BIT(UART_CLKS_PER_BIT)) ble_tx_inst (
        .clk(sys_clk), .rst_n(rst_n), .data_in(uart_tx_byte), .data_valid(uart_tx_valid && uart_tx_ready),
        .tx(BLE_TX), .busy(uart_tx_busy)
    );
    assign uart_tx_ready = !uart_tx_busy;

    // Board amplifier enable is active-low.
    assign PA_EN = 1'b0;
endmodule
