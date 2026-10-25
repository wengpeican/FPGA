`timescale 1ns/1ps
// Board passive speaker: official DEMO/13_music/a.adc maps spk to H11.
// Yellow retains the PCM sign waveform. Red uses a full 50% duty carrier:
// the sine LUT's zero samples previously shortened its positive half cycle.
// All counters run on clk; no generated clock or pin voltage increase.
module status_buzzer_output #(parameter integer CLOCK_HZ=25000000)(
 input wire clk,
 input wire rst,
 input wire sample_valid,
 input wire signed [15:0] sample_pcm,
 input wire [1:0] alarm_status,
 output reg buzzer
);
 localparam integer RED_HALF_CYCLES=CLOCK_HZ/4000;
 localparam integer RED_ON_CYCLES=CLOCK_HZ/10;
 localparam integer RED_PERIOD_CYCLES=CLOCK_HZ/8;
 reg [12:0] red_half_count;
 reg [21:0] red_cadence;
 reg red_level;
 always @(posedge clk or posedge rst) begin
  if(rst)begin red_half_count<=0;red_cadence<=0;red_level<=1;end
  else if(alarm_status!=2)begin red_half_count<=0;red_cadence<=0;red_level<=1;end
  else begin
   if(red_cadence==RED_PERIOD_CYCLES-1)red_cadence<=0;
   else red_cadence<=red_cadence+1'b1;
   if(red_cadence>=RED_ON_CYCLES)begin red_half_count<=0;red_level<=1;end
   else if(red_half_count==RED_HALF_CYCLES-1)begin red_half_count<=0;red_level<=~red_level;end
   else red_half_count<=red_half_count+1'b1;
  end
 end
 always @(posedge clk or posedge rst)
  if(rst) buzzer<=1'b0;
  else if(alarm_status==0) buzzer<=1'b0;
  else if(alarm_status==2) buzzer<=red_cadence<RED_ON_CYCLES && red_level;
  else if(sample_valid) buzzer<=sample_pcm>16'sd0;
endmodule
