`timescale 1ns/1ps

module i2s_tx (
    input  wire              clk,
    input  wire              rst_n,
    input  wire signed [15:0] sample_l,
    input  wire signed [15:0] sample_r,
    output wire              i2s_bclk,
    output wire              i2s_lrck,
    output wire              i2s_din,
    output reg               sample_tick
);
    reg [4:0] clk_div;
    reg [5:0] bit_count;
    reg bclk_reg, lrck_reg, din_reg;
    reg signed [15:0] left_hold, right_hold;
    assign i2s_bclk = bclk_reg;
    assign i2s_lrck = lrck_reg;
    assign i2s_din  = din_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_div <= 0; bit_count <= 6'd31; bclk_reg <= 0; lrck_reg <= 1;
            din_reg <= 0; left_hold <= 0; right_hold <= 0; sample_tick <= 0;
        end else begin
            sample_tick <= 1'b0;
            if (clk_div == 5'd15) begin
                clk_div <= 0;
                if (!bclk_reg) begin
                    bclk_reg <= 1'b1;
                    if (bit_count == 6'd31) bit_count <= 0;
                    else bit_count <= bit_count + 1'b1;
                end else begin
                    bclk_reg <= 1'b0;
                    case (bit_count)
                        6'd0: begin left_hold<=sample_l; right_hold<=sample_r; din_reg<=sample_l[15]; lrck_reg<=0; sample_tick<=1; end
                        6'd1: din_reg<=left_hold[14]; 6'd2: din_reg<=left_hold[13]; 6'd3: din_reg<=left_hold[12];
                        6'd4: din_reg<=left_hold[11]; 6'd5: din_reg<=left_hold[10]; 6'd6: din_reg<=left_hold[9];
                        6'd7: din_reg<=left_hold[8]; 6'd8: din_reg<=left_hold[7]; 6'd9: din_reg<=left_hold[6];
                        6'd10: din_reg<=left_hold[5]; 6'd11: din_reg<=left_hold[4]; 6'd12: din_reg<=left_hold[3];
                        6'd13: din_reg<=left_hold[2]; 6'd14: din_reg<=left_hold[1]; 6'd15: din_reg<=left_hold[0];
                        6'd16: begin din_reg<=right_hold[15]; lrck_reg<=1; end
                        6'd17: din_reg<=right_hold[14]; 6'd18: din_reg<=right_hold[13]; 6'd19: din_reg<=right_hold[12];
                        6'd20: din_reg<=right_hold[11]; 6'd21: din_reg<=right_hold[10]; 6'd22: din_reg<=right_hold[9];
                        6'd23: din_reg<=right_hold[8]; 6'd24: din_reg<=right_hold[7]; 6'd25: din_reg<=right_hold[6];
                        6'd26: din_reg<=right_hold[5]; 6'd27: din_reg<=right_hold[4]; 6'd28: din_reg<=right_hold[3];
                        6'd29: din_reg<=right_hold[2]; 6'd30: din_reg<=right_hold[1]; 6'd31: din_reg<=right_hold[0];
                        default: din_reg<=0;
                    endcase
                end
            end else clk_div <= clk_div + 1'b1;
        end
    end
endmodule
