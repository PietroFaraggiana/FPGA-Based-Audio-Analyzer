/*******************************************************************************************
* Module: tb_display_control
* Tests: 
* 1. Reset state verification
* 2. Frequency conversion for 1200 Hz and scale 01
* 3. Frequency conversion for 2745 Hz and scale 10
* 4. Maximum frequency conversion 8191 Hz and scale 11
*******************************************************************************************/
`timescale 1ns/1ps

module tb_display_control;

reg clk = 0;
reg reset = 0;
reg [1:0] scale_in = 0;
reg [12:0] frequency_in = 0;

wire [6:0] hex0;
wire [6:0] hex1;
wire [6:0] hex2;
wire [6:0] hex3;
wire [6:0] hex4;
wire [6:0] hex5;
wire [6:0] hex6;
wire [6:0] hex7;

always #10 clk = ~clk;

display_control #(
    .FREQUENCY_RANGE(8192)
) dut (
    .clk(clk),
    .reset(reset),
    .scale_in(scale_in),
    .frequency_in(frequency_in),
    .hex0(hex0),
    .hex1(hex1),
    .hex2(hex2),
    .hex3(hex3),
    .hex4(hex4),
    .hex5(hex5),
    .hex6(hex6),
    .hex7(hex7)
);

initial begin
    // 1
    reset = 1;
    #100;
    reset = 0;
    #100;

    // 2
    scale_in = 2'b01;
    frequency_in = 1200;
    #1000;

    // 3
    scale_in = 2'b10;
    frequency_in = 2745;
    #1000;

    // 4
    scale_in = 2'b11;
    frequency_in = 8191;
    #1000;

    $stop;
end

endmodule