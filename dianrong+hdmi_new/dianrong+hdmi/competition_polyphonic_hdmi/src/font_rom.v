`timescale 1ns/1ps

// 5x7 ASCII font used by the hardware monitor. Unsupported characters are blank.
module font_rom (
    input  wire [7:0] char_code,
    input  wire [2:0] row,
    output reg  [4:0] pixels
);
    always @* begin
        pixels = 5'b00000;
        case (char_code)
            8'h20: pixels = 5'b00000;
            8'h30: case(row) 0:pixels=5'b01110;1:pixels=5'b10001;2:pixels=5'b10011;3:pixels=5'b10101;4:pixels=5'b11001;5:pixels=5'b10001;6:pixels=5'b01110; endcase
            8'h31: case(row) 0:pixels=5'b00100;1:pixels=5'b01100;2:pixels=5'b00100;3:pixels=5'b00100;4:pixels=5'b00100;5:pixels=5'b00100;6:pixels=5'b01110; endcase
            8'h32: case(row) 0:pixels=5'b01110;1:pixels=5'b10001;2:pixels=5'b00001;3:pixels=5'b00010;4:pixels=5'b00100;5:pixels=5'b01000;6:pixels=5'b11111; endcase
            8'h33: case(row) 0:pixels=5'b11110;1:pixels=5'b00001;2:pixels=5'b00001;3:pixels=5'b01110;4:pixels=5'b00001;5:pixels=5'b00001;6:pixels=5'b11110; endcase
            8'h34: case(row) 0:pixels=5'b00010;1:pixels=5'b00110;2:pixels=5'b01010;3:pixels=5'b10010;4:pixels=5'b11111;5:pixels=5'b00010;6:pixels=5'b00010; endcase
            8'h35: case(row) 0:pixels=5'b11111;1:pixels=5'b10000;2:pixels=5'b10000;3:pixels=5'b11110;4:pixels=5'b00001;5:pixels=5'b00001;6:pixels=5'b11110; endcase
            8'h36: case(row) 0:pixels=5'b00110;1:pixels=5'b01000;2:pixels=5'b10000;3:pixels=5'b11110;4:pixels=5'b10001;5:pixels=5'b10001;6:pixels=5'b01110; endcase
            8'h37: case(row) 0:pixels=5'b11111;1:pixels=5'b00001;2:pixels=5'b00010;3:pixels=5'b00100;4:pixels=5'b01000;5:pixels=5'b01000;6:pixels=5'b01000; endcase
            8'h38: case(row) 0:pixels=5'b01110;1:pixels=5'b10001;2:pixels=5'b10001;3:pixels=5'b01110;4:pixels=5'b10001;5:pixels=5'b10001;6:pixels=5'b01110; endcase
            8'h39: case(row) 0:pixels=5'b01110;1:pixels=5'b10001;2:pixels=5'b10001;3:pixels=5'b01111;4:pixels=5'b00001;5:pixels=5'b00010;6:pixels=5'b11100; endcase
            8'h41: case(row) 0:pixels=5'b01110;1:pixels=5'b10001;2:pixels=5'b10001;3:pixels=5'b11111;4:pixels=5'b10001;5:pixels=5'b10001;6:pixels=5'b10001; endcase
            8'h42: case(row) 0:pixels=5'b11110;1:pixels=5'b10001;2:pixels=5'b10001;3:pixels=5'b11110;4:pixels=5'b10001;5:pixels=5'b10001;6:pixels=5'b11110; endcase
            8'h43: case(row) 0:pixels=5'b01111;1:pixels=5'b10000;2:pixels=5'b10000;3:pixels=5'b10000;4:pixels=5'b10000;5:pixels=5'b10000;6:pixels=5'b01111; endcase
            8'h44: case(row) 0:pixels=5'b11110;1:pixels=5'b10001;2:pixels=5'b10001;3:pixels=5'b10001;4:pixels=5'b10001;5:pixels=5'b10001;6:pixels=5'b11110; endcase
            8'h45: case(row) 0:pixels=5'b11111;1:pixels=5'b10000;2:pixels=5'b10000;3:pixels=5'b11110;4:pixels=5'b10000;5:pixels=5'b10000;6:pixels=5'b11111; endcase
            8'h46: case(row) 0:pixels=5'b11111;1:pixels=5'b10000;2:pixels=5'b10000;3:pixels=5'b11110;4:pixels=5'b10000;5:pixels=5'b10000;6:pixels=5'b10000; endcase
            8'h47: case(row) 0:pixels=5'b01111;1:pixels=5'b10000;2:pixels=5'b10000;3:pixels=5'b10111;4:pixels=5'b10001;5:pixels=5'b10001;6:pixels=5'b01111; endcase
            8'h48: case(row) 0:pixels=5'b10001;1:pixels=5'b10001;2:pixels=5'b10001;3:pixels=5'b11111;4:pixels=5'b10001;5:pixels=5'b10001;6:pixels=5'b10001; endcase
            8'h49: case(row) 0:pixels=5'b11111;1:pixels=5'b00100;2:pixels=5'b00100;3:pixels=5'b00100;4:pixels=5'b00100;5:pixels=5'b00100;6:pixels=5'b11111; endcase
            8'h4B: case(row) 0:pixels=5'b10001;1:pixels=5'b10010;2:pixels=5'b10100;3:pixels=5'b11000;4:pixels=5'b10100;5:pixels=5'b10010;6:pixels=5'b10001; endcase
            8'h4C: case(row) 0:pixels=5'b10000;1:pixels=5'b10000;2:pixels=5'b10000;3:pixels=5'b10000;4:pixels=5'b10000;5:pixels=5'b10000;6:pixels=5'b11111; endcase
            8'h4D: case(row) 0:pixels=5'b10001;1:pixels=5'b11011;2:pixels=5'b10101;3:pixels=5'b10101;4:pixels=5'b10001;5:pixels=5'b10001;6:pixels=5'b10001; endcase
            8'h4E: case(row) 0:pixels=5'b10001;1:pixels=5'b11001;2:pixels=5'b10101;3:pixels=5'b10011;4:pixels=5'b10001;5:pixels=5'b10001;6:pixels=5'b10001; endcase
            8'h4F: case(row) 0:pixels=5'b01110;1:pixels=5'b10001;2:pixels=5'b10001;3:pixels=5'b10001;4:pixels=5'b10001;5:pixels=5'b10001;6:pixels=5'b01110; endcase
            8'h50: case(row) 0:pixels=5'b11110;1:pixels=5'b10001;2:pixels=5'b10001;3:pixels=5'b11110;4:pixels=5'b10000;5:pixels=5'b10000;6:pixels=5'b10000; endcase
            8'h51: case(row) 0:pixels=5'b01110;1:pixels=5'b10001;2:pixels=5'b10001;3:pixels=5'b10001;4:pixels=5'b10101;5:pixels=5'b10010;6:pixels=5'b01101; endcase
            8'h52: case(row) 0:pixels=5'b11110;1:pixels=5'b10001;2:pixels=5'b10001;3:pixels=5'b11110;4:pixels=5'b10100;5:pixels=5'b10010;6:pixels=5'b10001; endcase
            8'h53: case(row) 0:pixels=5'b01111;1:pixels=5'b10000;2:pixels=5'b10000;3:pixels=5'b01110;4:pixels=5'b00001;5:pixels=5'b00001;6:pixels=5'b11110; endcase
            8'h54: case(row) 0:pixels=5'b11111;1:pixels=5'b00100;2:pixels=5'b00100;3:pixels=5'b00100;4:pixels=5'b00100;5:pixels=5'b00100;6:pixels=5'b00100; endcase
            8'h55: case(row) 0:pixels=5'b10001;1:pixels=5'b10001;2:pixels=5'b10001;3:pixels=5'b10001;4:pixels=5'b10001;5:pixels=5'b10001;6:pixels=5'b01110; endcase
            8'h56: case(row) 0:pixels=5'b10001;1:pixels=5'b10001;2:pixels=5'b10001;3:pixels=5'b10001;4:pixels=5'b10001;5:pixels=5'b01010;6:pixels=5'b00100; endcase
            8'h57: case(row) 0:pixels=5'b10001;1:pixels=5'b10001;2:pixels=5'b10001;3:pixels=5'b10101;4:pixels=5'b10101;5:pixels=5'b11011;6:pixels=5'b10001; endcase
            8'h59: case(row) 0:pixels=5'b10001;1:pixels=5'b10001;2:pixels=5'b01010;3:pixels=5'b00100;4:pixels=5'b00100;5:pixels=5'b00100;6:pixels=5'b00100; endcase
            8'h2B: case(row) 0:pixels=5'b00100;1:pixels=5'b00100;2:pixels=5'b11111;3:pixels=5'b00100;4:pixels=5'b00100;5:pixels=5'b00000;6:pixels=5'b00000; endcase
            8'h2D: case(row) 0:pixels=5'b00000;1:pixels=5'b00000;2:pixels=5'b00000;3:pixels=5'b11111;4:pixels=5'b00000;5:pixels=5'b00000;6:pixels=5'b00000; endcase
            8'h2E: case(row) 0:pixels=5'b00000;1:pixels=5'b00000;2:pixels=5'b00000;3:pixels=5'b00000;4:pixels=5'b00000;5:pixels=5'b00100;6:pixels=5'b00100; endcase
            8'h7A: case(row) 0:pixels=5'b00000;1:pixels=5'b00000;2:pixels=5'b11110;3:pixels=5'b00001;4:pixels=5'b01110;5:pixels=5'b10000;6:pixels=5'b11111; endcase
            default: pixels = 5'b00000;
        endcase
    end
endmodule
