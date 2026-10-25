`timescale 1ns/1ps
module tb_stability;
reg sdclk=0,memclk=0,pixclk=0,rst=1,k1=1,k2=1;
always #5 sdclk=~sdclk; always #10 memclk=~memclk; always #20 pixclk=~pixclk;
wire wr_req,wr_ack,we,finish,active,valid;wire [31:0] wd;wire [1:0] wb,db;wire [3:0] code;
reg finish_toggle=0;always @(posedge memclk) if(rst)finish_toggle<=0;else if(finish)finish_toggle<=~finish_toggle;
sd_card_bmp #(.USE_FAT32(0),.CLK_FREQ_HZ(1000),.WAIT_READ_ACK(1),.AUTO_PLAY_MS(3000),.LOAD_TIMEOUT_MS(10000),.SD_READ_TIMEOUT_MS(5000),.SCAN_MAX_SECTOR(8)) ctrl(
.clk(sdclk),.rst(rst),.startup_ready(1'b1),.key_next(k1),.key_auto(k2),.bmp_width(16'd16),.bmp_height(16'd4),.display_valid(valid),.state_code(code),
.read_active_buf(active),.write_finish_toggle(finish_toggle),.write_buf_idx(wb),.disp_buf_idx(db),.write_req(wr_req),.write_req_ack(wr_ack),.write_en(we),.write_data(wd),.SD_MISO(1'b1));
wire rd_ack,are,awe;wire [20:0] ra,wa;wire [31:0] awd,rd;
reg rr=0;reg ren=0;integer pcnt=0;
// Periodic video frame requests, real request/ack handshake, active pixels.
always @(posedge pixclk) begin
 if(rst) begin pcnt<=0;rr<=0;ren<=0;end
 else begin
 pcnt<=pcnt==399 ? 0 : pcnt+1;
 if(pcnt==0)rr<=1;else if(rd_ack)rr<=0;
 ren<=pcnt>=100 && pcnt<164;
 end
end
reg [31:0] ram[0:127];reg are_d=0;reg [20:0] ra_d=0;reg [31:0] memdata=0;
// Registered SDRAM-like return latency; frame readers/writers themselves are real.
always @(posedge memclk) begin
 are_d<=are;ra_d<=ra;
 if(are_d)memdata<=ram[ra_d%128];
 if(awe)ram[wa%128]<=awd;
end
reg are_d2=0;always @(posedge memclk)are_d2<=are_d;
frame_read_write #(.BURST_SIZE(16),.FRAME_WIDTH(16),.FRAME_HEIGHT(4)) fb(
.rst(rst),.mem_clk(memclk),.read_active_buf(active),.Sdr_init_done(!rst),.Sdr_init_ref_vld(1'b0),.Sdr_busy(1'b0),
.App_rd_en(are),.App_rd_addr(ra),.Sdr_rd_en(are_d2),.Sdr_rd_dout(memdata),.App_wr_en(awe),.App_wr_addr(wa),.App_wr_din(awd),.App_wr_dm(),
.read_clk(pixclk),.read_req(rr),.read_req_ack(rd_ack),.read_finish(),.read_addr_0(21'd0),.read_addr_1(21'd64),.read_addr_2(21'd0),.read_addr_3(21'd0),.read_addr_index(db),.read_len(21'd64),.read_en(ren),.read_data(rd),
.write_clk(sdclk),.write_req(wr_req),.write_req_ack(wr_ack),.write_finish(finish),.write_addr_0(21'd0),.write_addr_1(21'd64),.write_addr_2(21'd0),.write_addr_3(21'd0),.write_addr_index(wb),.write_len(21'd64),.write_en(we),.write_data(wd));
integer errors=0,commits=0,logfd,cyc=0,last_cycle=0,i,j;reg [3:0] oldcode=0;reg monitor=0;
task check(input ok,input [511:0] msg);begin if(ok!==1'b1)begin errors=errors+1;$fdisplay(logfd,"FAIL %0t %0s",$time,msg);$fflush(logfd);end end endtask
always @(negedge sdclk)if(!rst)begin
 cyc=cyc+1;
 if(code!=oldcode && valid)begin
 commits=commits+1;
 if(monitor)begin check(code==(oldcode==4?1:oldcode+1),"four-image ordering including third/fourth");check(cyc-last_cycle>=3000,"minimum dwell");end
 last_cycle=cyc;oldcode=code;
 $fdisplay(logfd,"commit=%0d image=%0d bank=%0d reader=%0d",commits,code,db,active);$fflush(logfd);
 end
end
task next_key;begin k1=0;repeat(30)@(negedge sdclk);k1=1;repeat(30)@(negedge sdclk);end endtask
task await_image(input [3:0] expected);integer n;begin n=0;while(code!=expected && n<15000)begin @(negedge sdclk);n=n+1;end if(code!=expected) $fdisplay(logfd,"DEBUG scan=%0d load=%b parser=%0d srcdone=%b wrdone=%b wrstate=%0d burst=%0d count=%0d used=%0d readstate=%0d into=%b rbusy=%b usedport=%b len=%0d",ctrl.img_found_count,ctrl.load_busy,ctrl.legacy_parser.bmp_read_m0.state,ctrl.source_done_seen,ctrl.write_done_seen,fb.frame_fifo_write_m0.state,fb.frame_fifo_write_m0.burst_cnt,fb.frame_fifo_write_m0.write_cnt,fb.rdusedw,fb.frame_fifo_read_m0.state,fb.frame_fifo_write_m0.into_burst,fb.App_rd_busy,fb.frame_fifo_write_m0.rdusedw,fb.frame_fifo_write_m0.write_len_latch); check(code==expected,"manual image completed");end endtask
integer attempts_before,old_image,old_bank;
task restart;begin rst=1;k1=1;k2=1;ctrl.sd_card_top_m0.fault=0;ctrl.sd_card_top_m0.failures_left=0;repeat(10)@(negedge sdclk);rst=0;await_image(1);end endtask
task inject_fault(input integer kind,input integer count,input integer sec);begin ctrl.sd_card_top_m0.fault=kind;ctrl.sd_card_top_m0.failures_left=count;ctrl.sd_card_top_m0.bad_sector=sec;end endtask
task short_key;begin k2=0;repeat(30)@(negedge sdclk);k2=1;repeat(30)@(negedge sdclk);end endtask
initial begin
 logfd=$fopen("assertions.log","w");restart();
 // Bad header after cataloguing: exactly one retry and no premature commit.
 attempts_before=ctrl.sd_card_top_m0.attempts;inject_fault(1,1,1);next_key();
 repeat(2300)@(negedge sdclk);check(code==1 && valid,"bad header retains displayed frame");
 await_image(2);check(ctrl.sd_card_top_m0.attempts-attempts_before==1 && ctrl.error_code==1,"transient header error recovered");
 // Persistent invalid header: two attempts, manual degradation, explicit recovery.
 inject_fault(1,99,2);attempts_before=ctrl.sd_card_top_m0.attempts;next_key();repeat(9500)@(negedge sdclk);
 check(code==2 && valid && ctrl.degraded && !ctrl.load_busy,"manual failed frame preserves last good display");
 check(ctrl.sd_card_top_m0.attempts-attempts_before==2,"one retry only");
 inject_fault(0,0,2);next_key();await_image(3);check(!ctrl.degraded,"KEY1 recovers after manual degradation");
 // Force a partial pixel sector then recover through the real frame writer.
 restart();wait(ctrl.bmp_ready);inject_fault(0,0,1);next_key();
 wait(ctrl.legacy_parser.bmp_read_m0.state==3);inject_fault(3,1,1);
 await_image(2);check(ctrl.error_code==3 && !ctrl.load_error,"short data sector retries with FIFO reset");
 // Stall after partial data; transport reset must not clear display/catalog.
 restart();next_key();wait(ctrl.legacy_parser.bmp_read_m0.state==3);inject_fault(2,1,1);
 repeat(5500)@(negedge sdclk);check(code==1 && valid && ctrl.scan_complete,"timeout preserves last good frame and catalog");
 await_image(2);check(ctrl.error_code==2 && !ctrl.load_error,"sector timeout recovers after transport reset");
 // Auto playback skips one persistently bad image and continues.
 restart();inject_fault(1,99,1);attempts_before=ctrl.sd_card_top_m0.attempts;short_key();
 await_image(3);check(ctrl.bad_mask[1] && ctrl.auto_play_en,"auto skips bad image after bounded retry");
 check(ctrl.sd_card_top_m0.attempts-attempts_before==2,"auto attempts bad image twice");
 await_image(4);await_image(1);await_image(3);
 // Long hold generates only one previous event, without toggling autoplay.
 inject_fault(0,0,1);short_key();repeat(5000)@(negedge sdclk);k2=0;repeat(3500)@(negedge sdclk);k2=1;repeat(6000)@(negedge sdclk);
 check(code==2 && !ctrl.auto_play_en,"long press selects previous image once");
 restart();inject_fault(1,99,-1);short_key();repeat(25000)@(negedge sdclk);
 check(ctrl.degraded && !ctrl.auto_play_en && !ctrl.retry_pending && !ctrl.load_busy && code==1 && valid,"all bad candidates stop after bounded attempts while retaining display");
 inject_fault(0,0,0);next_key();await_image(2);check(!ctrl.degraded,"KEY1 recovery after all candidates failed");
 // No valid catalog and a repeatedly stalled scan must also be recoverable.
 rst=1;repeat(10)@(negedge sdclk);inject_fault(1,99,-1);rst=0;repeat(20000)@(negedge sdclk);
 check(ctrl.degraded && ctrl.img_found_count==0 && !valid,"all invalid headers yield a bounded empty catalog");
 inject_fault(0,0,0);next_key();await_image(1);
 rst=1;repeat(10)@(negedge sdclk);inject_fault(2,99,-1);attempts_before=ctrl.sd_card_top_m0.attempts;rst=0;repeat(12000)@(negedge sdclk);
 check(ctrl.degraded && ctrl.scan_blocked && ctrl.error_code==2 && ctrl.sd_card_top_m0.attempts-attempts_before==2,"scan timeout retries only once");
 inject_fault(0,0,0);next_key();await_image(1);
 rst=1;repeat(10)@(negedge sdclk);force ctrl.sd_init_done=1'b0;rst=0;repeat(11000)@(negedge sdclk);
 check(ctrl.degraded && ctrl.error_code==2 && !valid,"missing card initialization times out");
 release ctrl.sd_init_done;next_key();await_image(1);
 $fdisplay(logfd,"RESULT errors=%0d",errors);$fclose(logfd);$finish;
end
initial begin #5000000;errors=errors+1;$fdisplay(logfd,"FAIL global watchdog");$finish;end
endmodule