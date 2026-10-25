`timescale 1ns/1ps
module tb_parser;
reg clk=0,rst=1,scan=0,start=0,abort_load=0,ack=0,dv=0,done=0;
reg [7:0] data=0,bytes[0:511];reg [15:0] w=3,h=2;
wire ready,req,sdreq,err,success,we,scan_done,found;wire [2:0] code;wire [31:0] addr;
integer errors=0,pixels=0,successes=0,failures=0,checks=0,i,n;reg [2:0] last_error;
always #5 clk=~clk;
bmp_read #(.CLK_FREQ_HZ(1000),.SD_READ_TIMEOUT_MS(1200)) dut(
.clk(clk),.rst(rst),.ready(ready),.scan_start(scan),.scan_start_sector(32'd0),.scan_max_sector(32'd10),.scan_target_count(3'd4),.scan_done(scan_done),.scan_found_valid(found),
.load_start(start),.load_abort(abort_load),.load_sector(32'd0),.sd_init_done(1'b1),.bmp_width(w),.bmp_height(h),.write_req(req),.write_req_ack(ack),
.sd_sec_read(sdreq),.sd_sec_read_addr(addr),.sd_sec_read_data(data),.sd_sec_read_data_valid(dv),.sd_sec_read_end(done),.bmp_data_wr_en(we),.bmp_error(code),.load_error(err),.load_success(success));
always @(negedge clk)begin if(we)pixels=pixels+1;if(success)successes=successes+1;if(err)begin failures=failures+1;last_error=code;end end
task tick(input integer c);begin repeat(c)@(negedge clk);#1;end endtask
task check(input good,input [799:0] msg);begin checks=checks+1;if(good!==1'b1)begin errors=errors+1;$display("FAIL %0s",msg);end end endtask
task reset_case;begin rst=1;dv=0;done=0;ack=0;start=0;scan=0;tick(4);rst=0;tick(4);pixels=0;successes=0;failures=0;last_error=0;for(i=0;i<512;i=i+1)bytes[i]=0;bytes[0]=66;bytes[1]=77;bytes[2]=78;bytes[10]=54;bytes[14]=40;bytes[18]=3;bytes[22]=2;bytes[26]=1;bytes[28]=24;end endtask
task begin_load;begin start=1;tick(1);start=0;tick(3);end endtask
task sector(input integer count);begin n=0;while(!sdreq && n<1500)begin tick(1);n=n+1;end check(sdreq,"sector requested");for(i=0;i<count;i=i+1)begin data=bytes[i];dv=1;tick(1);end dv=0;done=1;tick(1);done=0;tick(5);end endtask
task header_reject(input [2:0] expect_code);begin begin_load();sector(512);check(failures==1 && last_error==expect_code && !req && successes==0,"invalid header rejected without writer request");end endtask
initial begin
 reset_case();begin_load();sector(512);check(req,"valid padded BMP accepted");ack=1;tick(1);ack=0;sector(512);tick(8);check(successes==1 && pixels==6 && failures==0,"row padding and trailing sector bytes excluded");
 reset_case();bytes[0]=0;header_reject(1);
 reset_case();bytes[20]=1;header_reject(1); // full width, not only low16
 reset_case();bytes[25]=255;header_reject(1); // negative height
 reset_case();bytes[26]=2;header_reject(1);
 reset_case();bytes[28]=16;header_reject(1);
 reset_case();bytes[30]=1;header_reject(1);
 reset_case();bytes[14]=39;header_reject(1);
 reset_case();bytes[10]=53;header_reject(1);
 reset_case();bytes[14]=80;header_reject(1); // DIB overlaps pixels
 reset_case();bytes[2]=77;header_reject(3); // payload one byte short
 reset_case();bytes[5]=255;header_reject(1); // unbounded file size
 reset_case();begin_load();sector(511);check(last_error==3 && successes==0,"short header sector");
 reset_case();begin_load();tick(1250);check(last_error==2 && ready && !sdreq,"header timeout exits idle");
 reset_case();begin_load();sector(512);tick(1250);check(last_error==2 && ready && !req,"writer ack timeout");
 reset_case();begin_load();sector(512);ack=1;tick(1);ack=0;sector(100);check(last_error==3 && successes==0,"short pixel sector cannot commit");
 reset_case();begin_load();sector(512);ack=1;tick(1);ack=0;tick(1250);check(last_error==2 && successes==0,"pixel sector timeout");
 reset_case();scan=1;tick(1);scan=0;tick(1250);check(last_error==2 && ready,"scan sector timeout");
 reset_case();bytes[2]=0;bytes[3]=8;bytes[28]=16;scan=1;tick(1);scan=0;sector(512);tick(10);check(addr==4 && !found,"sane invalid BMP skips rounded file extent");
 reset_case();bytes[5]=255;scan=1;tick(1);scan=0;sector(512);tick(10);check(addr==1,"untrusted length advances only one sector");
 $display("PARSER_RESULT errors=%0d checks=%0d",errors,checks);$finish;
end
initial begin #2000000;errors=errors+1;$fatal(1,"watchdog");end
endmodule