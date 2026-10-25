initial begin
logfd=$fopen("monitor_fade_assertions.log","w");defaults();reset_card();await_image(1);image_pixels(1);
check(!fade_busy,"boot image must not wait for transition");
for(i=0;i<4;i=i+1)begin next_key();await_image(i==3?1:i+2);image_pixels(i==3?1:i+2);tick(40000);end
check(fades==4,"manual A-B-C-D-A all faded");
short_key();monitor=1;
for(i=0;i<6;i=i+1)await_image((i+1)%4+1);
monitor=0;short_key();tick(50000);
check(fades>=10,"autoplay transitions including D-A faded");
settings=1;pause_media=1;await_image(5);image_pixels(5);
settings=0;table_request=1;await_image(6);image_pixels(6);
table_request=0;await_image(3);pause_media=0;tick(40000);
// Invalid next BMP must not black out the existing display.
ctrl.sd_card_top_m0.fault_file=4;ctrl.sd_card_top_m0.fault=1;ctrl.sd_card_top_m0.failures_left=99;
next_key();wait_degraded();check(code==3 && !fade_request && !fade_busy,"failed load leaves current monitor visible");
defaults();next_key();await_image(4);image_pixels(4);tick(40000);
check(!fade_busy && fade_shade==0,"transition returns to full brightness");
$fdisplay(logfd,"MONITOR_FADE_RESULT errors=%0d fades=%0d",errors,fades);$fclose(logfd);
$display("MONITOR_FADE_RESULT errors=%0d fades=%0d",errors,fades);$finish;
end
initial begin #60000000;errors=errors+1;$display("MONITOR_FADE_TIMEOUT");$finish;end
