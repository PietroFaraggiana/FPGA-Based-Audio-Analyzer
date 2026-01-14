/*******************************************************************************************
* Module: tb_ddfs_core
* Tests: 
* 1. Initialize system and generate a low frequency sine/cosine wave.
* 2. High frequency test (Fs/4) to verify 90 degrees phase shift between I and Q.
* 3. Reset assertion during operation to verify the accumulator and valid signal clearing.
*******************************************************************************************/
`timescale 1ns/1ps

module tb_ddfs_core;

reg clk = 0;
reg reset;
reg sample_en;
reg [15:0] tuning_word;
wire signed [17:0] cosine_out;
wire signed [17:0] sine_out;
wire valid_out;

ddfs_core #(
    .ACC_WIDTH(16),
    .LUT_DEPTH(10),
    .LUT_BITS(18)
) dut (
    .clk(clk),
    .reset(reset),
    .sample_en(sample_en),
    .tuning_word(tuning_word),
    .cosine_out(cosine_out),
    .sine_out(sine_out),
    .valid_out(valid_out)
);

always #10 clk = ~clk;

initial begin
//1
reset = 1;
sample_en = 0;
tuning_word = 16'd256;
repeat (10) @(posedge clk);
reset = 0;
repeat (50) begin
@(posedge clk);
sample_en = 1;
@(posedge clk);
sample_en = 0;
repeat (5) @(posedge clk);
end

//2
@(posedge clk);
tuning_word = 16'd16384;
repeat (10) begin
@(posedge clk);
sample_en = 1;
@(posedge clk);
sample_en = 0;
repeat (5) @(posedge clk);
end

//3
@(posedge clk);
reset = 1;
repeat (5) begin
@(posedge clk);
sample_en = 1;
@(posedge clk);
sample_en = 0;
repeat (2) @(posedge clk);
end
@(posedge clk);
reset = 0;
tuning_word = 16'd1024;
repeat (10) begin
@(posedge clk);
sample_en = 1;
@(posedge clk);
sample_en = 0;
repeat (5) @(posedge clk);
end

$stop;
end

endmodule