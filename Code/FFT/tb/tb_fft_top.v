/*******************************************************************************************
* Module: tb_fft_top
* Tests: 
* 1. System reset and initialization
* 2. Input data loading via buffer interface using a square wave pattern
* 3. FFT processing execution and magnitude result monitoring
*******************************************************************************************/
`timescale 1ns/1ps

module tb_fft_top;

reg clk = 0;
reg reset = 0;
reg i_buffer_data_ready = 0;
reg signed [23:0] i_buffer_data = 0;
wire [8:0] o_buffer_read_addr;
wire [8:0] o_fft_magnitude_addr;
wire [23:0] o_fft_magnitude_out;
wire o_fft_out_valid;
wire o_fft_done_pulse;
wire o_fft_busy;

fft_top dut (
    .clk(clk),
    .reset(reset),
    .i_buffer_data_ready(i_buffer_data_ready),
    .i_buffer_data(i_buffer_data),
    .o_buffer_read_addr(o_buffer_read_addr),
    .o_fft_magnitude_addr(o_fft_magnitude_addr),
    .o_fft_magnitude_out(o_fft_magnitude_out),
    .o_fft_out_valid(o_fft_out_valid),
    .o_fft_done_pulse(o_fft_done_pulse),
    .o_fft_busy(o_fft_busy)
);

always #10 clk = ~clk;

always @(*) begin
    if (o_buffer_read_addr < 256) begin
        i_buffer_data = 24'd10000;
    end else begin
        i_buffer_data = -24'd10000;
    end
end

initial begin
    //1
    reset = 1;
    #100;
    reset = 0;
    #100;

    //2
    i_buffer_data_ready = 1;
    wait (o_fft_busy == 1);
    i_buffer_data_ready = 0;

    //3
    wait (o_fft_done_pulse == 1);
    #200;
    $finish;
end

endmodule