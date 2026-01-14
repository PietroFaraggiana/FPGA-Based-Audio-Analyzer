/*******************************************************************************************
* Module: tb_top_audio
* Tests: 
* 1. System reset and initialization
* 2. Verification of the I2C configuration start
* 3. Reception of I2S audio data samples
* 4. Double buffer reading and simulation end
*******************************************************************************************/
`timescale 1ns/1ps

module tb_top_audio;

reg clk = 0;
reg reset = 0;
reg i_aud_bclk = 0;
reg i_aud_adclrck = 0;
reg i_aud_adcdat = 0;
reg [8:0] i_read_addr = 0;

wire o_aud_xck;
wire o_i2c_sclk;
wire io_i2c_sdat;
wire [23:0] o_audio_sample;
wire o_buffer_ready;
wire o_config_done;

assign io_i2c_sdat = 1'bz;

top_audio dut (
    .clk(clk),
    .reset(reset),
    .o_aud_xck(o_aud_xck),
    .i_aud_bclk(i_aud_bclk),
    .i_aud_adclrck(i_aud_adclrck),
    .i_aud_adcdat(i_aud_adcdat),
    .o_i2c_sclk(o_i2c_sclk),
    .io_i2c_sdat(io_i2c_sdat),
    .i_read_addr(i_read_addr),
    .o_audio_sample(o_audio_sample),
    .o_buffer_ready(o_buffer_ready),
    .o_config_done(o_config_done)
);

always #10 clk = ~clk;
always #160 i_aud_bclk = ~i_aud_bclk;
always #10417 i_aud_adclrck = ~i_aud_adclrck;

reg [23:0] sdata_pattern = 24'hA51234;
integer bit_idx = 23;

always @(negedge i_aud_bclk) begin
    i_aud_adcdat = sdata_pattern[bit_idx];
    if (bit_idx == 0) begin
        bit_idx = 23;
    end else begin
        bit_idx = bit_idx - 1;
    end
end

initial begin
    // 1
    reset = 1;
    #100;
    reset = 0;
    // 2
    #2000;
    // 3
    #100000;
    // 4
    i_read_addr = 9'd10;
    #1000;
    $stop;
end

endmodule