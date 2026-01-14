/*******************************************************************************************
* Module: tb_vga_top_system
* Tests: 
* 1. Initialize and apply system reset
* 2. Select Lock-in mode and provide sample data
* 3. Select FFT mode and provide sample data
*******************************************************************************************/
`timescale 1ns/1ps

module tb_vga_top_system();

reg clk = 0;
always #10 clk = ~clk;

reg pixel_clk = 0;
always #20 pixel_clk = ~pixel_clk;

reg reset = 0;
reg i_switch_mode = 0;
reg [8:0] fft_addr = 0;
reg [23:0] fft_mag = 0;
reg fft_valid = 0;
reg lockin_valid = 0;
reg [41:0] lockin_mag = 0;
reg [41:0] lockin_phs = 0;

wire o_vga_hsync;
wire o_vga_vsync;
wire [9:0] o_vga_r;
wire [9:0] o_vga_g;
wire [9:0] o_vga_b;
wire o_vga_blank_n;
wire o_vga_sync_n;
wire o_pixel_clk;

vga_top_system dut (
    .clk(clk),
    .pixel_clk(pixel_clk),
    .reset(reset),
    .i_switch_mode(i_switch_mode),
    .fft_addr(fft_addr),
    .fft_mag(fft_mag),
    .fft_valid(fft_valid),
    .lockin_valid(lockin_valid),
    .lockin_mag(lockin_mag),
    .lockin_phs(lockin_phs),
    .o_vga_hsync(o_vga_hsync),
    .o_vga_vsync(o_vga_vsync),
    .o_vga_r(o_vga_r),
    .o_vga_g(o_vga_g),
    .o_vga_b(o_vga_b),
    .o_vga_blank_n(o_vga_blank_n),
    .o_vga_sync_n(o_vga_sync_n),
    .o_pixel_clk(o_pixel_clk)
);

initial begin
    //1
    reset = 1;
    #100;
    reset = 0;
    #100;

    //2
    i_switch_mode = 0;
    lockin_valid = 1;
    lockin_mag = 42'd500000;
    lockin_phs = 42'd100000;
    #1000;
    lockin_valid = 0;
    #500;

    //3
    i_switch_mode = 1;
    fft_valid = 1;
    fft_addr = 9'd256;
    fft_mag = 24'd123456;
    #1000;
    fft_valid = 0;
    #5000;

    $stop;
end

endmodule