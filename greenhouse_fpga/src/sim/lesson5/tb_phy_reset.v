`timescale 1ns/1ps
// Functional ODDR model only. Device/electrical timing is covered by TD STA.
module EG_LOGIC_ODDR(input clk,rst,d0,d1,output reg q);
 always @(clk or posedge rst)if(rst)q<=0;else q<=clk?d0:d1;
endmodule
module tb_phy_reset;
reg pix=0,ser=0,rst=0,run_ser=1;reg [9:0] word=10'b1011000110;
always #20 pix=~pix;always #4 if(run_ser)ser=~ser;
wire q;integer logfd; integer errors=0,loads=0,serial_cycles=0,last_load=0,i;
lane_lvds_10_1 dut(.I_pixel_clk(pix),.I_serial_clk(ser),.I_rst(rst),.I_data_in(word),.O_serial_out(q));
task check(input good,input [799:0] msg);begin if(good!==1'b1)begin errors=errors+1;$display("FAIL %0t %0s",$time,msg);$fdisplay(logfd,"FAIL %0t %0s cycles=%0d last=%0d loads=%0d",$time,msg,serial_cycles,last_load,loads);end end endtask
always @(negedge dut.pixel_rst)if($time>0)check(pix===1'b1,"pixel reset release edge");
always @(negedge dut.serial_rst)if($time>0)check(ser===1'b1,"serial reset release edge");
reg [9:0] expected_shift;reg [1:0] expected_pair;
always @(posedge ser)begin
 if(dut.serial_rst)begin serial_cycles=0;last_load=0;loads=0;end
 else begin
 serial_cycles=serial_cycles+1;
 expected_shift=dut.S_load_en_2d?word:(dut.S_shift_data<<2);
 expected_pair=dut.S_shift_data[9:8];
 if(dut.S_load_en_2d)begin if(loads>0)check(serial_cycles-last_load==5,"five serial clocks per symbol");last_load=serial_cycles;loads=loads+1;end
 #1;check(dut.S_shift_data===expected_shift && dut.S_oddr_data===expected_pair,"serializer load/shift/order unchanged");
 end
end
initial begin
 logfd=$fopen("phy_assertions.log","w");#1;rst=1;#80;rst=0;repeat(80)@(negedge ser);check(loads>10,"serial data resumes after startup");
 for(i=0;i<10;i=i+1)begin #1;rst=1;#1;check(dut.S_shift_data===0 && dut.S_load_en_2d===0 && dut.S_odd_even_2d===0 && dut.S_oddr_data===0,"reset clears entire serializer history");#13;rst=0;repeat(80)@(negedge ser);check(loads>10,"serial recovery after repeated reset");end
 @(negedge ser);run_ser=0;#1;rst=1;#2;check(dut.serial_rst && dut.S_shift_data===0,"reset assertion works with stopped serial clock");rst=0;#150;check(dut.serial_rst,"serial reset waits for stopped clock");run_ser=1;repeat(80)@(negedge ser);check(loads>10,"serial clock return recovers stream");
 $display("PHY_RESET_RESULT errors=%0d",errors);$fdisplay(logfd,"PHY_RESET_RESULT errors=%0d",errors);$fclose(logfd);$finish;
end
initial begin #100000;errors=errors+1;$fatal(1,"watchdog");end
endmodule