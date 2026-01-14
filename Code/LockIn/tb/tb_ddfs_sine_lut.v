/*******************************************************************************************
* Module: tb_ddfs_sine_lut
* Tests: 
* 1. Discrete Check: Verifies specific phase angles (0, 256, 512, 768)
* 2. Waveform Sweep: Generates 3 full periods of Sine and Cosine waves
*******************************************************************************************/
`timescale 1ns/1ps

module tb_ddfs_sine_lut;

reg clk = 0;
reg [9:0] addr = 0;
wire signed [17:0] sine_out;
wire signed [17:0] cosine_out;

always #10 clk = ~clk;

ddfs_sine_lut #(
    .LUT_DEPTH(10),
    .LUT_BITS(18)
) dut (
    .clk(clk),
    .addr(addr),
    .sine_out(sine_out),
    .cosine_out(cosine_out)
);

integer i;

initial begin
    // 1
    addr = 0;
    #40;
    addr = 256;
    #40;
    addr = 512;
    #40;
    addr = 768;
    #40;

    // 2
    for (i = 0; i < 3072; i = i + 1) begin
        addr = i;
        @(posedge clk);
    end

    $stop;
end

endmodule