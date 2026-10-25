`timescale 1ns/1ps
// Asynchronous assertion, three local clock edges before release.
// Three stages preserve the previous top-level reset latency.
module reset_sync(input clk,input ext_rst_n,output rst_n_sync);
 (* async_reg = "true" *) reg [2:0] stages;
 always @(posedge clk or negedge ext_rst_n)
   if(!ext_rst_n) stages<=3'b000;
   else stages<={stages[1:0],1'b1};
 assign rst_n_sync=stages[2];
endmodule