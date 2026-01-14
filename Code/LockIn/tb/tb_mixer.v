/*******************************************************************************************
* Module: tb_mixer
* Tests: 
* 1. Initialize signals and apply system reset to verify the idle state.
* 2. Input positive data and sine/cosine values to verify signed multiplication.
* 3. Input negative data to verify the signed arithmetic logic of the mixer.
* 4. Assert reset during operation to ensure outputs and valid signals are cleared.
*******************************************************************************************/
`timescale 1ns/1ps

module tb_mixer;

reg clk = 0;
always #10 clk = ~clk;

reg reset;
reg start;
reg signed [23:0] data_in;
reg signed [17:0] sine_in;
reg signed [17:0] cosine_in;

wire signed [41:0] phase_out;
wire signed [41:0] quadrature_out;
wire o_valid;

mixer #(
    .DATA_WIDTH(24),
    .SIN_WIDTH(18)
) dut (
    .clk(clk),
    .reset(reset),
    .start(start),
    .data_in(data_in),
    .sine_in(sine_in),
    .cosine_in(cosine_in),
    .phase_out(phase_out),
    .quadrature_out(quadrature_out),
    .o_valid(o_valid)
);

initial begin
    // 1
    reset = 1;
    start = 0;
    data_in = 0;
    sine_in = 0;
    cosine_in = 0;
    #40 reset = 0;
    #20;

    // 2
    data_in = 24'sd1000;
    sine_in = 18'sd500;
    cosine_in = 18'sd250;
    start = 1;
    #20 start = 0;
    #40;

    // 3
    data_in = -24'sd1000;
    sine_in = 18'sd500;
    cosine_in = 18'sd250;
    start = 1;
    #20 start = 0;
    #40;

    // 4
    reset = 1;
    #20 reset = 0;
    #100;
    $stop;
end

endmodule