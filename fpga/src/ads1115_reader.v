`timescale 1ns/1ps

// Minimal ADS1115 single-shot reader.  A0 is sampled at 128 SPS with the
// +/-4.096 V PGA setting.  The interface is open-drain and needs 3.3 V
// pull-ups on SDA/SCL (normally fitted on the breakout board).
module ads1115_reader #(
    parameter integer CLK_HZ = 50000000,
    parameter integer I2C_HZ = 100000
) (
    input  wire clk, input wire rst_n,
    inout  wire scl, inout wire sda,
    output reg [15:0] adc_value,
    output reg adc_valid
);
    localparam integer DIV = CLK_HZ/(I2C_HZ*2);
    reg [$clog2(DIV+1)-1:0] divcnt;
    reg scl_low, sda_low;
    assign scl = scl_low ? 1'b0 : 1'bz;
    assign sda = sda_low ? 1'b0 : 1'bz;
    wire sda_in = sda;
    reg [7:0] tx;
    reg [7:0] rx_hi;
    reg [7:0] rx_lo;
    reg [3:0] bitn;
    reg [2:0] state, phase;
    reg [2:0] byte_n;
    reg [23:0] waitcnt;
    localparam IDLE=0, START=1, SEND=2, ACK=3, READ=4, RNACK=5, STOP=6, WAIT=7;

    wire tick = (divcnt == DIV-1);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            divcnt<=0; scl_low<=0; sda_low<=0; tx<=0; rx_hi<=0; rx_lo<=0; bitn<=0;
            state<=IDLE; phase<=0; byte_n<=0; waitcnt<=0; adc_value<=0; adc_valid<=0;
        end else begin
            adc_valid <= 1'b0;
            if (!tick) divcnt <= divcnt + 1'b1;
            else begin
                divcnt <= 0;
                case (state)
                    IDLE: begin
                        scl_low<=0; sda_low<=0; byte_n<=0; tx<=8'h90;
                        state<=START; phase<=0;
                    end
                    START: begin
                        // I2C START: release SCL/SDA, pull SDA low while SCL
                        // is high, then pull SCL low before transmitting.
                        if (!phase) begin scl_low<=0; sda_low<=0; phase<=1; end
                        else if (phase==1) begin sda_low<=1; phase<=2; end
                        else begin scl_low<=1; phase<=0; bitn<=7; state<=SEND; end
                    end
                    SEND: begin
                        if (!phase) begin
                            sda_low <= ~tx[bitn]; phase<=1;
                        end else begin
                            scl_low<=0; phase<=2;
                        end
                        if (phase==2) begin
                            scl_low<=1; phase<=0;
                            if (bitn==0) state<=ACK; else bitn<=bitn-1'b1;
                        end
                    end
                    ACK: begin
                        sda_low<=0;
                        if (!phase) begin scl_low<=0; phase<=1; end
                        else begin scl_low<=1; phase<=0;
                            if (byte_n==0) begin tx<=8'h01; byte_n<=1; bitn<=7; state<=SEND; end
                            // OS=1, AIN0-GND, PGA=+/-4.096 V, single-shot,
                            // 128 SPS, comparator disabled.
                            else if (byte_n==1) begin tx<=8'hC3; byte_n<=2; bitn<=7; state<=SEND; end
                            else if (byte_n==2) begin tx<=8'h83; byte_n<=3; bitn<=7; state<=SEND; end
                            else if (byte_n==3) begin
                                // Configuration complete; conversion runs
                                // during WAIT before register 0 is read.
                                sda_low<=0; state<=STOP;
                            end else if (byte_n==4) begin
                                tx<=8'h00; byte_n<=5; bitn<=7; state<=SEND;
                            end else if (byte_n==5) begin
                                tx<=8'h91; byte_n<=6; bitn<=7; state<=START; phase<=0;
                            end else if (byte_n==6) begin
                                sda_low<=0; bitn<=7; byte_n<=5; state<=READ; phase<=0;
                            end else begin sda_low<=0; state<=STOP; end
                        end
                    end
                    READ: begin
                        sda_low<=0;
                        if (!phase) begin scl_low<=0; phase<=1; end
                        else begin
                            if (scl_low==0) begin
                                if (byte_n==5) rx_hi[bitn]<=sda_in;
                                else rx_lo[bitn]<=sda_in;
                                scl_low<=1; phase<=0;
                                if (bitn==0) begin
                                    state<=RNACK; phase<=0;
                                end else bitn<=bitn-1'b1;
                            end
                        end
                    end
                    RNACK: begin
                        // Finish the high byte with ACK, read low byte, then
                        // finish with NACK and STOP.  Low byte is sampled in
                        // adc_value directly to keep the logic compact.
                        if (!phase) begin
                            // ACK after high byte, NACK after low byte.
                            sda_low <= (byte_n==5); scl_low<=0; phase<=1;
                        end else begin
                            scl_low<=1; sda_low<=0; phase<=0;
                            if (byte_n==5) begin bitn<=7; state<=READ; byte_n<=6; end
                            else begin
                                adc_value <= {rx_hi,rx_lo}; adc_valid<=1'b1;
                                state<=STOP;
                            end
                        end
                    end
                    STOP: begin
                        scl_low<=1; sda_low<=1; phase<=1; state<=WAIT; waitcnt<=0;
                    end
                    WAIT: begin
                        scl_low<=0; sda_low<=0;
                        if (waitcnt < 24'd500000) waitcnt<=waitcnt+1'b1;
                        else begin
                            // After a single-shot configuration write, wait
                            // for the ADS1115 conversion before reading it.
                            // Every transaction starts with the ADS1115 write
                            // address.  Without this assignment the first
                            // read cycle would resend the previous config
                            // byte instead of 0x90, leaving adc_value stale.
                            tx<=8'h90;
                            if (byte_n==3) byte_n<=4;
                            else byte_n<=0;
                            state<=START; phase<=0;
                        end
                    end
                    default: state<=IDLE;
                endcase
            end
        end
    end
endmodule
