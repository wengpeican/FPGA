`timescale 1ns/1ps
module tb_lesson3;
reg clk=0; always #20 clk=~clk;
reg rst=1;
wire hs0,vs0,de0,hs,vs,de,re;
wire [23:0] rgb;
wire ah,av,ad,nla;
wire [9:0] x,y,c0,c1,c2;
wire [23:0] ar;
wire seq_err,overflow,contract_err,blip,tap;
wire signed [15:0] pcm;
reg source_clk=0; always #5 source_clk=~source_clk;
reg [1:0] source_id=0; wire [1:0] media;
lesson3_media_cdc cdc(.source_clk(source_clk),.source_rst(rst),.source_id(source_id),.pixel_clk(clk),.pixel_rst(rst),.frame_start(ad && x==0 && y==0),.media_id(media));
integer logfd; initial logfd=$fopen("assertions.log","w");
integer errors=0, ticks=0, samples=0, packets=0, acr=0, infos=0;
integer avis=0;
integer cycles=0, last_tick=0, gap=0, first_cycle=0, last_cycle=0;
integer blip_ticks=0, nonzero=0, frames=0;
reg prev_vs=1, locked=0, prev_de=0;
video_timing_data timing(.video_clk(clk),.rst(rst),.read_req(),.read_req_ack(1'b1),.hs(hs0),.vs(vs0),.de(de0));
video_delay delay_v(.video_clk(clk),.rst(rst),.read_en(re),.read_data(24'h123456),.hs(hs0),.vs(vs0),.de(de0),.hs_r(hs),.vs_r(vs),.de_r(de),.vout_data(rgb));
lesson3_video_align align_v(.clk(clk),.rst(rst),.hs(hs),.vs(vs),.de(de),.rgb(rgb),.hs_q(ah),.vs_q(av),.de_q(ad),.rgb_q(ar),.x(x),.y(y),.next_line_active(nla));
media_hdmi_audio_bridge dut(.pixel_clk(clk),.pixel_rst_n(~rst),.video_hsync(ah),.video_vsync(av),.video_de(ad),.video_x(x),.video_next_line_active(nla),.video_rgb(ar),.media_id(media),.volume(8'd128),.channel0_symbol(c0),.channel1_symbol(c1),.channel2_symbol(c2),.sequence_error(seq_err),.tone_overflow(overflow),.pcm_contract_error(contract_err),.blip_active(blip),.pcm_tap_valid(tap),.pcm_tap_left(pcm));
// Independent polynomial long division of the transmitted data followed by
// ECC. Generator in stream order: x^8+x^7+x^6+1 (9'h1c1).
function bch_ok;
 input [63:0] bits_on_wire;
 input integer count;
 reg [8:0] poly;
 integer k;
 begin
   poly=0;
   for(k=0;k<count;k=k+1) begin
     poly={poly[7:0],bits_on_wire[k]};
     if(poly[8]) poly=poly ^ 9'h1c1;
   end
   bch_ok=(poly==0);
 end
endfunction
integer subpacket;
task check;
 input condition; input [511:0] msg;
 begin if(condition !== 1'b1) begin errors=errors+1; if(errors<16) begin $fdisplay(logfd,"FAIL %0t: %0s x=%0d y=%0d de=%b rgb=%h",$time,msg,x,y,ad,ar); $fflush(logfd); end end end
endtask
always @(posedge clk) if(!rst) begin
 cycles=cycles+1;
 if (dut.u_tone.sample_tick) begin
   ticks=ticks+1;
   if(last_tick!=0) begin gap=cycles-last_tick; check(gap==520 || gap==521,"48k tick interval"); end
   last_tick=cycles;
   if(blip) blip_ticks=blip_ticks+1;
 end
 if(tap) begin samples=samples+1; if(pcm!=0) nonzero=nonzero+1; check(pcm<=6000 && pcm>=-6000,"half-volume amplitude"); end
 if(dut.u_symbol_core.packet_claim) begin
    check(bch_ok({32'd0,dut.u_symbol_core.packet_header_ecc,dut.u_symbol_core.packet_header},32),"header BCH syndrome");
    for(subpacket=0;subpacket<4;subpacket=subpacket+1)
      check(bch_ok({dut.u_symbol_core.packet_body_ecc[subpacket*8+:8],dut.u_symbol_core.packet_body[subpacket*56+:56]},64),"body BCH syndrome");
    case(dut.u_symbol_core.packet_header[7:0])
      8'h02: packets=packets+1;
      8'h01: begin
        acr=acr+1;
        check(dut.u_symbol_core.packet_body[55:0]===56'h001800a8610000,"ACR wire bytes SB0..6");
        check(dut.u_symbol_core.u_acr_packetizer.ACR_N==6144,"ACR N");
        check(dut.u_symbol_core.u_acr_packetizer.ACR_CTS==25000,"ACR CTS");
      end
      8'h84: infos=infos+1;
      8'h82: begin avis=avis+1; check(dut.u_symbol_core.packet_body[39:32]==1,"AVI VIC1" ); end
    endcase
 end
 if(prev_vs && !av && cycles>420000) begin locked=1; frames=frames+1; end
 prev_vs=av;
 if(locked) begin
    check(ad === (x<640 && y<480),"DE and coordinate alignment");
    if(ad) check(ar===24'h123456,"RGB pipeline alignment");
 end
 check(!seq_err && !overflow && !contract_err,"HDMI sequence/FIFO/PCM error");
end
initial begin
 repeat(8) @(negedge clk); rst=0;
 repeat(1250000) @(negedge clk);
 check(ticks==2400,"exact 48k average over 50ms");
 source_id=1;
 repeat(3) @(negedge clk); check(!blip,"no cue before image frame boundary");
 wait(blip); @(negedge clk); check(media==1,"image ID handshake and frame commit");
 repeat(2500100) @(negedge clk); check(!blip,"cue ends at 100ms");
 check(blip_ticks==4800,"cue has exactly 4800 samples");
 check(dut.u_tone.media_id_q==1,"new melody selected");
 check(dut.u_tone.melody_note_inc==9634,"A4 first note for picture2");
 check(samples>7190 && nonzero>5000,"PCM delivered continuously");
 check(packets>1700 && acr>100 && infos>5,"audio ACR InfoFrame packets sent");
 check(avis>5,"AVI sent each frame");
 check(frames>5,"multiple complete video frames");
 $fdisplay(logfd,"RESULT errors=%0d ticks=%0d samples=%0d audio_packets=%0d acr=%0d info=%0d",errors,ticks,samples,packets,acr,infos);
 $finish;
end
initial begin #200000000; $display("FAIL watchdog"); errors=errors+1; $finish; end
endmodule