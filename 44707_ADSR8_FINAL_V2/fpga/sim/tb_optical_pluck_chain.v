`timescale 1ns/1ps
module tb_optical_pluck_chain;
 reg clk=0,rst_n=0,rx=1,optical=0;
 reg [7:0] keys=0;
 tri1 scl,sda;
 wire tx,bclk,lrck,din,pa;
 wire [7:0] led;
 integer nonzero=0, triggers=0;
 always #10 clk=~clk;
 top #(.DEBOUNCE_CYCLES(2),.UART_CLKS_PER_BIT(8)) dut(
  .sys_clk(clk),.rst_n(rst_n),.key_in(keys),.BLE_RX(rx),.OPTICAL_IN(optical),
  .BLE_TX(tx),.led_out(led),
  .I2S_BCLK(bclk),.I2S_LRCK(lrck),.I2S_DIN(din),.PA_EN(pa));
 always @(posedge clk) if(rst_n && dut.sample_tick) begin
  if(dut.audio_pressure != 0) nonzero=nonzero+1;
  if(dut.pluck_trigger) triggers=triggers+1;
 end
 task send_byte(input [7:0] value);
  begin
   @(negedge clk);rx=0;repeat(8) @(negedge clk);
   for(integer b=0;b<8;b=b+1) begin rx=value[b];repeat(8) @(negedge clk);end
   rx=1;repeat(8) @(negedge clk);
  end
 endtask
 initial begin
  repeat(3) @(negedge clk);rst_n=1;
  send_byte(8'hA5);send_byte(8'h12);send_byte(8'h01);
  send_byte(8'h00);send_byte(8'h05);send_byte(8'h18);
  repeat(1000) @(negedge clk);
  if(dut.mode_sel !== 5) $fatal(1,"UART did not select pluck mode");
  keys=1;repeat(12000) @(negedge clk);
  if(nonzero != 0) $fatal(1,"Key alone made sound");
  optical=1;repeat(20000) @(negedge clk);
  if(triggers != 1 || nonzero == 0) $fatal(1,"Optical pluck failed: events=%0d samples=%0d",triggers,nonzero);
  $display("OPTICAL_CHAIN_PASS mode=%0d optical_events=%0d audible_samples=%0d",dut.mode_sel,triggers,nonzero);
  $finish;
 end
 initial begin #2000000;$fatal(1,"Timeout");end
endmodule
