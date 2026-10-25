`timescale 1ns/1ps
module tb_recovery;
reg clk=0,rst=1,k1=1,k2=1,fin=0;
reg init_ok=0,ready=1,scanned=0,found=0,parser_done=0;
reg [31:0] sector=0;
wire [3:0] code;
integer errors=0,starts=0,i,age=0,delay_cycles=80,stamp=0,last_commit=0,commits=0;
reg active_buf=0, hold_reader=0; integer ack_age=0;
reg stalled=0, monitor_auto=0;
reg [3:0] oldcode=0;
sd_card_bmp #(.USE_FAT32(0),.WAIT_READ_ACK(1),.CLK_FREQ_HZ(1000),.AUTO_PLAY_MS(3000),.LONG_PRESS_MS(1000),.LOAD_TIMEOUT_MS(500)) dut(
.clk(clk),.rst(rst),.startup_ready(1'b1),.key_next(k1),.key_auto(k2),.bmp_width(16'd640),.bmp_height(16'd480),
.read_active_buf(active_buf),.state_code(code),.write_finish_toggle(fin),.write_req_ack(1'b0),.SD_MISO(1'b1));
always #5 clk=~clk;
always @(posedge clk) begin
 stamp=stamp+1; parser_done=0;
 if(active_buf != dut.disp_buf_idx[0] && !hold_reader) begin
   ack_age=ack_age+1;
   if(ack_age==15) begin active_buf=dut.disp_buf_idx[0];ack_age=0;end
 end
 if(dut.load_start_pulse) begin starts=starts+1; age=1; #1 ready=0; end
 else if(age>0 && !stalled) begin
   age=age+1;
   if(age==delay_cycles) begin #1 ready=1; parser_done=1; fin=~fin; age=0; end
 end
 if(dut.load_abort) begin #1 ready=1; age=0; scanned=0; end
end
always @(negedge clk) begin
 if(code!=oldcode) begin
  if(monitor_auto && commits>0 && stamp-last_commit!=3000) begin
   errors=errors+1; $display("FAIL dwell=%0d expected=3000",stamp-last_commit);
  end
  if(monitor_auto) begin last_commit=stamp; commits=commits+1; end
  oldcode=code;
 end
end
task tick; input integer n; begin repeat(n) @(negedge clk); #1; end endtask
task check; input ok; input [799:0] msg;
begin if(ok!==1'b1) begin errors=errors+1; $display("FAIL %0s",msg); end
else $display("PASS %0s",msg); end endtask
task nextkey; begin k1=0;tick(30);k1=1;tick(120);end endtask
task shortkey; begin k2=0;tick(40);k2=1;tick(30);end endtask
initial begin
 force dut.parser_success=parser_done; force dut.parser_error=1'b0; force dut.sd_init_done=init_ok; force dut.bmp_ready=ready;
 force dut.scan_done=scanned; force dut.scan_found_valid=found;
 force dut.scan_found_sector=sector;
 tick(5);rst=0;init_ok=1;tick(8);
 for(i=0;i<4;i=i+1) begin sector=100+i*2000;found=1;tick(1);found=0;tick(1);end
 scanned=1;tick(8);check(!dut.source_done_seen,"initial ready is not completion");
 tick(100);check(code==1,"first frame");
 nextkey;check(code==2,"next");
 hold_reader=1; active_buf=0; tick(5); k1=0;tick(30);k1=1;tick(30);
 check(!dut.load_busy && dut.next_req_pending,"old read buffer blocks new write");
 hold_reader=0;tick(150);check(code==3,"read retirement releases pending write");
 nextkey;nextkey;nextkey;check(code==2,"next wraps after retirement");
 k2=0;tick(1200);k2=1;tick(50);check(code==1&&!dut.auto_play_en,"long previous without auto toggle");
 shortkey;monitor_auto=1;tick(9200);monitor_auto=0;
 check(commits>=3,"multiple automatic commits with exact 3000-cycle dwell");
 shortkey;tick(120);check(!dut.auto_play_en&&!dut.load_busy,"stop discards prefetch");
 stalled=1;nextkey;tick(1100);
 check(dut.load_error&&dut.degraded&&!dut.load_busy&&dut.scan_complete&&!scanned,"timeout retains catalog");
 stalled=0;nextkey;check(!dut.load_error&&!dut.load_busy,"next recovers after abort");
 // A fully prefetched frame must wait despite timeout being shorter than dwell.
 shortkey;tick(1000);check(!dut.load_error&&dut.source_done_seen&&dut.write_done_seen,"prefetch dwell is not timeout");
 tick(2200);check(!dut.load_error,"auto after recovery");
 if(errors==0)$display("RECOVERY_PASS");else $display("RECOVERY_FAIL %0d",errors);
 $finish;
end
initial begin #300000; $fatal(1,"watchdog");end
endmodule