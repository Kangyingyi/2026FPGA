`timescale 1ns/1ps
// Gentle chorus: dry signal plus a low-level, slowly modulated short delay.
module audio_chorus #(parameter integer DEPTH=520,parameter integer PTR_W=10)(input wire clk,input wire rst_n,input wire sample_tick,input wire signed [15:0] audio_in,output reg signed [15:0] audio_out);
(* ram_style = "block" *) reg signed [15:0] ram[0:DEPTH-1]; reg [PTR_W-1:0] wr_ptr,rd_ptr; reg [PTR_W-1:0] fill_count; reg [31:0] lfo; reg [7:0] mod_n; reg [9:0] delay_n; reg signed [15:0] delayed_sample; reg signed [17:0] mix;
always @* begin mod_n=lfo[31]?(8'd127-lfo[30:24]):lfo[30:24]; delay_n=10'd360+({2'd0,mod_n}>>1); if(wr_ptr>=delay_n) rd_ptr=wr_ptr-delay_n; else rd_ptr=wr_ptr+DEPTH-delay_n; end
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin wr_ptr<=0;lfo<=0;fill_count<=0;delayed_sample<=0;audio_out<=0; end
 else if(sample_tick) begin
  delayed_sample<=ram[rd_ptr];
  if(fill_count<delay_n) mix={{2{audio_in[15]}},audio_in}; else mix={{2{audio_in[15]}},audio_in}+({{2{delayed_sample[15]}},delayed_sample}>>>3);
  if(mix>18'sd32767)audio_out<=16'sh7fff; else if(mix<-18'sd32768)audio_out<=-16'sh8000; else audio_out<=mix[15:0];
  ram[wr_ptr]<=audio_in; wr_ptr<=(wr_ptr==DEPTH-1)?0:wr_ptr+1'b1; if(fill_count<DEPTH)fill_count<=fill_count+1'b1; lfo<=lfo+32'd22000;
 end
end
endmodule
