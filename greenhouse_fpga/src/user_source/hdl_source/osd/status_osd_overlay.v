// Frame-blank snapshots converted by ONE serial double-dabble converter.
module status_osd_overlay(input clk,rst,convert_start,input [575:0] numbers,
 input [1:0] page,zone,input [4:0] field,input [3:0] sim_field,input auto_run,media_valid,
 input [7:0] states,input [9:0] x,y,input de,
 output reg hit,output reg [23:0] rgb,output reg ready);
 reg [15:0] bcd[0:35];reg busy;reg [5:0] index;reg [4:0] bits_left;
 reg [15:0] binary,bcd_work;reg [15:0] adjusted;integer n;
 always @*begin adjusted=bcd_work;for(n=0;n<4;n=n+1)if(bcd_work[n*4+:4]>=5)adjusted[n*4+:4]=bcd_work[n*4+:4]+4'd3;end
 always @(posedge clk or posedge rst)begin
 if(rst)begin busy<=0;index<=0;bits_left<=0;binary<=0;bcd_work<=0;ready<=0;end
 else if(convert_start)begin busy<=1;index<=0;bits_left<=16;binary<=numbers[15:0];bcd_work<=0;end
 else if(busy)begin
 binary<=binary<<1;bcd_work<={adjusted[14:0],binary[15]};bits_left<=bits_left-1'b1;
 if(bits_left==1)begin bcd[index]<={adjusted[14:0],binary[15]};bcd_work<=0;bits_left<=16;
 if(index==35)begin busy<=0;ready<=1;end
 else begin index<=index+1'b1;binary<=numbers[(index+1'b1)*16+:16];end
 end end end
 function [34:0] font;input [7:0] ch;begin case(ch)
"-":font=35'b00000000000000011111000000000000000;
"%":font=35'b11001110100001000100010001011010011;
"/":font=35'b00001000100001000100010000100010000;
":":font=35'b00000001000010000000001000010000000;
"+":font=35'b00000001000010011111001000010000000;
"0":font=35'b01110100011001110101110011000101110;
"1":font=35'b00100011000010000100001000010001110;
"2":font=35'b01110100010000100010001000100011111;
"3":font=35'b11110000010000101110000010000111110;
"4":font=35'b00010001100101010010111110001000010;
"5":font=35'b11111100001000011110000010000111110;
"6":font=35'b01110100001000011110100011000101110;
"7":font=35'b11111000010001000100010000100001000;
"8":font=35'b01110100011000101110100011000101110;
"9":font=35'b01110100011000101111000010000101110;
"A":font=35'b01110100011000111111100011000110001;
"B":font=35'b11110100011000111110100011000111110;
"C":font=35'b01111100001000010000100001000001111;
"D":font=35'b11110100011000110001100011000111110;
"E":font=35'b11111100001000011110100001000011111;
"F":font=35'b11111100001000011110100001000010000;
"G":font=35'b01111100001000010111100011000101111;
"H":font=35'b10001100011000111111100011000110001;
"I":font=35'b01110001000010000100001000010001110;
"J":font=35'b00111000100001000010100101001001100;
"K":font=35'b10001100101010011000101001001010001;
"L":font=35'b10000100001000010000100001000011111;
"M":font=35'b10001110111010110101100011000110001;
"N":font=35'b10001110011010110011100011000110001;
"O":font=35'b01110100011000110001100011000101110;
"P":font=35'b11110100011000111110100001000010000;
"Q":font=35'b01110100011000110001101011001001101;
"R":font=35'b11110100011000111110101001001010001;
"S":font=35'b01111100001000001110000010000111110;
"T":font=35'b11111001000010000100001000010000100;
"U":font=35'b10001100011000110001100011000101110;
"V":font=35'b10001100011000110001100010101000100;
"W":font=35'b10001100011000110101101011101110001;
"X":font=35'b10001100010101000100010101000110001;
"Y":font=35'b10001100010101000100001000010000100;
"Z":font=35'b11111000010001000100010001000011111;
 default:font=0;endcase end endfunction
 function [7:0] letter;input [511:0] text;input [6:0] col;begin letter=col<64?text[(63-col)*8+:8]:8'd32;end endfunction
