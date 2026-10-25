`timescale 1ns/1ps
module tb_startup;
reg sdclk=0,memclk=0,pixclk=0,k1=1,k2=1;
reg ext_n=0,syslock=0,vidlock=0,memready=0,pixel_running=1;
wire rst,sd_rst,mem_rst,pix_rst,storage_ready,pll_reset;
lesson5_startup boot(.ext_rst_n(ext_n),.sys_locked(syslock),.video_locked(vidlock),
 .sd_clk(sdclk),.mem_clk(memclk),.pixel_clk(pixclk),.mem_init_done(memready),
 .rst_request(rst),.rst_sd(sd_rst),.rst_mem(mem_rst),.rst_pixel(pix_rst),
 .storage_ready(storage_ready),.pll_reset(pll_reset));
always #5 sdclk=~sdclk; always #10 memclk=~memclk; always #20 if(pixel_running)pixclk=~pixclk;
wire wr_req,wr_ack,we,finish,active,valid;wire [31:0] wd;wire [1:0] wb,db;wire [3:0] code;
reg finish_toggle=0;always @(posedge memclk) if(rst)finish_toggle<=0;else if(finish)finish_toggle<=~finish_toggle;
sd_card_bmp #(.USE_FAT32(0),.CLK_FREQ_HZ(1000),.WAIT_READ_ACK(1),.AUTO_PLAY_MS(3000),.LOAD_TIMEOUT_MS(10000),.SD_READ_TIMEOUT_MS(5000),.SCAN_MAX_SECTOR(8)) ctrl(
.clk(sdclk),.rst(sd_rst),.startup_ready(storage_ready),.key_next(k1),.key_auto(k2),.bmp_width(16'd16),.bmp_height(16'd4),.display_valid(valid),.state_code(code),
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
.rst(rst),.mem_clk(memclk),.read_active_buf(active),.Sdr_init_done(memready),.Sdr_init_ref_vld(1'b0),.Sdr_busy(1'b0),
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
integer commands=0,boots=0,ncmd;
always @(negedge sdclk) if(!rst)begin
 if(ctrl.scan_start_pulse)begin commands=commands+1;check(storage_ready,"scan waits for synchronized SDRAM init");end
 if(ctrl.load_start_pulse)check(storage_ready,"load waits for synchronized SDRAM init");
end
always @(negedge memclk)if(!rst && !memready)check(!are && !awe,"no SDRAM transactions before initialization");
always @(negedge sd_rst)if($time>0)check(sdclk===1'b1,"SD reset releases on its own rising edge");
always @(negedge mem_rst)if($time>0)check(memclk===1'b1,"memory reset releases on its own rising edge");
always @(negedge pix_rst)if($time>0)check(pixclk===1'b1,"pixel reset releases on its own rising edge");
task tick(input integer count);begin repeat(count)@(negedge sdclk);#1;end endtask
task finish_boot;begin
 ext_n=1;syslock=0;vidlock=0;memready=0;tick(17);
 check(rst && sd_rst && mem_rst && pix_rst && !pll_reset,"PLL acquisition is not held in PLL reset");
 syslock=1;tick(13);check(rst,"both PLLs required");vidlock=1;tick(20);
 check(!sd_rst && !mem_rst && !pix_rst && !storage_ready,"domains release before SDRAM readiness");
 ncmd=commands;tick(300);check(commands==ncmd && !ctrl.scan_kicked && !valid,"no early TF scan or display");
 memready=1;tick(1);check(!storage_ready,"memory ready passes two stages");tick(5);check(storage_ready,"memory ready synchronized");
 await_image(1);check(valid && ctrl.img_found_count==4,"first complete frame after ordered boot");boots=boots+1;
end endtask
initial begin
 logfd=$fopen("assertions.log","w");tick(10);finish_boot();
 // Repeated asynchronous button resets, including reset during a write.
 for(i=0;i<10;i=i+1)begin
 next_key();wait(we);tick(17+i);check(ctrl.load_busy,"reset injected during active pixel loading");#2;ext_n=0;memready=0;#1;
 check(rst && sd_rst && mem_rst && pix_rst && pll_reset,"button asserts all resets without waiting for clocks");
 check(!valid,"reset invalidates previous frame");tick(5);finish_boot();
 end
 // PLL loss while pixel clock is stopped; recovery waits for local clock edges.
 @(negedge pixclk);pixel_running=0;#3;vidlock=0;memready=0;#1;
 check(pix_rst && sd_rst && mem_rst && !pll_reset,"lock loss asserts reset without PLL feedback loop");
 tick(15);vidlock=1;tick(20);check(pix_rst && !sd_rst,"stopped domain cannot release reset");
 pixel_running=1;repeat(4)@(negedge pixclk);check(!pix_rst,"pixel reset releases after clock returns");
 memready=1;await_image(1);boots=boots+1;
 $fdisplay(logfd,"STARTUP_RESULT errors=%0d boots=%0d",errors,boots);$fclose(logfd);$finish;
end
initial begin #5000000;errors=errors+1;$fdisplay(logfd,"FAIL watchdog");$finish;end
endmodule