`timescale 1ns/1ps
module tb_adsr_presets;
 reg clk=0,rst=0,tick=0,gate=0;
 reg [2:0] tone=7;
 wire signed [15:0] audio;
 integer i,j,n,changes;
 reg [31:0] old_phase;
 reg signed [15:0] old_audio;
 instrument_voice dut(.clk(clk),.rst_n(rst),.sample_tick(tick),.note_active(gate),
   .tone_sel(tone),.phase_step(32'd23013218),.sample(audio));
 always #5 clk=~clk;
 task sample_step;
 begin
   @(negedge clk); tick=1;
   @(negedge clk); tick=0;
   repeat(2) @(negedge clk);
 end endtask
 initial begin
  repeat(3) @(negedge clk); rst=1;
  for(i=0;i<8;i=i+1) begin
   tone=i; gate=1;
   // Deliberately change gate between sample ticks.
   repeat(2) @(negedge clk);
   sample_step();
   if(dut.env_state!==1) $fatal(1,"missed asynchronous key onset tone %0d",i);
   for(j=0;j<45000;j=j+1) sample_step();
   if(dut.env_state!==3 || dut.envelope!==dut.sustain_level)
     $fatal(1,"sustain failed tone %0d",i);
   // Retrigger while held-state test starts from idle again.
   gate=0; n=0;
   while(dut.envelope!=0 && n<40000) begin sample_step(); n=n+1; end
   sample_step();
   if(dut.envelope!==0 || audio!==0) $fatal(1,"release stuck tone %0d",i);
   gate=1;
   sample_step();
   for(j=0;j<1000;j=j+1) sample_step();
   gate=0; old_phase=dut.phase; changes=0; old_audio=audio;
   for(j=0;j<20;j=j+1) begin
    sample_step();
    if(dut.phase===old_phase) $fatal(1,"release phase frozen tone %0d",i);
    if(audio!==old_audio) changes=changes+1;
    old_phase=dut.phase; old_audio=audio;
   end
   if(changes<2) $fatal(1,"release is not oscillating tone %0d",i);
   gate=1; repeat(2) @(negedge clk); sample_step();
   if(dut.env_state!==1) $fatal(1,"retrigger missed tone %0d",i);
   gate=0; for(j=0;j<33000;j=j+1) sample_step();
  end
  $display("ADSR_8_PRESETS_PASS"); $finish;
 end
endmodule

