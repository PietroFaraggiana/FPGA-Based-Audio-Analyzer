/*******************************************************************************************
* Module: tb_vga_controller
* Tests: 
* 1. System reset: Verify that all counters and sync signals return to their default states.
* 2. Horizontal timing: Observe pixel_x and h_sync behavior during a few lines.
* 3. Full frame completion: Run the simulation long enough to trigger the frame_over pulse.
*******************************************************************************************/
`timescale 1ns/1ps

module tb_vga_controller;

reg pixel_clk = 0;
reg reset;
wire h_sync;
wire v_sync;
wire video_on;
wire [9:0] pixel_x;
wire [9:0] pixel_y;
wire frame_over;

vga_controller dut (
    .pixel_clk(pixel_clk),
    .reset(reset),
    .h_sync(h_sync),
    .v_sync(v_sync),
    .video_on(video_on),
    .pixel_x(pixel_x),
    .pixel_y(pixel_y),
    .frame_over(frame_over)
);

always #10 pixel_clk = ~pixel_clk;

initial begin
    // 1
    reset = 1;
    #100;
    reset = 0;
    
    // 2
    #200000;
    
    // 3
    wait(frame_over);
    #100;
    
    $stop;
end

endmodule