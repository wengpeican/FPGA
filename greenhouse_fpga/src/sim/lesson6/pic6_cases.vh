initial begin
 logfd=$fopen("pic6_assertions.log","w");defaults();reset_card();await_image(1);image_pixels(1);
 check(ctrl.img_found_count==4 && ctrl.fat32_parser.backend.resources==63,"six resources, only four in autoplay");
 pause_media=1;settings=1;await_image(5);image_pixels(5);
 settings=0;table_request=1;await_image(6);image_pixels(6);
 tick(90000);check(code==6 && !ctrl.load_busy,"PIC6 remains displayed without repeated loads");
 table_request=0;settings=1;await_image(5);image_pixels(5);
 settings=0;await_image(1);pause_media=0;
 next_key();await_image(2);short_key();tick(100);
 pause_media=1;table_request=1;await_image(6);image_pixels(6);
 tick(90000);check(code==6 && ctrl.auto_play_en,"PIC6 pauses autoplay without losing preference");
 table_request=0;await_image(2);image_pixels(2);pause_media=0;await_image(3);short_key();
 pause_media=1;table_request=1;tick(400);table_request=0;tick(35000);
 check(code==3,"cancelled PIC6 load cannot commit a stale frame");pause_media=0;
 // Switching between optional pages while loading must commit the current request.
 settings=1;pause_media=1;tick(400);settings=0;table_request=1;await_image(6);image_pixels(6);
 table_request=0;await_image(3);pause_media=0;
 defaults();ctrl.sd_card_top_m0.missing=32;reset_card();await_image(1);
 table_request=1;pause_media=1;wait_degraded();
 check(code==1 && ctrl.error_code==5 && ctrl.bad_mask==0,"missing PIC6 preserves monitor and resource health");
 table_request=0;settings=1;await_image(5);image_pixels(5);
 settings=0;pause_media=0;await_image(1);
 defaults();reset_card();await_image(1);
 ctrl.sd_card_top_m0.fault_file=6;ctrl.sd_card_top_m0.fault=1;ctrl.sd_card_top_m0.failures_left=99;
 table_request=1;pause_media=1;wait_degraded();
 check(code==1 && ctrl.error_code==1 && ctrl.bad_mask==0,"bad PIC6 has bounded retries without corrupting monitor catalog");
 table_request=0;pause_media=0;tick(100);next_key();await_image(2);
 defaults();table_request=1;pause_media=1;await_image(6);image_pixels(6);
 table_request=0;pause_media=0;await_image(2);image_pixels(2);
 $fdisplay(logfd,"PIC6_CONTROL_RESULT errors=%0d commits=%0d",errors,commits);$fclose(logfd);
 $display("PIC6_CONTROL_RESULT errors=%0d commits=%0d",errors,commits);$finish;
end
initial begin #60000000;errors=errors+1;$display("PIC6_TIMEOUT");$finish;end
