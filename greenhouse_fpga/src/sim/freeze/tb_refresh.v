`timescale 1ns/1ps
`include "global_def.v"
module tb_refresh;
reg clk=0,rst=1;always #10 clk=~clk;
wire done,req,vld;integer errors=0,cyc=0,last=0,pulses=0,logfd;
sdr_init_ref #(.self_refresh_open(1)) dut(
.Sdr_clk(clk),.Rst(rst),.Sdr_init_req(1'b0),.Sdr_init_mode(4'b1000),.Sdr_init_done(done),
.App_ref_req(1'b0),.Sdr_ref_req(req),.Sdr_ref_ack(req),.Sdr_rw_vld(1'b0),
.Sdr_init_ref_vld(vld),.Sdr_init_ref_ras(),.Sdr_init_ref_cas(),.Sdr_init_ref_we(),.Sdr_init_ref_ba(),.Sdr_init_ref_addr());
always @(posedge clk) if(!rst) begin
cyc=cyc+1;
if(req) begin
 if(last!=0 && cyc-last!=1562) begin errors=errors+1;$fdisplay(logfd,"FAIL refresh gap=%0d",cyc-last);end
 last=cyc;pulses=pulses+1;
end
end
initial begin
logfd=$fopen("refresh_result.txt","w");
if(`SDR_CLK_PERIOD!=20 || `SELF_REFRESH_INTERVAL!=1561)errors=errors+1;
repeat(8)@(negedge clk);rst=0;
repeat(160000)@(negedge clk);
if(!done || pulses<10)errors=errors+1;
$fdisplay(logfd,"RESULT errors=%0d refresh_pulses=%0d interval_cycles=1562",errors,pulses);$fclose(logfd);$finish;
end
endmodule