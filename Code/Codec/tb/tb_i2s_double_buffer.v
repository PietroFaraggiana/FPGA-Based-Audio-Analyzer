/*******************************************************************************************
* Module: tb_i2s_double_buffer
*
* Tests: 
* 1. System reset and initialization
* 2. Fill the first buffer and verify o_data_ready pulse
* 3. Simultaneous read from the first buffer and write to the second buffer
*******************************************************************************************/
`timescale 1ns/1ps

module tb_i2s_double_buffer;

parameter DATA_WIDTH = 24;
parameter BUFFER_DEPTH = 512;
parameter ADDR_WIDTH = 9;

reg clk = 0;
reg reset;
reg i_audio_valid;
reg [DATA_WIDTH-1:0] i_audio_data;
reg [ADDR_WIDTH-1:0] i_read_addr;
wire [DATA_WIDTH-1:0] o_data_out;
wire o_data_ready;

integer i;

i2s_double_buffer #(
    .DATA_WIDTH(DATA_WIDTH),
    .BUFFER_DEPTH(BUFFER_DEPTH)
) dut (
    .clk(clk),
    .reset(reset),
    .i_audio_valid(i_audio_valid),
    .i_audio_data(i_audio_data),
    .i_read_addr(i_read_addr),
    .o_data_out(o_data_out),
    .o_data_ready(o_data_ready)
);

always #10 clk = ~clk;

initial begin
    // 1
    reset = 1;
    i_audio_valid = 0;
    i_audio_data = 0;
    i_read_addr = 0;
    #40;
    reset = 0;
    #20;

    // 2
    for (i = 0; i < BUFFER_DEPTH; i = i + 1) begin
        @(posedge clk);
        i_audio_valid = 1;
        i_audio_data = i + 1;
    end
    @(posedge clk);
    i_audio_valid = 0;
    
    wait(o_data_ready);
    @(posedge clk);

    // 3
    for (i = 0; i < BUFFER_DEPTH; i = i + 1) begin
        @(posedge clk);
        i_audio_valid = 1;
        i_audio_data = i + 1000;
        i_read_addr = i;
    end
    @(posedge clk);
    i_audio_valid = 0;

    #100;
    $stop;
end

endmodule