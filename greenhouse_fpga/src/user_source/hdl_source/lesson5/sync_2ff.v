`timescale 1ns/1ps
// Slow single-bit status only; multi-bit payloads require a handshake/FIFO.
module sync_2ff(input clk,input rst_n,input async_in,output sync_out);
 (* async_reg = "true" *) reg s1,s2;
 always @(posedge clk or negedge rst_n)
   if(!rst_n)begin s1<=0;s2<=0;end
   else begin s1<=async_in;s2<=s1;end
 assign sync_out=s2;
endmodule