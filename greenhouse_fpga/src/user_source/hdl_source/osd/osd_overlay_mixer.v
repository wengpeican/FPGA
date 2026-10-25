// RGB and the COMPLETE HDMI timing bundle have exactly three pixel clocks latency.
module osd_overlay_mixer #(parameter CLK_HZ=25000000, DISPLAY_CONTROLS=0)(
 input clk,rst,key1_n,key2_n,input [23:0] rgb_in,input hs,vs,de,next_line,
 input [9:0] x,y,input media_valid,input [2:0] media_zone,
 output reg [23:0] rgb_out,output reg hs_out,vs_out,de_out,next_line_out,output reg [9:0] x_out,
 output media_next_n,media_auto_n,output settings_request,media_pause,output table_request,input switch_request,output switch_black,output reg [1:0] audio_status,
 input [3:0] control_volume,control_brightness,control_contrast,
 input [1:0] control_selected,input control_show);
 reg [23:0] bg2;
 wire [23:0] adjusted_bg,hud_rgb;wire hud_hit;
 generate if(DISPLAY_CONTROLS)begin: controls
 video_display_adjust adjust(clk,rst,rgb_in,control_brightness,control_contrast,adjusted_bg);
 display_parameter_hud hud(clk,rst,control_show,control_selected,control_volume,
 control_brightness,control_contrast,x,y,de,hud_hit,hud_rgb);
 end else begin: legacy
 assign adjusted_bg=bg2;assign hud_hit=1'b0;assign hud_rgb=24'd0;
 end endgenerate
 wire frame_tick=x==0 && y==480;
 wire s1,l1,s2,l2;
 osd_button #(.CLK_HZ(CLK_HZ)) b1(clk,rst,key1_n,s1,l1);
 osd_button #(.CLK_HZ(CLK_HZ)) b2(clk,rst,key2_n,s2,l2);
 wire [1:0] requested_page,zone,display_page;wire [4:0] field;wire [3:0] sim_field;
 wire auto_run,inc,dec,media_next,media_auto,page_change,busy;
 reg [575:0] numbers;wire [7:0] frame_states;
 wire [383:0] thresholds;wire [191:0] values;wire data_valid;wire [7:0] states;
 wire [3:0] blink;wire [2:0] shade,page_shade,monitor_shade;
 wire page_busy,monitor_busy;
 assign busy=page_busy || monitor_busy;
 assign shade=monitor_shade>page_shade?monitor_shade:page_shade;
 ui_page_ctrl #(.CLK_HZ(CLK_HZ)) ui(clk,rst,frame_tick,s1,l1,s2,l2,busy,requested_page,zone,field,auto_run,thresholds,inc,dec,sim_field,media_next,media_auto,page_change);
 sim_sensor_data_gen #(.CLK_HZ(CLK_HZ)) sensor(clk,rst,requested_page==2,inc,dec,sim_field,values,data_valid);
 alarm_threshold_cmp alarm(clk,rst,numbers[191:0],numbers[575:192],states);
 assign frame_states=states;
 alarm_blink_ctrl #(.CLK_HZ(CLK_HZ)) blink_ctrl(clk,rst,states,blink);
 assign settings_request=requested_page==1;
 assign table_request=requested_page==2;
 assign media_pause=requested_page!=0;
 page_transition_ctrl transition(clk,rst,frame_tick,page_change,requested_page,display_page,page_busy,page_shade);
 // Pulse stretching lets the unchanged TF controller debounce these events.
 reg [31:0] next_count,auto_count;
 always @(posedge clk or posedge rst)if(rst)begin next_count<=0;auto_count<=0;end
 else begin
 if(media_next)next_count<=CLK_HZ/20;else if(next_count!=0)next_count<=next_count-1'b1;
 if(media_auto)auto_count<=CLK_HZ/20;else if(auto_count!=0)auto_count<=auto_count-1'b1;
 end
 assign media_next_n=next_count==0;assign media_auto_n=auto_count==0;
 reg [3:0] frame_blink;
 reg [1:0] frame_zone;reg [2:0] frame_resource;reg [4:0] frame_field;reg [3:0] frame_sim_field;
 // The buzzer follows the zone whose image is actually on screen.  Using
 // frame_zone here keeps the sound and the visible border on the same zone;
 // an off-screen red zone must not mask a green or yellow selected zone.
 wire [1:0] current_zone_status = frame_states[frame_zone*2+:2];
 always @(posedge clk or posedge rst)
 if(rst)audio_status<=0;else audio_status<=current_zone_status;
 monitor_transition_ctrl monitor_transition(clk,rst,frame_tick,switch_request,
 requested_page==0 && !page_busy,frame_resource,monitor_busy,switch_black,monitor_shade);
 // Never draw the settings table over a zone BMP while PIC5 is loading.
 wire [1:0] render_page=frame_resource==4 ? 2'd1 : frame_resource==5 ? 2'd2 : display_page!=0 ? 2'd3 : display_page;
 reg convert_delay;
 reg frame_auto,frame_media,convert;
 always @(posedge clk or posedge rst)begin
 if(rst)begin numbers<=0;frame_blink<=4'hf;frame_zone<=0;frame_resource<=0;frame_field<=0;frame_sim_field<=0;frame_auto<=0;frame_media<=0;convert<=0;convert_delay<=0;end
 else begin
 // First active pixel carries the resource ID of the actual displayed buffer.
 if(de && x==0 && y==0 && media_valid)begin frame_resource<=media_zone;if(media_zone<4)frame_zone<=media_zone[1:0];end
 convert_delay<=convert;if(convert_delay)frame_blink<=blink;
 convert<=frame_tick;if(frame_tick)begin numbers<={thresholds,values};if(!media_valid)frame_zone<=zone;frame_field<=field;frame_sim_field<=sim_field;frame_auto<=auto_run;frame_media<=media_valid;end end end
 // Sample on vertical blank after a data update; never alter history mid-frame.
 reg pending_sample;wire sample_now=frame_tick && pending_sample;
 always @(posedge clk or posedge rst)if(rst)pending_sample<=1;
 else if(data_valid)pending_sample<=1;else if(sample_now)pending_sample<=0;
 wire wave_hit,text_hit,text_ready;wire [23:0] wave_rgb,text_rgb;
 trend_waveform_draw wave(clk,rst,sample_now,frame_zone,values,x,y,de,wave_hit,wave_rgb);
 status_osd_overlay text_layer(clk,rst,convert,numbers,render_page,frame_zone,frame_field,frame_sim_field,frame_auto,frame_media,frame_states,x,y,de,text_hit,text_rgb,text_ready);
 reg [23:0] bg1;reg hs1,vs1,de1,nl1;reg [9:0] x1,y1;
 reg [23:0] wave_rgb2;reg hs2,vs2,de2,nl2,wave_hit2;reg [9:0] x2,y2;
 reg [23:0] mix;reg [1:0] st;reg border;
 reg [9:0] left_edge,right_edge,top_edge,bottom_edge;
 always @*begin
 mix=adjusted_bg;st=0;border=0;left_edge=320;right_edge=587;top_edge=82;bottom_edge=169;
 if(render_page==0 && wave_hit2)mix=wave_rgb2;
 if(text_hit)mix=text_rgb;
 if(render_page==0)begin
 case(frame_zone)
 0:begin left_edge=320;right_edge=587;top_edge=82;bottom_edge=169;end
 1:begin left_edge=264;right_edge=604;top_edge=116;bottom_edge=152;end
 2:begin left_edge=260;right_edge=592;top_edge=89;bottom_edge=161;end
 3:begin left_edge=254;right_edge=602;top_edge=81;bottom_edge=122;end
 endcase
 st=frame_states[frame_zone*2+:2];
 border=x2>=left_edge && x2<=right_edge && y2>=top_edge && y2<=bottom_edge &&
 (x2<=left_edge+1 || x2>=right_edge-1 || y2<=top_edge+1 || y2>=bottom_edge-1);
 if(border && frame_blink[frame_zone])mix=st==2?24'hdc2020:st==1?24'hb08000:24'h008040;
 end
 if(shade>=4)mix=0;else begin mix[23:16]=mix[23:16]>>shade;mix[15:8]=mix[15:8]>>shade;mix[7:0]=mix[7:0]>>shade;end
 if(hud_hit)mix=hud_rgb;
 if(!de2)mix=0;
 end
 always @(posedge clk or posedge rst)begin
 if(rst)begin bg1<=0;hs1<=1;vs1<=1;de1<=0;nl1<=0;x1<=0;y1<=0;bg2<=0;hs2<=1;vs2<=1;de2<=0;nl2<=0;x2<=0;y2<=0;wave_hit2<=0;wave_rgb2<=0;rgb_out<=0;hs_out<=1;vs_out<=1;de_out<=0;next_line_out<=0;x_out<=0;end
 else begin bg1<=rgb_in;hs1<=hs;vs1<=vs;de1<=de;nl1<=next_line;x1<=x;y1<=y;
 bg2<=bg1;hs2<=hs1;vs2<=vs1;de2<=de1;nl2<=nl1;x2<=x1;y2<=y1;wave_hit2<=wave_hit;wave_rgb2<=wave_rgb;
 rgb_out<=mix;hs_out<=hs2;vs_out<=vs2;de_out<=de2;next_line_out<=nl2;x_out<=x2;end end
endmodule
