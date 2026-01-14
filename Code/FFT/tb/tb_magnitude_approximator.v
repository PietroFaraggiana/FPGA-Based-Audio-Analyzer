/*******************************************************************************************
* Module: tb_magnitude_approximator
* Tests: 
* 1. Basic positive inputs to verify pure real and imaginary values
* 2. Negative inputs to verify absolute value calculation
* 3. Maximum positive values to verify saturation logic
* 4. Verify pipeline throughput
*******************************************************************************************/
`timescale 1ns/1ps

module tb_magnitude_approximator;

parameter DATA_WIDTH = 24;

reg clk = 0;
reg reset;
reg i_start;
reg [DATA_WIDTH*2-1:0] i_fft_complex;

wire [DATA_WIDTH-1:0] o_magnitude;
wire o_valid;

always #10 clk = ~clk;

magnitude_approximator #(
    .DATA_WIDTH(DATA_WIDTH)
) dut (
    .clk(clk),
    .reset(reset),
    .i_start(i_start),
    .i_fft_complex(i_fft_complex),
    .o_magnitude(o_magnitude),
    .o_valid(o_valid)
);

initial begin
    reset = 1;
    i_start = 0;
    i_fft_complex = 0;
    #100;
    reset = 0;
    @(posedge clk);

    // 1
    i_fft_complex = {24'd1000, 24'd0};
    i_start = 1;
    @(posedge clk);
    i_start = 0;
    repeat(4) @(posedge clk);

    // 2
    i_fft_complex = {-24'd2000, 24'd500};
    i_start = 1;
    @(posedge clk);
    i_start = 0;
    repeat(4) @(posedge clk);

    // 3
    i_fft_complex = {24'h7FFFFF, 24'h7FFFFF};
    i_start = 1;
    @(posedge clk);
    i_start = 0;
    repeat(4) @(posedge clk);

    // 4
    i_fft_complex = {24'd100, 24'd100};
    i_start = 1;
    @(posedge clk);
    i_fft_complex = {24'd200, 24'd200};
    i_start = 1;
    @(posedge clk);
    i_fft_complex = {24'd300, 24'd300};
    i_start = 1;
    @(posedge clk);
    i_start = 0;
    repeat(10) @(posedge clk);

    $stop;
end

endmodule