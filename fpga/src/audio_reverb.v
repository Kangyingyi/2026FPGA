`timescale 1ns/1ps
// Schroeder-style reverb: four parallel comb lines with a bounded tail.
// voice_active is supplied by the touch-key state. After three seconds with
// no touched key, the effect is forced silent and its delay lines are cleared.
module audio_reverb(
    input  wire clk,
    input  wire rst_n,
    input  wire sample_tick,
    input  wire voice_active,
    input  wire signed [15:0] audio_in,
    output reg  signed [15:0] audio_out
);
localparam integer D0=1416, D1=1807, D2=2099, D3=2588;
localparam integer TAIL_SAMPLES=146400; // 3 s at approximately 48.8 kHz
(* ram_style = "block" *) reg signed [15:0] r0[0:D0-1];
(* ram_style = "block" *) reg signed [15:0] r1[0:D1-1];
(* ram_style = "block" *) reg signed [15:0] r2[0:D2-1];
(* ram_style = "block" *) reg signed [15:0] r3[0:D3-1];
reg [11:0] p0,p1,p2;
reg [12:0] p3;
reg [12:0] startup;
reg [17:0] idle_samples;
reg signed [15:0] d0,d1,d2,d3;
reg signed [19:0] wet_sum,w0,w1,w2,w3;
reg signed [20:0] out_sum;
wire tail_expired = (idle_samples >= TAIL_SAMPLES-1);

always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin
  p0<=0; p1<=0; p2<=0; p3<=0; startup<=0; idle_samples<=0;
  d0<=0; d1<=0; d2<=0; d3<=0; audio_out<=0;
 end else if(sample_tick) begin
  d0<=r0[(p0==D0-1)?0:p0+1'b1];
  d1<=r1[(p1==D1-1)?0:p1+1'b1];
  d2<=r2[(p2==D2-1)?0:p2+1'b1];
  d3<=r3[(p3==D3-1)?0:p3+1'b1];

  if (voice_active)
    idle_samples <= 0;
  else if (idle_samples < TAIL_SAMPLES)
    idle_samples <= idle_samples + 1'b1;

  if(startup < D3) begin
    wet_sum=0;
    startup<=startup+1'b1;
  end else if(tail_expired) begin
    // Keep writing zeroes after timeout so an old tail cannot reappear.
    wet_sum=0;
  end else begin
    wet_sum=({{4{d0[15]}},d0}+{{4{d1[15]}},d1}+
             {{4{d2[15]}},d2}+{{4{d3[15]}},d3})>>>3;
  end

  if(tail_expired && !voice_active) begin
    audio_out<=16'sd0;
    w0=0; w1=0; w2=0; w3=0;
  end else begin
    out_sum={{5{audio_in[15]}},audio_in}+{{1{wet_sum[19]}},wet_sum};
    if(out_sum>21'sd32767) audio_out<=16'sh7fff;
    else if(out_sum<-21'sd32768) audio_out<=-16'sh8000;
    else if((out_sum<21'sd24)&&(out_sum>-21'sd24)) audio_out<=0;
    else audio_out<=out_sum[15:0];
    w0={{4{audio_in[15]}},audio_in}+({{4{d0[15]}},d0}>>>3);
    w1={{4{audio_in[15]}},audio_in}+({{4{d1[15]}},d1}>>>3);
    w2={{4{audio_in[15]}},audio_in}+({{4{d2[15]}},d2}>>>3);
    w3={{4{audio_in[15]}},audio_in}+({{4{d3[15]}},d3}>>>3);
  end

  if(w0>20'sd32767) r0[p0]<=16'sh7fff;
  else if(w0<-20'sd32768) r0[p0]<=-16'sh8000;
  else r0[p0]<=w0[15:0];
  if(w1>20'sd32767) r1[p1]<=16'sh7fff;
  else if(w1<-20'sd32768) r1[p1]<=-16'sh8000;
  else r1[p1]<=w1[15:0];
  if(w2>20'sd32767) r2[p2]<=16'sh7fff;
  else if(w2<-20'sd32768) r2[p2]<=-16'sh8000;
  else r2[p2]<=w2[15:0];
  if(w3>20'sd32767) r3[p3]<=16'sh7fff;
  else if(w3<-20'sd32768) r3[p3]<=-16'sh8000;
  else r3[p3]<=w3[15:0];

  p0<=(p0==D0-1)?0:p0+1'b1;
  p1<=(p1==D1-1)?0:p1+1'b1;
  p2<=(p2==D2-1)?0:p2+1'b1;
  p3<=(p3==D3-1)?0:p3+1'b1;
 end
end
endmodule
