`timescale 1ns/1ps

// Low-depth 1280x720 monitor rasterizer. All waveform/spectrum values are
// measured upstream; this block only performs range compares and shifts.
module hdmi_ui (
    input  wire              clk,
    input  wire              rst_n,
    input  wire              de,
    input  wire [11:0]       x,
    input  wire [10:0]       y,
    input  wire [3:0]        polyphony_count,
    input  wire [7:0]        key_state,
    input  wire [63:0]       spectrum_level,
    input  wire [7:0]        spectrum_dft_level,
    input  wire [11:0]       peak_bcd,
    input  wire              peak_valid,
    input  wire signed [15:0] wave_sample,
    output reg  [7:0]        wave_addr,
    output reg  [7:0]        spectrum_addr,
    output reg  [7:0]        rgb_r,
    output reg  [7:0]        rgb_g,
    output reg  [7:0]        rgb_b
);
    localparam [23:0] BG     = 24'h0b1220;
    localparam [23:0] PANEL  = 24'h152337;
    localparam [23:0] PANEL2 = 24'h1b2c43;
    localparam [23:0] GRID   = 24'h29405a;
    localparam [23:0] CYAN   = 24'h35d8c0;
    localparam [23:0] BLUE   = 24'h48a9ff;
    localparam [23:0] ORANGE = 24'hf1b84b;
    localparam [23:0] WHITE  = 24'he8f1fb;

    reg [7:0] font_char;
    reg [2:0] font_row;
    reg [3:0] font_col;
    reg       font_on;
    wire [4:0] font_pixels;

    reg        font_on_q;
    reg [7:0]  font_id_q;
    reg [7:0]  font_id_d;
    reg [2:0]  font_row_q;
    reg [2:0]  font_row_d;
    reg [3:0]  font_col_q;
    reg [3:0]  font_col_d;
    reg        font_on_d;
    reg        de_q;
    reg [11:0] x_q;
    reg [10:0] y_q;
    reg [3:0]  polyphony_count_q;
    reg [11:0] peak_bcd_q;
    reg        peak_valid_q;
    reg [7:0]  key_state_q;
    reg [63:0] spectrum_level_q;
    reg [7:0]  spectrum_dft_level_q;
    reg signed [15:0] wave_sample_q;
    reg signed [8:0] wave_previous_level_q;
    reg signed [8:0] wave_current_level_q;
    reg signed [8:0] wave_delta_q;
    reg [7:0] spectrum_addr_next;

    // Display-only gain and clipping. PCM in the audio and DFT paths is
    // untouched; the interpolator merely joins adjacent measured samples.
    function signed [8:0] display_wave_level;
        input signed [15:0] sample;
        reg signed [15:0] scaled;
        begin
            scaled = sample >>> 5;
            if (scaled > 16'sd74)
                display_wave_level = 9'sd74;
            else if (scaled < -16'sd74)
                display_wave_level = -9'sd74;
            else
                display_wave_level = scaled[8:0];
        end
    endfunction

    function [23:0] spectrum_palette;
        input [7:0] bin;
        begin
            case (bin[6:3])
                4'd0: spectrum_palette = 24'h67e8f9;
                4'd1: spectrum_palette = 24'h38bdf8;
                4'd2: spectrum_palette = 24'h3b82f6;
                4'd3: spectrum_palette = 24'h6366f1;
                4'd4: spectrum_palette = 24'h8b5cf6;
                4'd5: spectrum_palette = 24'hd946ef;
                4'd6: spectrum_palette = 24'hf43f5e;
                4'd7: spectrum_palette = 24'hfb7185;
                4'd8: spectrum_palette = 24'hfb923c;
                4'd9: spectrum_palette = 24'hfbbf24;
                4'd10: spectrum_palette = 24'hfde047;
                4'd11: spectrum_palette = 24'ha3e635;
                4'd12: spectrum_palette = 24'h4ade80;
                4'd13: spectrum_palette = 24'h34d399;
                4'd14: spectrum_palette = 24'h2dd4bf;
                default: spectrum_palette = 24'h22d3ee;
            endcase
        end
    endfunction

    function [23:0] waveform_palette;
        input [7:0] magnitude;
        begin
            if (magnitude < 8'd16)
                waveform_palette = 24'h38bdf8;
            else if (magnitude < 8'd32)
                waveform_palette = 24'h35d8c0;
            else if (magnitude < 8'd48)
                waveform_palette = 24'ha3e635;
            else if (magnitude < 8'd64)
                waveform_palette = 24'hfbbf24;
            else
                waveform_palette = 24'hfb7185;
        end
    endfunction

    wire [7:0] font_map_char;

    font_rom font_rom_inst (
        .char_code(font_map_char), .row(font_row_q), .pixels(font_pixels)
    );

    function [7:0] title_char;
        input [4:0] idx;
        begin
            case(idx)
                0:title_char=8'h46; 1:title_char=8'h50; 2:title_char=8'h47; 3:title_char=8'h41;
                4:title_char=8'h20; 5:title_char=8'h41; 6:title_char=8'h55; 7:title_char=8'h44;
                8:title_char=8'h49; 9:title_char=8'h4f; 10:title_char=8'h20; 11:title_char=8'h4d;
                12:title_char=8'h4f; 13:title_char=8'h4e; 14:title_char=8'h49; 15:title_char=8'h54;
                16:title_char=8'h4f; 17:title_char=8'h52; default:title_char=8'h20;
            endcase
        end
    endfunction

    function [7:0] label_char;
        input [2:0] lid;
        input [3:0] pos;
        begin
            label_char=8'h20;
            case(lid)
                0: case(pos) 0:label_char=8'h50;1:label_char=8'h4f;2:label_char=8'h4c;3:label_char=8'h59; endcase
                1: case(pos) 0:label_char=8'h4b;1:label_char=8'h45;2:label_char=8'h59; endcase
                2: case(pos) 0:label_char=8'h53;1:label_char=8'h41;2:label_char=8'h4d;3:label_char=8'h50;4:label_char=8'h4c;5:label_char=8'h45; endcase
                3: case(pos) 0:label_char=8'h50;1:label_char=8'h45;2:label_char=8'h41;3:label_char=8'h4b; endcase
                4: case(pos) 0:label_char=8'h57;1:label_char=8'h41;2:label_char=8'h56;3:label_char=8'h45;4:label_char=8'h46;5:label_char=8'h4f;6:label_char=8'h52;7:label_char=8'h4d; endcase
                5: case(pos) 0:label_char=8'h46;1:label_char=8'h52;2:label_char=8'h45;3:label_char=8'h51;4:label_char=8'h20;5:label_char=8'h42;6:label_char=8'h41;7:label_char=8'h4e;8:label_char=8'h44; endcase
                default: label_char=8'h20;
            endcase
        end
    endfunction

    function [7:0] note_char;
        input [3:0] idx;
        begin
            case(idx) 0,8:note_char=8'h43;1:note_char=8'h44;2:note_char=8'h45;3:note_char=8'h46;
                4:note_char=8'h47;5:note_char=8'h41;6:note_char=8'h42;default:note_char=8'h20; endcase
        end
    endfunction

    function [7:0] note_octave;
        input [3:0] idx;
        begin if(idx==7) note_octave=8'h35; else note_octave=8'h34; end
    endfunction

    function [7:0] freq_digit;
        input [3:0] idx;
        input [1:0] pos;
        begin
            case(idx)
                0:case(pos)0:freq_digit=8'h32;1:freq_digit=8'h36;default:freq_digit=8'h32;endcase
                1:case(pos)0:freq_digit=8'h32;1:freq_digit=8'h39;default:freq_digit=8'h34;endcase
                2:case(pos)0:freq_digit=8'h33;1:freq_digit=8'h33;default:freq_digit=8'h30;endcase
                3:case(pos)0:freq_digit=8'h33;1:freq_digit=8'h34;default:freq_digit=8'h39;endcase
                4:case(pos)0:freq_digit=8'h33;1:freq_digit=8'h39;default:freq_digit=8'h32;endcase
                5:case(pos)0:freq_digit=8'h34;1:freq_digit=8'h34;default:freq_digit=8'h30;endcase
                6:case(pos)0:freq_digit=8'h34;1:freq_digit=8'h39;default:freq_digit=8'h34;endcase
                default:case(pos)0:freq_digit=8'h35;1:freq_digit=8'h32;default:freq_digit=8'h33;endcase
            endcase
        end
    endfunction

    function [7:0] metric_char;
        input [2:0] pos;
        begin
            case(pos) 0:metric_char=8'h34;1:metric_char=8'h38;2:metric_char=8'h2e;3:metric_char=8'h38;4:metric_char=8'h4b; default:metric_char=8'h20; endcase
        end
    endfunction

    function [7:0] axis_text_char;
        input [3:0] group;
        input [2:0] pos;
        begin
            axis_text_char = 8'h20;
            case (group)
                0: case(pos) 0:axis_text_char=8'h30; 1:axis_text_char=8'h20; 2:axis_text_char=8'h48; 3:axis_text_char=8'h7a; endcase
                1: case(pos) 0:axis_text_char=8'h32; 1:axis_text_char=8'h35; 2:axis_text_char=8'h30; 3:axis_text_char=8'h20; 4:axis_text_char=8'h48; 5:axis_text_char=8'h7a; endcase
                2: case(pos) 0:axis_text_char=8'h35; 1:axis_text_char=8'h30; 2:axis_text_char=8'h30; 3:axis_text_char=8'h20; 4:axis_text_char=8'h48; 5:axis_text_char=8'h7a; endcase
                3: case(pos) 0:axis_text_char=8'h37; 1:axis_text_char=8'h35; 2:axis_text_char=8'h30; 3:axis_text_char=8'h20; 4:axis_text_char=8'h48; 5:axis_text_char=8'h7a; endcase
                4: case(pos) 0:axis_text_char=8'h31; 1:axis_text_char=8'h30; 2:axis_text_char=8'h30; 3:axis_text_char=8'h30; 4:axis_text_char=8'h20; 5:axis_text_char=8'h48; 6:axis_text_char=8'h7a; endcase
                default: axis_text_char=8'h20;
            endcase
        end
    endfunction

    // Compact text token map. Character decoding is deliberately placed
    // after the registered token so the coordinate comparator path stays
    // separate from the font ROM path.
    function [7:0] mapped_char;
        input [7:0] id;
        input [3:0] poly_count;
        input [11:0] bcd;
        input valid;
        begin
            mapped_char = 8'h20;
            if (id < 8'd18)
                mapped_char = title_char(id[4:0]);
            else if ((id[7:4] >= 4'd2) && (id[7:4] <= 4'd7))
                mapped_char = label_char(id[7:4]-4'd2, id[3:0]);
            else if (id[7:4] == 4'd9)
                mapped_char = metric_char(id[2:0]);
            else if (id == 8'h80)
                mapped_char = 8'h30 + poly_count;
            else if ((id >= 8'ha0) && (id <= 8'ha5)) begin
                if (id == 8'ha0) mapped_char = valid ? (8'h30 + bcd[11:8]) : 8'h2d;
                else if (id == 8'ha1) mapped_char = valid ? (8'h30 + bcd[7:4]) : 8'h2d;
                else if (id == 8'ha2) mapped_char = valid ? (8'h30 + bcd[3:0]) : 8'h2d;
                else if (id == 8'ha4) mapped_char = 8'h48;
                else if (id == 8'ha5) mapped_char = 8'h7a;
            end
            else if ((id >= 8'hb0) && (id < 8'hf8))
                mapped_char = axis_text_char((id-8'hb0) >> 3, (id-8'hb0) & 8'h07);
        end
    endfunction

    assign font_map_char = mapped_char(font_id_q, polyphony_count_q, peak_bcd_q, peak_valid_q);

    integer rel_x;
    integer rel_y;
    integer text_card_idx;
    integer pixel_card_idx;
    integer card_left;
    integer bar_idx;
    integer bar_left;
    integer bar_level;
    integer bar_top;
    integer spectrum_level_pixel;
    integer spectrum_y;
    integer spectrum_height;
    integer wave_level;
    integer wave_y;
    integer wave_distance;
    integer wave_magnitude;
    reg [23:0] spectrum_rgb;
    reg [23:0] wave_rgb;

    // Font coordinates use power-of-two character cells, avoiding pixel-rate
    // division and modulo hardware on the critical HDMI path.
    always @* begin
        font_char=8'h20; font_row=0; font_col=0; font_on=1'b0;
        rel_x=0; rel_y=0; text_card_idx=-1;
        if(de) begin
            if((x>=32)&&(x<320)&&(y>=18)&&(y<34)) begin
                rel_x=x-32; rel_y=y-18; font_char=title_char(rel_x[8:4]);
                font_row=rel_y[3:1]; font_col=rel_x[3:1]; font_on=1'b1;
            end else if((x>=48)&&(x<112)&&(y>=92)&&(y<106)) begin
                rel_x=x-48; rel_y=y-92; font_char=label_char(0,rel_x[7:4]); font_row=rel_y[3:1]; font_col=rel_x[3:1]; font_on=1'b1;
            end else if((x>=278)&&(x<342)&&(y>=92)&&(y<106)) begin
                rel_x=x-278; rel_y=y-92; font_char=label_char(1,rel_x[7:4]); font_row=rel_y[3:1]; font_col=rel_x[3:1]; font_on=1'b1;
            end else if((x>=548)&&(x<660)&&(y>=92)&&(y<106)) begin
                rel_x=x-548; rel_y=y-92; font_char=label_char(2,rel_x[7:4]); font_row=rel_y[3:1]; font_col=rel_x[3:1]; font_on=1'b1;
            end else if((x>=818)&&(x<962)&&(y>=92)&&(y<106)) begin
                rel_x=x-818; rel_y=y-92; font_char=label_char(3,rel_x[7:4]); font_row=rel_y[3:1]; font_col=rel_x[3:1]; font_on=1'b1;
            end else if((x>=60)&&(x<188)&&(y>=188)&&(y<202)) begin
                rel_x=x-60; rel_y=y-188; font_char=label_char(4,rel_x[7:4]); font_row=rel_y[3:1]; font_col=rel_x[3:1]; font_on=1'b1;
            end else if((x>=60)&&(x<204)&&(y>=410)&&(y<424)) begin
                rel_x=x-60; rel_y=y-410; font_char=label_char(5,rel_x[7:4]); font_row=rel_y[3:1]; font_col=rel_x[3:1]; font_on=1'b1;
            end else if((x>=62)&&(x<94)&&(y>=116)&&(y<148)) begin
                rel_x=x-62; rel_y=y-116; font_char=8'h30+polyphony_count; font_row=rel_y[4:2]; font_col=rel_x[4:2]; font_on=1'b1;
            end else if((x>=548)&&(x<628)&&(y>=116)&&(y<132)) begin
                rel_x=x-548; rel_y=y-116; font_char=metric_char(rel_x[6:4]); font_row=rel_y[3:1]; font_col=rel_x[3:1]; font_on=1'b1;
            end else if((x>=818)&&(x<882)&&(y>=116)&&(y<132)) begin
                rel_x=x-818; rel_y=y-116;
                case(rel_x[6:4]) 0:font_char=8'h31;1:font_char=8'h30;2:font_char=8'h32;3:font_char=8'h34;default:font_char=8'h20;endcase
                font_row=rel_y[3:1]; font_col=rel_x[3:1]; font_on=1'b1;
            end else begin
                if((x>=42)&&(x<192))text_card_idx=0; else if((x>=194)&&(x<344))text_card_idx=1;
                else if((x>=346)&&(x<496))text_card_idx=2; else if((x>=498)&&(x<648))text_card_idx=3;
                else if((x>=650)&&(x<800))text_card_idx=4; else if((x>=802)&&(x<952))text_card_idx=5;
                else if((x>=954)&&(x<1104))text_card_idx=6; else if((x>=1106)&&(x<1256))text_card_idx=7;
                if((text_card_idx>=0)&&(y>=628)&&(y<646)) begin
                    rel_x=x-(42+text_card_idx*152); rel_y=y-628;
                    if(rel_x<16)font_char=note_char(text_card_idx[3:0]);
                    else if((rel_x>=32)&&(rel_x<48))font_char=note_octave(text_card_idx[3:0]);
                    else if((rel_x>=64)&&(rel_x<112))font_char=freq_digit(text_card_idx[3:0],rel_x[5:4]);
                    font_row=rel_y[3:1]; font_col=rel_x[3:1]; font_on=1'b1;
                end
            end
        end
    end

    // A short first-stage decoder emits only a text token and its glyph
    // coordinates. It separates coordinate compares from the font map/ROM.
    always @* begin
        font_id_d = 8'hff;
        font_row_d = 3'd0;
        font_col_d = 4'd0;
        font_on_d = 1'b0;
        if (de) begin
            if ((x>=32) && (x<320) && (y>=18) && (y<34)) begin
                font_id_d = x[8:4] - 5'd2;
                font_row_d = (y-18) >> 1;
                font_col_d = ((x-32) >> 1) & 4'h7;
                font_on_d = 1'b1;
            end else if ((x>=48) && (x<112) && (y>=92) && (y<106)) begin
                font_id_d = 8'h20 + ((x-48) >> 4);
                font_row_d = (y-92) >> 1;
                font_col_d = ((x-48) >> 1) & 4'h7;
                font_on_d = 1'b1;
            end else if ((x>=278) && (x<342) && (y>=92) && (y<106)) begin
                font_id_d = 8'h30 + ((x-278) >> 4);
                font_row_d = (y-92) >> 1;
                font_col_d = ((x-278) >> 1) & 4'h7;
                font_on_d = 1'b1;
            end else if ((x>=548) && (x<660) && (y>=92) && (y<106)) begin
                font_id_d = 8'h40 + ((x-548) >> 4);
                font_row_d = (y-92) >> 1;
                font_col_d = ((x-548) >> 1) & 4'h7;
                font_on_d = 1'b1;
            end else if ((x>=818) && (x<882) && (y>=92) && (y<106)) begin
                font_id_d = 8'h50 + ((x-818) >> 4);
                font_row_d = (y-92) >> 1;
                font_col_d = ((x-818) >> 1) & 4'h7;
                font_on_d = 1'b1;
            end else if ((x>=62) && (x<94) && (y>=116) && (y<148)) begin
                font_id_d = 8'h80;
                font_row_d = (y-116) >> 2;
                font_col_d = (x-62) >> 2;
                font_on_d = 1'b1;
            end else if ((x>=818) && (x<914) && (y>=116) && (y<132)) begin
                font_id_d = 8'ha0 + ((x-818) >> 4);
                font_row_d = (y-116) >> 1;
                font_col_d = ((x-818) >> 1) & 4'h7;
                font_on_d = 1'b1;
            end else if ((x>=60) && (x<188) && (y>=188) && (y<202)) begin
                font_id_d = 8'h60 + ((x-60) >> 4);
                font_row_d = (y-188) >> 1;
                font_col_d = ((x-60) >> 1) & 4'h7;
                font_on_d = 1'b1;
            end else if ((x>=60) && (x<204) && (y>=410) && (y<424)) begin
                font_id_d = 8'h70 + ((x-60) >> 4);
                font_row_d = (y-410) >> 1;
                font_col_d = ((x-60) >> 1) & 4'h7;
                font_on_d = 1'b1;
            end else if ((x>=548) && (x<628) && (y>=116) && (y<132)) begin
                font_id_d = 8'h90 + ((x-548) >> 4);
                font_row_d = (y-116) >> 1;
                font_col_d = ((x-548) >> 1) & 4'h7;
                font_on_d = 1'b1;
            end else if ((x>=48) && (x<112) && (y>=578) && (y<594)) begin
                font_id_d = 8'hb0 + ((x-48) >> 4);
                font_row_d = (y-578) >> 1;
                font_col_d = ((x-48) >> 1) & 4'h7;
                font_on_d = 1'b1;
            end else if ((x>=330) && (x<426) && (y>=578) && (y<594)) begin
                font_id_d = 8'hb8 + ((x-330) >> 4);
                font_row_d = (y-578) >> 1;
                font_col_d = ((x-330) >> 1) & 4'h7;
                font_on_d = 1'b1;
            end else if ((x>=585) && (x<681) && (y>=578) && (y<594)) begin
                font_id_d = 8'hc0 + ((x-585) >> 4);
                font_row_d = (y-578) >> 1;
                font_col_d = ((x-585) >> 1) & 4'h7;
                font_on_d = 1'b1;
            end else if ((x>=840) && (x<936) && (y>=578) && (y<594)) begin
                font_id_d = 8'hc8 + ((x-840) >> 4);
                font_row_d = (y-578) >> 1;
                font_col_d = ((x-840) >> 1) & 4'h7;
                font_on_d = 1'b1;
            end else if ((x>=1090) && (x<1202) && (y>=578) && (y<594)) begin
                font_id_d = 8'hd0 + ((x-1090) >> 4);
                font_row_d = (y-578) >> 1;
                font_col_d = ((x-1090) >> 1) & 4'h7;
                font_on_d = 1'b1;
            end
        end
    end

    // Decode text coordinates and capture one complete dashboard pixel
    // context before the color selection stage. The font ROM is deliberately
    // fed from registered character coordinates so it is not on the same
    // long path as the video timing counters.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            font_on_q <= 1'b0;
            font_id_q <= 8'hff;
            font_row_q <= 3'd0;
            font_col_q <= 4'd0;
            de_q <= 1'b0;
            x_q <= 12'd0;
            y_q <= 11'd0;
            polyphony_count_q <= 4'd0;
            peak_bcd_q <= 12'd0;
            peak_valid_q <= 1'b0;
            key_state_q <= 8'd0;
            spectrum_level_q <= 64'd0;
            spectrum_dft_level_q <= 8'd0;
            wave_sample_q <= 16'sd0;
            wave_previous_level_q <= 9'sd0;
            wave_current_level_q <= 9'sd0;
            wave_delta_q <= 9'sd0;
            spectrum_addr <= 8'd0;
        end else begin
            font_on_q <= font_on_d;
            font_id_q <= font_id_d;
            font_row_q <= font_row_d;
            font_col_q <= font_col_d;
            de_q <= de;
            x_q <= x;
            y_q <= y;
            polyphony_count_q <= polyphony_count;
            peak_bcd_q <= peak_bcd;
            peak_valid_q <= peak_valid;
            key_state_q <= key_state;
            spectrum_level_q <= spectrum_level;
            spectrum_dft_level_q <= spectrum_dft_level;
            wave_sample_q <= wave_sample;
            // wave_addr is selected from x_q. At every fourth pixel it
            // prefetches the next source sample one pixel early. Compute
            // the delta from the already registered value, avoiding a
            // RAM-read-plus-subtraction path in one pixel period.
            if ((x_q == 12'd47) && (y_q >= 11'd212) && (y_q < 11'd370)) begin
                wave_previous_level_q <= display_wave_level(wave_sample_q);
                wave_current_level_q <= display_wave_level(wave_sample_q);
                wave_delta_q <= 9'sd0;
            end else if ((x_q >= 12'd48) && (x_q < 12'd1072) &&
                         (y_q >= 11'd212) && (y_q < 11'd370) &&
                         (x_q[1:0] == 2'b00)) begin
                wave_previous_level_q <= wave_current_level_q;
                wave_current_level_q <= display_wave_level(wave_sample_q);
                wave_delta_q <= display_wave_level(wave_sample_q) - wave_current_level_q;
            end
            spectrum_addr <= spectrum_addr_next;
        end
    end

    always @* begin
        wave_addr = 8'd0;
        if ((x_q >= 48) && (x_q < 1072) && (y_q >= 212) && (y_q < 370))
            wave_addr = (x_q - 47) >> 2;
        spectrum_addr_next = 8'd0;
        if ((x >= 48) && (x < 1230) && (y >= 426) && (y < 571)) begin
            spectrum_addr_next = ((x - 48) * 8'd27) >> 8;
            if (spectrum_addr_next > 8'd125)
                spectrum_addr_next = 8'd125;
        end
    end

    // Color stage uses only registered coordinates/data. It retains the
    // dashboard sections while keeping the pixel-rate decision tree shallow.
    always @* begin
        rgb_r = BG[23:16]; rgb_g = BG[15:8]; rgb_b = BG[7:0];
        spectrum_level_pixel = spectrum_dft_level_q;
        spectrum_height = (spectrum_level_pixel >> 1) + (spectrum_level_pixel >> 4);
        spectrum_y = 570 - spectrum_height;
        // Quarter-step linear interpolation between the two real samples.
        // x_q=53/54/55/56 are respectively 1/4, 1/2, 3/4, 1 of the way
        // from sample 0 to sample 1; no extra audio samples are generated.
        case (x_q[1:0])
            2'd1: wave_level = wave_previous_level_q + (wave_delta_q >>> 2);
            2'd2: wave_level = wave_previous_level_q + (wave_delta_q >>> 1);
            2'd3: wave_level = wave_current_level_q - (wave_delta_q >>> 2);
            default: wave_level = wave_current_level_q;
        endcase
        wave_y = 291 - wave_level;
        if (wave_level < 0)
            wave_magnitude = -wave_level;
        else
            wave_magnitude = wave_level;
        wave_rgb = waveform_palette(wave_magnitude[7:0]);
        wave_distance = (y_q >= wave_y) ? (y_q-wave_y) : (wave_y-y_q);
        spectrum_rgb = spectrum_palette(spectrum_addr);
        bar_idx = -1; bar_left = 0; bar_level = 0; bar_top = 570;
        pixel_card_idx = -1; card_left = 0;
        if (!de_q) begin
            rgb_r = 0; rgb_g = 0; rgb_b = 0;
        end else begin
            if (y_q < 64) begin
                rgb_r=PANEL2[23:16]; rgb_g=PANEL2[15:8]; rgb_b=PANEL2[7:0];
                if ((x_q >= 20) && (x_q < 25)) begin rgb_r=CYAN[23:16]; rgb_g=CYAN[15:8]; rgb_b=CYAN[7:0]; end
            end
            if ((x_q >= 32) && (x_q < 1055) && (y_q >= 78) && (y_q < 154)) begin
                if ((x_q < 245) || ((x_q >= 262) && (x_q < 515)) ||
                    ((x_q >= 532) && (x_q < 785)) || (x_q >= 802)) begin
                    rgb_r=PANEL[23:16]; rgb_g=PANEL[15:8]; rgb_b=PANEL[7:0];
                end
            end
            if ((x_q >= 282) && (x_q < 490) && (y_q >= 120) && (y_q < 142)) begin
                if (((x_q < 307) && key_state_q[0]) || ((x_q >= 307) && (x_q < 332) && key_state_q[1]) ||
                    ((x_q >= 332) && (x_q < 357) && key_state_q[2]) || ((x_q >= 357) && (x_q < 382) && key_state_q[3]) ||
                    ((x_q >= 382) && (x_q < 407) && key_state_q[4]) || ((x_q >= 407) && (x_q < 432) && key_state_q[5]) ||
                    ((x_q >= 432) && (x_q < 457) && key_state_q[6]) || ((x_q >= 457) && key_state_q[7])) begin
                    rgb_r=CYAN[23:16]; rgb_g=CYAN[15:8]; rgb_b=CYAN[7:0];
                end else begin rgb_r=GRID[23:16]; rgb_g=GRID[15:8]; rgb_b=GRID[7:0]; end
            end
            if ((x_q >= 32) && (x_q < 1248) && (y_q >= 174) && (y_q < 382)) begin
                rgb_r=PANEL[23:16]; rgb_g=PANEL[15:8]; rgb_b=PANEL[7:0];
                if ((x_q >= 48) && (x_q < 1072) && (y_q >= 212) && (y_q < 370)) begin
                    if ((((x_q-48)&127)==0) || (((y_q-212)&31)==0) || (y_q==291)) begin rgb_r=GRID[23:16]; rgb_g=GRID[15:8]; rgb_b=GRID[7:0]; end
                    if (wave_distance <= 5) begin
                        rgb_r=wave_rgb[23:16] >> 1;
                        rgb_g=wave_rgb[15:8] >> 1;
                        rgb_b=wave_rgb[7:0] >> 1;
                    end
                    if (wave_distance <= 2) begin
                        rgb_r=wave_rgb[23:16];
                        rgb_g=wave_rgb[15:8];
                        rgb_b=wave_rgb[7:0];
                    end
                    if (wave_distance <= 1) begin rgb_r=WHITE[23:16]; rgb_g=WHITE[15:8]; rgb_b=WHITE[7:0]; end
                end
            end
            if ((x_q >= 32) && (x_q < 1248) && (y_q >= 394) && (y_q < 610)) begin
                rgb_r=PANEL[23:16]; rgb_g=PANEL[15:8]; rgb_b=PANEL[7:0];
                if ((x_q >= 48) && (x_q < 1230) && (y_q >= 426) && (y_q < 571)) begin
                    if ((spectrum_level_pixel > 3) && (y_q >= spectrum_y) && (y_q < 570)) begin
                        rgb_r=spectrum_rgb[23:16] >> 1;
                        rgb_g=spectrum_rgb[15:8] >> 1;
                        rgb_b=spectrum_rgb[7:0] >> 1;
                    end
                    if ((((y_q-426)&31)==0) || (y_q==570) || (((x_q-48)&127)==0)) begin
                        rgb_r=GRID[23:16]; rgb_g=GRID[15:8]; rgb_b=GRID[7:0];
                    end
                    if ((spectrum_level_pixel > 3) && (y_q >= spectrum_y-1) && (y_q <= spectrum_y+1)) begin
                        rgb_r=spectrum_rgb[23:16]; rgb_g=spectrum_rgb[15:8]; rgb_b=spectrum_rgb[7:0];
                    end
                end
            end
            if (y_q >= 620) begin
                if ((x_q >= 42) && (x_q < 192)) begin pixel_card_idx=0; card_left=42; end
                else if ((x_q >= 194) && (x_q < 344)) begin pixel_card_idx=1; card_left=194; end
                else if ((x_q >= 346) && (x_q < 496)) begin pixel_card_idx=2; card_left=346; end
                else if ((x_q >= 498) && (x_q < 648)) begin pixel_card_idx=3; card_left=498; end
                else if ((x_q >= 650) && (x_q < 800)) begin pixel_card_idx=4; card_left=650; end
                else if ((x_q >= 802) && (x_q < 952)) begin pixel_card_idx=5; card_left=802; end
                else if ((x_q >= 954) && (x_q < 1104)) begin pixel_card_idx=6; card_left=954; end
                else if ((x_q >= 1106) && (x_q < 1256)) begin pixel_card_idx=7; card_left=1106; end
                if (pixel_card_idx >= 0) begin
                    if (key_state_q[pixel_card_idx]) begin rgb_r=8'h1d; rgb_g=8'h4b; rgb_b=8'h4b; end
                    else begin rgb_r=PANEL2[23:16]; rgb_g=PANEL2[15:8]; rgb_b=PANEL2[7:0]; end
                    case (pixel_card_idx)
                        0:bar_level=spectrum_level_q[7:0]; 1:bar_level=spectrum_level_q[15:8];
                        2:bar_level=spectrum_level_q[23:16]; 3:bar_level=spectrum_level_q[31:24];
                        4:bar_level=spectrum_level_q[39:32]; 5:bar_level=spectrum_level_q[47:40];
                        6:bar_level=spectrum_level_q[55:48]; 7:bar_level=spectrum_level_q[63:56];
                        default:bar_level=0;
                    endcase
                    if ((y_q >= 690) && (y_q < 697)) begin
                        if ((x_q >= card_left+22) && (x_q < card_left+22+(bar_level>>1))) begin rgb_r=CYAN[23:16]; rgb_g=CYAN[15:8]; rgb_b=CYAN[7:0]; end
                        else begin rgb_r=GRID[23:16]; rgb_g=GRID[15:8]; rgb_b=GRID[7:0]; end
                    end
                end
            end
            if (font_on_q && (font_col_q < 5) && font_pixels[4-font_col_q]) begin rgb_r=WHITE[23:16]; rgb_g=WHITE[15:8]; rgb_b=WHITE[7:0]; end
        end
    end
endmodule
