/*******************************************************************************************
* Module: tb_lockin_controller
* Tests: 
* 1. System Reset: Verify that all registers are initialized to zero.
* 2. Start Processing: Trigger buffer_ready and check if ddfs_tuning_word is loaded.
* 3. Single Sample Flow: Simulate DDFS and Mixer handshake for one sample.
* 4. Full Buffer Loop: Simulate the processing of multiple samples until the end.
*******************************************************************************************/
`timescale 1ns/1ps

module tb_lockin_controller;

parameter BUFFER_DEPTH = 512;
parameter DATA_WIDTH = 24;
parameter FREQUENCY_SIZE_IN = 13;
parameter FREQUENCY_SIZE_OUT = 16;
parameter SIN_WIDTH = 18;

reg clk = 0;
reg reset;
reg [FREQUENCY_SIZE_IN-1:0] tuning_word_in;
wire [FREQUENCY_SIZE_OUT-1:0] ddfs_tuning_word;
reg buffer_ready;
wire [$clog2(BUFFER_DEPTH)-1:0] buffer_addr;
reg [DATA_WIDTH-1:0] buffer_data;
wire mixer_start_en;
wire signed [DATA_WIDTH-1:0] mixer_data_in;
wire signed [SIN_WIDTH-1:0] mixer_sine_in;
wire signed [SIN_WIDTH-1:0] mixer_cosine_in;
reg signed [(DATA_WIDTH + SIN_WIDTH)-1:0] mixer_phase_out;
reg signed [(DATA_WIDTH + SIN_WIDTH)-1:0] mixer_quadrature_out;
reg mixer_valid_out;
wire signed [(DATA_WIDTH + SIN_WIDTH)-1:0] cic_phase_in;
wire signed [(DATA_WIDTH + SIN_WIDTH)-1:0] cic_quadrature_in;
wire [$clog2(BUFFER_DEPTH)-1:0] cic_addr_in;
wire cic_valid_in;
wire ddfs_sample_en;
reg ddfs_valid_out;
reg signed [SIN_WIDTH-1:0] ddfs_sine_out;
reg signed [SIN_WIDTH-1:0] ddfs_cosine_out;

lockin_controller #(
    .BUFFER_DEPTH(BUFFER_DEPTH),
    .DATA_WIDTH(DATA_WIDTH),
    .FREQUENCY_SIZE_IN(FREQUENCY_SIZE_IN),
    .FREQUENCY_SIZE_OUT(FREQUENCY_SIZE_OUT),
    .SIN_WIDTH(SIN_WIDTH)
) dut (
    .clk(clk),
    .reset(reset),
    .tuning_word_in(tuning_word_in),
    .ddfs_tuning_word(ddfs_tuning_word),
    .buffer_ready(buffer_ready),
    .buffer_addr(buffer_addr),
    .buffer_data(buffer_data),
    .mixer_start_en(mixer_start_en),
    .mixer_data_in(mixer_data_in),
    .mixer_sine_in(mixer_sine_in),
    .mixer_cosine_in(mixer_cosine_in),
    .mixer_phase_out(mixer_phase_out),
    .mixer_quadrature_out(mixer_quadrature_out),
    .mixer_valid_out(mixer_valid_out),
    .cic_phase_in(cic_phase_in),
    .cic_quadrature_in(cic_quadrature_in),
    .cic_addr_in(cic_addr_in),
    .cic_valid_in(cic_valid_in),
    .ddfs_sample_en(ddfs_sample_en),
    .ddfs_valid_out(ddfs_valid_out),
    .ddfs_sine_out(ddfs_sine_out),
    .ddfs_cosine_out(ddfs_cosine_out)
);

always #10 clk = ~clk;

initial begin
// 1
reset = 1;
tuning_word_in = 0;
buffer_ready = 0;
buffer_data = 0;
mixer_phase_out = 0;
mixer_quadrature_out = 0;
mixer_valid_out = 0;
ddfs_valid_out = 0;
ddfs_sine_out = 0;
ddfs_cosine_out = 0;
#100;
reset = 0;
#40;

// 2
tuning_word_in = 13'h1ABC;
buffer_ready = 1;
#20;
buffer_ready = 0;
#40;

// 3
buffer_data = 24'hAABBCC;
ddfs_sine_out = 18'h10000;
ddfs_cosine_out = 18'h05555;
ddfs_valid_out = 1;
#20;
ddfs_valid_out = 0;
#40;
mixer_phase_out = 42'h123456789A;
mixer_quadrature_out = 42'h0987654321;
mixer_valid_out = 1;
#20;
mixer_valid_out = 0;
#100;

// 4
repeat (5) begin
wait(ddfs_sample_en);
#20;
buffer_data = buffer_data + 1;
ddfs_valid_out = 1;
#20;
ddfs_valid_out = 0;
wait(mixer_start_en);
#40;
mixer_valid_out = 1;
#20;
mixer_valid_out = 0;
end

#200;
$stop;
end

endmodule