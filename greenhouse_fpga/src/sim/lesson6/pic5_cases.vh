initial begin
 logfd=$fopen("pic5_assertions.log","w");defaults();reset_card();await_image(1);image_pixels(1);
 check(ctrl.img_found_count==4,"PIC5 is not part of four-zone autoplay catalog");
 check(ctrl.fat32_parser.backend.resources==31,"all five FAT32 resources catalogued");
 pause_media=1;settings=1;await_image(5);image_pixels(5);
 tick(90000);check(code==5 && !ctrl.load_busy,"settings remains displayed without background prefetch");
 settings=0;await_image(1);image_pixels(1);pause_media=0;
 next_key();await_image(2);image_pixels(2);
 // Interrupt an automatic prefetch, then return to exactly the same zone.
 short_key();tick(100);pause_media=1;settings=1;await_image(5);image_pixels(5);
 tick(90000);check(code==5 && ctrl.auto_play_en,"autoplay paused, preference retained in settings");
 settings=0;await_image(2);image_pixels(2);tick(35000);check(code==2,"simulation edit page keeps media paused");
 pause_media=0;await_image(3);image_pixels(3);short_key();
 // Abandon PIC5 while its BMP is in flight: no stale settings frame may commit.
 pause_media=1;settings=1;tick(400);settings=0;tick(35000);check(code==3,"cancelled settings load preserves monitor frame");pause_media=0;
 // Missing PIC5 is optional at boot and must not mark any monitoring file bad.
 defaults();ctrl.sd_card_top_m0.missing=16;settings=0;pause_media=0;reset_card();await_image(1);image_pixels(1);
 pause_media=1;settings=1;wait_degraded();check(code==1 && ctrl.error_code==5 && ctrl.bad_mask==0,"missing PIC5 preserves previous image and monitor health");
 settings=0;pause_media=0;tick(100);next_key();await_image(2);image_pixels(2);
 // Present but unsupported BMP: bounded retry then safe return.
 defaults();settings=0;pause_media=0;reset_card();await_image(1);
 ctrl.sd_card_top_m0.fault_file=5;ctrl.sd_card_top_m0.fault=1;ctrl.sd_card_top_m0.failures_left=99;
 pause_media=1;settings=1;wait_degraded();check(code==1 && ctrl.error_code==1 && ctrl.bad_mask==0,"bad PIC5 cannot corrupt the zone catalog");
 settings=0;pause_media=0;tick(100);next_key();await_image(2);image_pixels(2);
 // Retry a settings request after leaving and re-entering.
 defaults();settings=1;pause_media=1;await_image(5);image_pixels(5);settings=0;await_image(2);image_pixels(2);
 $fdisplay(logfd,"PIC5_CONTROL_RESULT errors=%0d commits=%0d",errors,commits);$fclose(logfd);
 $display("PIC5_CONTROL_RESULT errors=%0d commits=%0d",errors,commits);$finish;
end
initial begin #60000000;errors=errors+1;$display("PIC5_TIMEOUT");$finish;end
