`timescale 1ns/1ps
module tb_lesson2;
reg clk=0, rst=1, key1=1, key2=1, finish_toggle=0;
always #5 clk=~clk;
reg init_done=0, ready=1, scan_done=0, found=0;
reg [31:0] sector=0;
wire [3:0] number;
wire valid;
integer loads=0, before_loads, i;
sd_card_bmp #(.USE_FAT32(0),.CLK_FREQ_HZ(1000),.LONG_PRESS_MS(1000),.AUTO_PLAY_MS(3000)) dut (
 .clk(clk),.rst(rst),.startup_ready(1'b1),.key_next(key1),.key_auto(key2),
 .bmp_width(16'd640),.bmp_height(16'd480),.state_code(number),
 .display_valid(valid),.write_finish_toggle(finish_toggle),
 .write_req_ack(1'b0),.SD_MISO(1'b1));
always @(posedge clk) if(dut.load_start_pulse) loads=loads+1;
task cycles; input integer n; begin repeat(n) @(negedge clk); end endtask
task check; input ok; input [639:0] msg;
begin if(ok !== 1'b1) begin $display("FAIL: %0s time=%0t",msg,$time); $fatal(1); end
else $display("PASS: %0s",msg); end endtask
task boot; input integer n;
begin
 rst=1; init_done=0; scan_done=0; found=0; ready=1; key1=1; key2=1; finish_toggle=0;
 cycles(5); rst=0; cycles(5);
 check(number==0 && !valid,"no frame: number zero");
 init_done=1; cycles(5);
 for(i=0;i<n;i=i+1) begin sector=100+i*100; found=1; cycles(1); found=0; cycles(1); end
 scan_done=1; cycles(5);
end endtask
task finish; input integer expected;
begin
 check(dut.load_busy,"load in progress");
 finish_toggle=~finish_toggle; cycles(9);
 check(valid && number==expected && !dut.load_busy,"commit correct image number");
end endtask
task next_key; begin key1=0; cycles(30); key1=1; cycles(30); end endtask
task short_key; begin key2=0; cycles(40); key2=1; cycles(30); end endtask
initial begin
 $dumpfile("lesson2.vcd"); $dumpvars(0,tb_lesson2);
 // Controller-level stimulus: real lower RTL is compiled, but TF/BMP responses
 // are driven here. This is not a physical TF/SDRAM/HDMI simulation.
 force dut.sd_init_done=init_done;
 force dut.bmp_ready=ready;
 force dut.scan_done=scan_done;
 force dut.scan_found_valid=found;
 force dut.scan_found_sector=sector;
 force dut.scan_found_total=3'd0;
 force dut.bmp_data_wr_en=1'b0;
 boot(4); finish(1);
 next_key; check(number==1,"number stays old until write completion"); finish(2);
 next_key; finish(3); next_key; finish(4); next_key; finish(1);
 key1=0; cycles(3); key1=1; cycles(30);
 check(!dut.load_busy,"short bounce ignored");
 // Long KEY2: no short action at press; one previous request, wrap 1->4.
 key2=0; cycles(900);
 check(!dut.auto_play_en && !dut.load_busy,"long hold does not prematurely toggle auto");
 cycles(150); finish(4); before_loads=loads; cycles(1200);
 check(loads==before_loads && !dut.load_busy,"held key triggers only once");
 key2=1; cycles(30); check(!dut.auto_play_en,"long release does not toggle auto");
 // Busy previous request persists until current transfer is committed.
 next_key; ready=0; key2=0; cycles(1050);
 check(dut.prev_req_pending,"previous request retained while busy");
 key2=1; ready=1; finish_toggle=~finish_toggle; cycles(10);
 check(number==1 && dut.load_busy,"queued previous starts after current commit");
 finish(4);
 // Repeated next during busy is coalesced to one pending request.
 next_key; ready=0; next_key; next_key;
 finish_toggle=~finish_toggle; cycles(8); ready=1; cycles(6);
 check(number==1 && dut.load_busy,"busy next requests coalesced");
 finish(2); cycles(30); check(!dut.load_busy,"no extra queued next");
 // Auto: exactly 3000 eligible clock cycles between commit and next load request.
 short_key; check(dut.auto_play_en,"short release enables auto");
 cycles(2900); check(!dut.load_busy,"auto does not fire before configured delay");
 cycles(110); check(dut.load_busy,"auto fires after configured delay"); finish(3);
 short_key; check(!dut.auto_play_en,"short release disables auto");
 cycles(3100); check(!dut.load_busy,"auto remains stopped");
 // Count-limited wrap and no-image behavior.
 boot(1); finish(1); before_loads=loads;
 next_key; short_key; key2=0; cycles(1050); key2=1; cycles(30);
 check(number==1 && loads==before_loads && !dut.auto_play_en,"single image: no switching");
 boot(2); finish(1); key2=0; cycles(1050); key2=1; cycles(30); finish(2);
 boot(3); finish(1); key2=0; cycles(1050); key2=1; cycles(30); finish(3);
 boot(0); cycles(50);
 check(!valid && number==0 && !dut.load_busy,"zero images: no phantom load");
 $display("ALL LESSON2 TESTS PASSED"); $finish;
end
initial begin #1000000; $fatal(1,"watchdog timeout"); end
endmodule

