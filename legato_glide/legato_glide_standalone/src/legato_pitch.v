`timescale 1ns/1ps

// Last-pressed held key wins. A new overlapping press slides the one voice.
module legato_pitch #(
    parameter integer SLIDE_SAMPLES = 14648
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       sample_tick,
    input  wire [7:0] key_state,
    output reg        active,
    output reg [31:0] step
);
    localparam integer COUNT_W = (SLIDE_SAMPLES <= 1) ? 1 : $clog2(SLIDE_SAMPLES + 1);
    // Rounded reciprocal is constant at elaboration, not a runtime divider.
    localparam [63:0] RECIP_Q32 =
        ((64'd4294967296 + SLIDE_SAMPLES / 2) / SLIDE_SAMPLES);

    function [31:0] note_step;
        input [2:0] key_index;
        begin
            case (key_index)
                3'd0: note_step = 32'd23013218; // C4
                3'd1: note_step = 32'd25830607; // D4
                3'd2: note_step = 32'd28994561; // E4
                3'd3: note_step = 32'd30718596; // F4
                3'd4: note_step = 32'd34480685; // G4
                3'd5: note_step = 32'd38702809; // A4
                3'd6: note_step = 32'd43442144; // B4
                3'd7: note_step = 32'd46025557; // C5
                default: note_step = 32'd0;
            endcase
        end
    endfunction

    reg [7:0] previous_keys;
    reg [31:0] sequence;
    reg [31:0] press_age [0:7];
    reg [2:0] current_key;
    wire [7:0] new_presses = key_state & ~previous_keys;
    wire old_remains = |(key_state & previous_keys);
    integer i, j;

    // New touches share one age; a higher key number wins a same-cycle tie.
    reg [2:0] newest_key;
    always @* begin
        newest_key = 3'd0;
        for (i = 0; i < 8; i = i + 1)
            if (new_presses[i]) begin
                newest_key = i[2:0];
            end
    end

    // Balanced three-level tournament finds the newest still-held key.
    wire [2:0] win1_key [0:3];
    wire [31:0] win1_age [0:3];
    wire win1_valid [0:3];
    wire [2:0] win2_key [0:1];
    wire [31:0] win2_age [0:1];
    wire win2_valid [0:1];
    genvar p;
    generate
        for (p = 0; p < 4; p = p + 1) begin: first_pair
            wire choose_high = !key_state[2*p] ||
                (key_state[2*p+1] && press_age[2*p+1] >= press_age[2*p]);
            assign win1_key[p] = choose_high ? (2*p+1) : (2*p);
            assign win1_age[p] = choose_high ? press_age[2*p+1] : press_age[2*p];
            assign win1_valid[p] = key_state[2*p] | key_state[2*p+1];
        end
        for (p = 0; p < 2; p = p + 1) begin: second_pair
            wire choose_high = !win1_valid[2*p] ||
                (win1_valid[2*p+1] && win1_age[2*p+1] >= win1_age[2*p]);
            assign win2_key[p] = choose_high ? win1_key[2*p+1] : win1_key[2*p];
            assign win2_age[p] = choose_high ? win1_age[2*p+1] : win1_age[2*p];
            assign win2_valid[p] = win1_valid[2*p] | win1_valid[2*p+1];
        end
    endgenerate
    wire choose_final_high = !win2_valid[0] ||
        (win2_valid[1] && win2_age[1] >= win2_age[0]);
    wire [2:0] fallback_key = choose_final_high ? win2_key[1] : win2_key[0];
    wire [31:0] new_step = note_step(newest_key);
    wire [31:0] fallback_step = note_step(fallback_key);
    wire [31:0] transition_delta = (new_step >= step) ?
        new_step - step : step - new_step;
    reg [31:0] delta_latched;
    reg slope_pending;
    wire [63:0] prepared_slope_q32 = delta_latched * RECIP_Q32;

    reg [31:0] target_step;
    reg [31:0] slide_start;
    reg [63:0] slope_q32;
    reg [63:0] progress_q32;
    reg [COUNT_W-1:0] ticks_left;
    reg slide_up;
    wire [63:0] next_progress = progress_q32 + slope_q32;
    wire [31:0] moved_step = next_progress[63:32];
    wire [31:0] up_step = slide_start + moved_step;
    wire [31:0] down_step = slide_start - moved_step;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            previous_keys <= 8'h00;
            sequence <= 32'd0;
            current_key <= 3'd0;
            for (j = 0; j < 8; j = j + 1)
                press_age[j] <= 32'd0;
            active <= 1'b0;
            step <= 32'd0;
            target_step <= 32'd0;
            slide_start <= 32'd0;
            delta_latched <= 32'd0;
            slope_pending <= 1'b0;
            slope_q32 <= 64'd0;
            progress_q32 <= 64'd0;
            ticks_left <= {COUNT_W{1'b0}};
            slide_up <= 1'b1;
        end else if (key_state != previous_keys) begin
            previous_keys <= key_state;
            for (j = 0; j < 8; j = j + 1) begin
                if (new_presses[j])
                    press_age[j] <= sequence + 32'd1;
                else if (!key_state[j])
                    press_age[j] <= 32'd0;
            end
            if (new_presses != 8'h00)
                sequence <= sequence + 32'd1;

            if (key_state == 8'h00) begin
                active <= 1'b0;
                step <= 32'd0;
                target_step <= 32'd0;
                ticks_left <= {COUNT_W{1'b0}};
                progress_q32 <= 64'd0;
                slope_pending <= 1'b0;
                sequence <= 32'd0;
            end else if (new_presses != 8'h00) begin
                active <= 1'b1;
                current_key <= newest_key;
                target_step <= new_step;
                if (old_remains && step != new_step) begin
                    slide_up <= new_step > step;
                    slide_start <= step;
                    delta_latched <= transition_delta;
                    slope_pending <= 1'b1;
                    progress_q32 <= 64'd0;
                    ticks_left <= SLIDE_SAMPLES[COUNT_W-1:0];
                end else begin
                    step <= new_step;
                    ticks_left <= {COUNT_W{1'b0}};
                    progress_q32 <= 64'd0;
                    slope_pending <= 1'b0;
                end
            end else if (!key_state[current_key]) begin
                // A release never glides back: resume the newest held key.
                active <= 1'b1;
                current_key <= fallback_key;
                step <= fallback_step;
                target_step <= fallback_step;
                ticks_left <= {COUNT_W{1'b0}};
                progress_q32 <= 64'd0;
                slope_pending <= 1'b0;
            end
        end else if (slope_pending) begin
            // One sys-clock stage separates key selection from the
            // constant multiply; 1024 sys clocks separate audio samples.
            slope_q32 <= prepared_slope_q32;
            slope_pending <= 1'b0;
        end else if (sample_tick && ticks_left != {COUNT_W{1'b0}}) begin
            ticks_left <= ticks_left - 1'b1;
            progress_q32 <= next_progress;
            if (ticks_left == {{(COUNT_W-1){1'b0}}, 1'b1}) begin
                step <= target_step;
            end else begin
                if (slide_up)
                    step <= (up_step > target_step) ? target_step : up_step;
                else
                    step <= (down_step < target_step) ? target_step : down_step;
            end
        end
    end
endmodule
