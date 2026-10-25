`timescale 1ns/1ps
module lesson5_startup(
 input ext_rst_n,input sys_locked,input video_locked,
 input sd_clk,input mem_clk,input pixel_clk,input mem_init_done,
 output pll_reset,output rst_request,output rst_sd,output rst_mem,output rst_pixel,
 output storage_ready
);
 // Never drive a PLL reset from its own LOCK signal: that prevents acquisition.
 assign pll_reset=~ext_rst_n;
 assign rst_request=~ext_rst_n | ~sys_locked | ~video_locked;
 wire sd_n,mem_n,pixel_n;
 reset_sync u_sd(.clk(sd_clk),.ext_rst_n(~rst_request),.rst_n_sync(sd_n));
 reset_sync u_mem(.clk(mem_clk),.ext_rst_n(~rst_request),.rst_n_sync(mem_n));
 reset_sync u_pixel(.clk(pixel_clk),.ext_rst_n(~rst_request),.rst_n_sync(pixel_n));
 assign rst_sd=~sd_n;
 assign rst_mem=~mem_n;
 assign rst_pixel=~pixel_n;
 // The SDRAM must leave reset to initialize. Gate the consumer, not its reset.
 sync_2ff u_ready(.clk(sd_clk),.rst_n(sd_n),.async_in(mem_init_done),.sync_out(storage_ready));
endmodule