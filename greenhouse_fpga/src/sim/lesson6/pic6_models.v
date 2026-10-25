`timescale 1ns/1ps
// Behavioral storage only; real BMP/parser/frame state machines are in the DUT.
module fifo_model(input clkr,clkw,rst,we,re,input [31:0] di,
 output empty_flag,full_flag,output [8:0] wrusedw,rdusedw,output reg [31:0] dout);
reg [31:0] ram[0:511]; integer wp=0,rp=0;
assign empty_flag=wp==rp; assign full_flag=wp-rp>=512;
assign wrusedw=wp-rp; assign rdusedw=wp-rp;
always @(posedge clkw or posedge rst)
 if(rst) wp<=0; else if(we) begin ram[wp%512]<=di; wp<=wp+1; end
always @(posedge clkr or posedge rst)
 if(rst) begin rp<=0;dout<=0;end else if(re) begin dout<=ram[rp%512];rp<=rp+1;end
endmodule
module wfifo_32_32_512(input clkr,clkw,rst,we,re,input [31:0] di, output empty_flag,full_flag,output [8:0] wrusedw,rdusedw,output [31:0] dout);
fifo_model m(.*);
endmodule
module rfifo_32_32_512(input clkr,clkw,rst,we,re,input [31:0] di, output empty_flag,full_flag,output [8:0] wrusedw,rdusedw,output [31:0] dout);
fifo_model m(.*);
endmodule
// Sparse FAT32 card: data clusters beyond 64 MiB; files and root are fragmented.
module sd_card_top(input clk,rst,input SD_MISO,output SD_nCS,SD_DCLK,SD_MOSI,
 output reg sd_init_done,input sd_sec_read,input [31:0] sd_sec_read_addr,
 output reg [7:0] sd_sec_read_data,output reg sd_sec_read_data_valid,sd_sec_read_end,
 input sd_sec_write,input [31:0] sd_sec_write_addr,input [7:0] sd_sec_write_data,
 output sd_sec_write_data_req,sd_sec_write_end);
assign SD_nCS=1;assign SD_DCLK=0;assign SD_MOSI=1;assign sd_sec_write_data_req=0;assign sd_sec_write_end=0;
integer superfloppy=0,mbr_slot=0,spc=2,active_fat=0,bad_bpb=0;
reg [5:0] missing=0;integer short_file=0,chain_mode=0,chain_file=2;
integer fault=0,fault_file=2,failures_left=0,attempts=0,reads=0;
integer state=0,idx=0,delay_count=0,sector=0;reg inject=0;
function integer part;begin part=superfloppy?0:2048;end endfunction
function integer data_base;begin data_base=part()+1232;end endfunction
function integer first_cluster(input integer id);begin first_cluster=66000+(id-1)*100;end endfunction
function integer second_cluster(input integer id);begin second_cluster=first_cluster(id)+id*10;end endfunction
function integer first_lba(input integer id);begin first_lba=data_base()+(first_cluster(id)-2)*spc;end endfunction
function integer fat_value(input integer cluster);
 integer id,seg;begin
 fat_value=0;
 if(cluster==2)fat_value=9;
 if(cluster==9)fat_value=32'h0fffffff;
 for(id=1;id<=6;id=id+1)begin
 if(cluster==first_cluster(id))begin
 fat_value=spc>=4?32'h0fffffff:second_cluster(id);
 if(id==chain_file)case(chain_mode)
 1:fat_value=32'h0fffffff;2:fat_value=cluster;3:fat_value=32'h0ffffff7;4:fat_value=80000;
 endcase
 end
 if(spc==1)for(seg=1;seg<4;seg=seg+1)if(cluster==first_cluster(id)+id*10*seg)fat_value=seg==3?32'h0fffffff:first_cluster(id)+id*10*(seg+1);
 if(cluster==second_cluster(id))begin if(spc!=1)fat_value=32'h0fffffff;if(id==chain_file && chain_mode==5)fat_value=first_cluster(id);end
 end
 end
endfunction
function [7:0] data_byte(input integer at,input integer lba);
 integer v,k,id,offset,entry,sub,root_second,delta,cluster,whichfat,seg;
 begin
 data_byte=0;v=0;root_second=data_base()+7*spc;
 if(!superfloppy && lba==0)begin
 if(at==510)data_byte=8'h55;else if(at==511)data_byte=8'haa;
 else if(at==450+16*mbr_slot)data_byte=8'h0c;
 else if(at>=454+16*mbr_slot && at<458+16*mbr_slot)data_byte=(2048 >> (8*(at-454-16*mbr_slot)));
 else if(at>=458+16*mbr_slot && at<462+16*mbr_slot)data_byte=((1232+70000*spc) >> (8*(at-458-16*mbr_slot)));
 end else if(lba==part())begin
 case(at)
 0:data_byte=8'heb;11:data_byte=0;12:data_byte=bad_bpb==1?4:2;
 13:data_byte=bad_bpb==2?3:spc;14:data_byte=32;16:data_byte=2;
 32,33,34,35:begin v=bad_bpb==3?16:(1232+70000*spc);data_byte=v>>(8*(at-32));end
 36,37,38,39:begin v=bad_bpb==4?1:600;data_byte=v>>(8*(at-36));end
 40:data_byte=active_fat?8'h81:0;
 44:data_byte=2;510:data_byte=bad_bpb==5?0:8'h55;511:data_byte=8'haa;
 endcase
 end else if(lba>=part()+32 && lba<part()+1232)begin
 whichfat=(lba-part()-32)/600;
 cluster=((lba-part()-32)%600)*128+at/4;
 v=fat_value(cluster);if(active_fat && whichfat==0)v=0;
 data_byte=v>>(8*(at%4));
 end else if(lba>=data_base() && lba<data_base()+spc)begin
 data_byte=(at%32==0)?8'he5:0; // force root chain traversal
 end else if(lba>=root_second && lba<root_second+spc)begin
 entry=at/32;sub=at%32;
 case(entry)3:id=4;4:id=2;5:id=1;6:id=3;7:id=5;8:id=6;default:id=0;endcase
 if(id==0)begin
 if(entry<3)begin if(sub==0)data_byte=entry==2?8'he5:"X";if(sub==11)data_byte=entry==1?8'h0f:8'h20;end
 end else if(missing[id-1])begin if(sub==0)data_byte=8'he5;end
 else begin
 case(sub)
 0:data_byte="P";1:data_byte="I";2:data_byte="C";3:data_byte="0"+id;
 4,5,6,7:data_byte=" ";8:data_byte="B";9:data_byte="M";10:data_byte="P";
 11:data_byte=id==1?8'h21:8'h20;
 20:data_byte=first_cluster(id)>>16;21:data_byte=first_cluster(id)>>24;
 26:data_byte=first_cluster(id);27:data_byte=first_cluster(id)>>8;
 28,29,30,31:begin v=short_file==id?100:1590;data_byte=v>>(8*(sub-28));end
 endcase
 end
 end else begin
 for(id=1;id<=6;id=id+1)begin
 offset=-1;
 if(lba>=first_lba(id) && lba<first_lba(id)+spc)offset=(lba-first_lba(id))*512+at;
 for(seg=1;seg<4;seg=seg+1)begin delta=data_base()+(first_cluster(id)+id*10*seg-2)*spc;
 if(lba>=delta && lba<delta+spc)offset=seg*spc*512+(lba-delta)*512+at;end
 if(offset>=0)begin
 data_byte=offset<54?0:(((offset-54)/3)%251+id);
 case(offset)
 0:data_byte="B";1:data_byte="M";2:data_byte=8'h36;3:data_byte=6;
 10:data_byte=54;14:data_byte=40;18:data_byte=16;22:data_byte=32;26:data_byte=1;28:data_byte=24;
 endcase
 end
 end
 end
 end
endfunction
initial begin sd_init_done=0;sd_sec_read_data_valid=0;sd_sec_read_end=0;sd_sec_read_data=0;end
always @(posedge clk)begin
 sd_sec_read_data_valid<=0;sd_sec_read_end<=0;
 if(rst)begin state<=0;sd_init_done<=0;delay_count<=0;end
 else begin
 sd_init_done<=1;
 case(state)
 0:if(sd_sec_read)begin
 sector<=sd_sec_read_addr;idx<=0;delay_count<=0;state<=1;reads<=reads+1;
 inject<=fault!=0 && failures_left!=0 && sd_sec_read_addr==first_lba(fault_file);
 if(fault!=0 && failures_left!=0 && sd_sec_read_addr==first_lba(fault_file))begin failures_left<=failures_left-1;attempts<=attempts+1;end
 end
 1:if(inject && fault==2 && idx==100)begin end
 else if(delay_count==3)begin
 delay_count<=0;
 if(idx==512 || (inject && fault==3 && idx==120))begin sd_sec_read_end<=1;state<=2;end
 else begin sd_sec_read_data<=(inject && fault==1 && idx==28)?8'd16:data_byte(idx,sector);sd_sec_read_data_valid<=1;idx<=idx+1;end
 end else delay_count<=delay_count+1;
 2:if(!sd_sec_read)state<=0;
 endcase
 end
end
endmodule