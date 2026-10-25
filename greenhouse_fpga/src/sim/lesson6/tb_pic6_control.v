`timescale 1ns/1ps
module tb_pic6_control;
reg sdclk=0,memclk=0,pixclk=0,rst=1,k1=1,k2=1;
always #5 sdclk=~sdclk; always #10 memclk=~memclk; always #20 pixclk=~pixclk;
wire wr_req,wr_ack,we,finish,active,valid;wire [31:0] wd;wire [1:0] wb,db;wire [3:0] code;
reg finish_toggle=0;always @(posedge memclk) if(rst)finish_toggle<=0;else if(finish)finish_toggle<=~finish_toggle;
reg settings=0,pause_media=0,table_request=0;
sd_card_bmp #(.ENABLE_SETTINGS(1),.USE_FAT32(1),.CLK_FREQ_HZ(10000),.WAIT_READ_ACK(1),.AUTO_PLAY_MS(3000),.LOAD_TIMEOUT_MS(10000),.SD_READ_TIMEOUT_MS(500),.SCAN_MAX_SECTOR(8)) ctrl(
.table_request(table_request),.settings_request(settings),.media_pause(pause_media),.clk(sdclk),.rst(rst),.startup_ready(1'b1),.key_next(k1),.key_auto(k2),.bmp_width(16'd16),.bmp_height(16'd32),.display_valid(valid),.state_code(code),
.read_active_buf(active),.write_finish_toggle(finish_toggle),.write_buf_idx(wb),.disp_buf_idx(db),.write_req(wr_req),.write_req_ack(wr_ack),.write_en(we),.write_data(wd),.SD_MISO(1'b1));
wire rd_ack,are,awe;wire [20:0] ra,wa;wire [31:0] awd,rd;
reg rr=0;reg ren=0;integer pcnt=0;
// Periodic video frame requests, real request/ack handshake, active pixels.
always @(posedge pixclk) begin
 if(rst) begin pcnt<=0;rr<=0;ren<=0;end
 else begin
 pcnt<=pcnt==799 ? 0 : pcnt+1;
 if(pcnt==0)rr<=1;else if(rd_ack)rr<=0;
 ren<=pcnt>=100 && pcnt<612;
 end
end
reg [31:0] ram[0:1023];reg are_d=0;reg [20:0] ra_d=0;reg [20:0] wa_d=0;reg [31:0] memdata=0;
// FIFO data is registered at the request edge; sample after NBA using saved address.
// Read side models the SDRAM return latency; real frame state machines are used.
always @(posedge memclk) begin
 are_d<=are;ra_d<=ra;
 if(are_d)memdata<=ram[ra_d%1024];
 if(awe)begin #1; ram[wa_d%1024]<=awd;end
end
always @(posedge memclk)wa_d<=wa;
reg are_d2=0;always @(posedge memclk)are_d2<=are_d;
frame_read_write #(.BURST_SIZE(16),.FRAME_WIDTH(16),.FRAME_HEIGHT(32)) fb(
.rst(rst),.mem_clk(memclk),.read_active_buf(active),.Sdr_init_done(!rst),.Sdr_init_ref_vld(1'b0),.Sdr_busy(1'b0),
.App_rd_en(are),.App_rd_addr(ra),.Sdr_rd_en(are_d2),.Sdr_rd_dout(memdata),.App_wr_en(awe),.App_wr_addr(wa),.App_wr_din(awd),.App_wr_dm(),
.read_clk(pixclk),.read_req(rr),.read_req_ack(rd_ack),.read_finish(),.read_addr_0(21'd0),.read_addr_1(21'd512),.read_addr_2(21'd0),.read_addr_3(21'd0),.read_addr_index(db),.read_len(21'd512),.read_en(ren),.read_data(rd),
.write_clk(sdclk),.write_req(wr_req),.write_req_ack(wr_ack),.write_finish(finish),.write_addr_0(21'd0),.write_addr_1(21'd512),.write_addr_2(21'd0),.write_addr_3(21'd0),.write_addr_index(wb),.write_len(21'd512),.write_en(we),.write_data(wd));
integer errors=0,commits=0,logfd,cyc=0,last_cycle=0,i,j;reg [3:0] oldcode=0;reg monitor=0;
task check(input ok,input [511:0] msg);begin if(ok!==1'b1)begin errors=errors+1;$fdisplay(logfd,"FAIL %0t %0s",$time,msg);$fflush(logfd);end end endtask
always @(negedge sdclk)if(!rst)begin
 cyc=cyc+1;
 if(code!=oldcode && valid)begin
 commits=commits+1;
 if(monitor)begin check(code==(oldcode==4?1:oldcode+1),"four-image ordering including third/fourth");check(cyc-last_cycle>=30000,"minimum dwell");end
 last_cycle=cyc;oldcode=code;
 $fdisplay(logfd,"commit=%0d image=%0d bank=%0d reader=%0d",commits,code,db,active);$fflush(logfd);
 end
end
task next_key;begin k1=0;repeat(250)@(negedge sdclk);k1=1;repeat(250)@(negedge sdclk);end endtask
task await_image(input [3:0] expected);integer n;begin n=0;while(code!=expected && n<100000)begin @(negedge sdclk);n=n+1;end check(code==expected,"manual image completed");end endtask
integer attempts_before,reads_before,bank,n,pval;
task tick(input integer c);begin repeat(c)@(negedge sdclk);#1;end endtask
task short_key;begin k2=0;tick(250);k2=1;tick(250);end endtask
task image_pixels(input integer id);begin bank=db[0]*512;for(j=0;j<512;j=j+1)begin pval=((((31-j/16)*16+j%16)%251)+id)&255;check(ram[bank+j]==((pval<<24)|(pval<<16)|(pval<<8)|(id-1)),"RGB order, vertical flip and resource ID across fragmented clusters");end end endtask
task reset_card;begin monitor=0;rst=1;k1=1;k2=1;tick(12);rst=0;oldcode=0;end endtask
task defaults;begin ctrl.sd_card_top_m0.superfloppy=0;ctrl.sd_card_top_m0.mbr_slot=0;ctrl.sd_card_top_m0.spc=2;ctrl.sd_card_top_m0.active_fat=0;ctrl.sd_card_top_m0.bad_bpb=0;ctrl.sd_card_top_m0.missing=0;ctrl.sd_card_top_m0.short_file=0;ctrl.sd_card_top_m0.chain_mode=0;ctrl.sd_card_top_m0.fault=0;ctrl.sd_card_top_m0.failures_left=0;end endtask
task wait_degraded;begin n=0;while(!ctrl.degraded && n<120000)begin tick(1);n=n+1;end check(ctrl.degraded,"bounded degradation on invalid media");end endtask
`include "pic6_cases.vh"
endmodule