localparam [511:0] BAD="ALARM                                                           ";
localparam [511:0] AUTO1="AUTO ON  - HOLD KEY1: MONITOR / LIMITS / SIMULATION             ";
localparam [511:0] LEGEND="TREND: CYAN TEMP / YELLOW HUM / MAGENTA LIGHT                   ";
localparam [511:0] AUTO0="AUTO OFF - HOLD KEY1: MONITOR / LIMITS / SIMULATION             ";
localparam [511:0] HELP0="KEY1 NEXT ZONE/IMAGE   KEY2 AUTO ON/OFF                         ";
localparam [511:0] HELP1="KEY1 NEXT FIELD   HOLD KEY1 NEXT PAGE                           ";
localparam [511:0] WARN="WARNING                                                         ";
localparam [511:0] HELP2="KEY1 NEXT VALUE   HOLD KEY1 MONITOR                             ";
localparam [511:0] TITLE0="GREENHOUSE MONITOR - FPGA INTERNAL SIMULATION                   ";
localparam [511:0] COL0="ZONE  TEMP C    HUM %    LIGHT LUX      STATUS                  ";
localparam [511:0] TITLE1="ALARM THRESHOLDS - KEY2 + / HOLD KEY2 -                         ";
localparam [511:0] OK="NORMAL                                                          ";
localparam [511:0] TITLE2="SIMULATED VALUES - KEY2 + / HOLD KEY2 -                         ";
localparam [511:0] MEDIA1="TF BACKGROUND READY - INTERNAL SIMULATION ACTIVE                ";
localparam [511:0] MEDIA0="TF BACKGROUND NOT READY - INTERNAL SIMULATION ACTIVE            ";
localparam [511:0] AXIS="NEWEST LEFT - 128 SAMPLES - 1 SEC SAMPLE                        ";
localparam [511:0] COL1="ZONE  T-LOW T-HIGH H-LOW H-HIGH L-LOW L-HIGH                    ";
 reg [7:0] ch;reg [23:0] color;reg panel,cursor;
 reg [5:0] glyph_index;reg glyph_valid,stroke;
 reg [7:0] ch_q;reg [23:0] color_q;reg [5:0] glyph_q;
 reg glyph_valid_q,stroke_q,panel_q,opaque_q,ready_q;
 wire [34:0] shape_q=font(ch_q);
 wire dot_q=stroke_q || (glyph_valid_q && shape_q[glyph_q]);
 integer col,rowz,j,pos,numidx,digit,dx,dy,ox,oy,sx,sy,legend_y;reg [1:0] state_value;reg wide;
 always @*begin
 dx=0;dy=0;ox=120;oy=88;sx=352;sy=116;legend_y=208;wide=0;
 col=(x-32)>>3;rowz=(y-80)>>5;ch=32;color=24'hffffff;panel=0;cursor=0;numidx=0;digit=0;pos=0;state_value=0;
 // Coordinates measured on each native 640x480 BMP. Monitor glyphs are transparent.
 if(page==0 && de)begin
 case(zone)
 0:begin ox=120;oy=88;sx=352;sy=116;legend_y=208;end
 1:begin ox=100;oy=92;sx=296;sy=126;legend_y=224;end
 2:begin ox=96;oy=90;sx=296;sy=118;legend_y=208;end
 3:begin ox=96;oy=88;sx=288;sy=94;legend_y=212;end
 endcase
 state_value=states[zone*2+:2];color=24'h124b38;
 for(j=0;j<3;j=j+1)begin
 pos=oy+(zone==0?34:zone==1?37:zone==2?30:34)*j;
 if(x>=ox && x<ox+128 && y>=pos && y<pos+14)begin
 panel=1;wide=1;dx=x-ox;dy=y-pos;col=dx>>4;numidx=zone*3+j;
 if(j<2)begin
 if(col==0)ch=bcd[numidx][7:4]==0?8'd32:8'd48+{4'd0,bcd[numidx][7:4]};
 if(col==1)ch=8'd48+{4'd0,bcd[numidx][3:0]};
 if(col==3)ch=j==0?8'd67:8'd37;
 if(bcd[numidx][11:8]!=0)begin
 if(col==0)ch=8'd48+{4'd0,bcd[numidx][11:8]};
 if(col==1)ch=8'd48+{4'd0,bcd[numidx][7:4]};
 if(col==2)ch=8'd48+{4'd0,bcd[numidx][3:0]};
 end
 end else begin
 if(col<4)begin digit=3-col;ch=8'd48+{4'd0,bcd[numidx][digit*4+:4]};end
 if(col==5)ch="L";if(col==6)ch="U";if(col==7)ch="X";
 end
 end
 end
 if(x>=sx && x<sx+224 && y>=sy && y<sy+14)begin
 panel=1;wide=1;dx=x-sx;dy=y-sy;col=dx>>4;
 ch=letter(state_value==2?BAD:state_value==1?WARN:OK,col);
 color=state_value==2?24'hdc2020:state_value==1?24'hb08000:24'h008040;
 end
 if(x>=72 && x<552 && y>=legend_y && y<legend_y+14)begin
 panel=1;dx=x-72;dy=y-legend_y;col=dx>>3;
 if(col<20)begin ch=letter("TEMP C                                                          ",col);color=24'h007e98;end
 else if(col<40)begin ch=letter("HUM %                                                           ",col-20);color=24'hb07800;end
 else begin ch=letter("LIGHT LUX                                                       ",col-40);color=24'h9830b0;end
 end
 if(x>=64 && x<576 && y>=440 && y<454)begin
 panel=1;dx=x-64;dy=y-440;col=dx>>3;color=24'h124b38;
 ch=letter(media_valid?(auto_run?"FPGA SIMULATION - AUTO ON                                       ":"FPGA SIMULATION - AUTO OFF                                      "):"TF NOT READY - FPGA SIMULATION                                  ",col);
 end
 end
 if(page==1 && de)begin
 // PIC5: six columns, four rows; preserve every printed heading and label.
 rowz=y<190?0:y<241?1:y<292?2:3;
 oy=144+rowz*51;
 for(j=0;j<6;j=j+1)begin
 ox=110+j*84;
 if(x>=ox && x<ox+72 && y>=oy && y<oy+40)begin
 panel=1;wide=1;dx=x-(ox+6);dy=y-(oy+13);col=dx>>4;
 numidx=12+rowz*6+j;digit=3-col;
 color=field==rowz*6+j?24'h007e98:24'h124b38;
 if(dx>=0 && dx<64 && dy>=0 && dy<14)ch=48+{4'd0,bcd[numidx][digit*4+:4]};
 if(field==rowz*6+j && (x==ox || x==ox+71 || y==oy || y==oy+39))cursor=1;
 end
 end
 end
 if(page==2 && de)begin
 // PIC6 native 640x480: only the four rows of data cells receive OSD.
 rowz=y<238?0:y<302?1:y<365?2:3;
 oy=rowz==0?185:rowz==1?249:rowz==2?313:376;
 state_value=states[rowz*2+:2];
 for(j=0;j<3;j=j+1)begin
 ox=j==0?166:j==1?284:399;
 if(x>=ox && x<ox+84 && y>=oy && y<oy+40)begin
 panel=1;wide=1;dx=x-(ox+10);dy=y-(oy+13);col=dx>>4;
 numidx=rowz*3+j;digit=3-col;
 color=sim_field==numidx?24'h007e98:24'h124b38;
 if(dx>=0 && dx<64 && dy>=0 && dy<14)ch=48+{4'd0,bcd[numidx][digit*4+:4]};
 if(sim_field==numidx && (x==ox || x==ox+83 || y==oy || y==oy+39))cursor=1;
 end
 end
 if(x>=516 && x<580 && y>=oy+13 && y<oy+27)begin
 panel=1;dx=x-516;dy=y-(oy+13);col=dx>>3;
 ch=letter(state_value==2?BAD:state_value==1?WARN:OK,col);
 color=state_value==2?24'hdc2020:state_value==1?24'hb08000:24'h008040;
 end
 end
 if(page==3 && de && x>=64 && x<576 && y>=440 && y<454)begin
 panel=1;dx=x-64;dy=y-440;col=dx>>3;color=24'hb08000;
 ch=letter("PAGE LOADING / CHECK TF CARD - HOLD KEY1 TO LEAVE                 ",col);
 end
 glyph_index=0;glyph_valid=0;stroke=0;
 // Non-negative local coordinates; bit slices avoid signed divide/modulo logic.
 if(dx>=0 && dy>=0 && dy<14)begin
 glyph_index=34-dy[3:1]*5-(wide?{1'b0,dx[3:1]}:{1'b0,dx[2:0]});
 glyph_valid=wide?dx[3:1]<5:dx[2:0]<5;
 end
 stroke=(page==1 || page==2) && cursor;
 end
 // Split coordinate/BCD selection from font lookup. Total text latency: 2 clocks.
 always @(posedge clk or posedge rst)begin
 if(rst)begin hit<=0;rgb<=0;ch_q<=32;color_q<=0;glyph_q<=0;glyph_valid_q<=0;stroke_q<=0;panel_q<=0;opaque_q<=0;ready_q<=0;end
 else begin
 ch_q<=ch;color_q<=color;glyph_q<=glyph_index;glyph_valid_q<=glyph_valid;stroke_q<=stroke;
 panel_q<=de && panel;opaque_q<=0;ready_q<=ready;
 hit<=panel_q && (opaque_q || (ready_q && dot_q));rgb<=ready_q && dot_q?color_q:24'h101824;
 end end
endmodule
