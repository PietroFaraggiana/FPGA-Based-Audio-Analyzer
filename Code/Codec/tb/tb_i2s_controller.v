/*******************************************************************************************
* Module: tb_i2s_controller
* Tests: 
* 1. System reset initialization
* 2. Serial data input sequence during LRCLK low phase
* 3. Transition of LRCLK to high to trigger parallel data output and valid flag
*******************************************************************************************/
`timescale 1ns/1ps

module tb_i2s_controller;

reg bclk = 0;
reg lrclk = 0;
reg sdata_in = 0;
reg reset = 0;

wire [23:0] o_audio_data;
wire o_audio_valid;

i2s_controller dut (
    .bclk(bclk),
    .lrclk(lrclk),
    .sdata_in(sdata_in),
    .reset(reset),
    .o_audio_data(o_audio_data),
    .o_audio_valid(o_audio_valid)
);

always #10 bclk = ~bclk;

integer i;
reg [23:0] test_pattern = 24'hACE123;

initial begin
    // 1
    reset = 1;
    lrclk = 0;
    sdata_in = 0;
    #100;
    reset = 0;
    #40;

    // 2
    for (i = 23; i >= 0; i = i - 1) begin
        sdata_in = test_pattern[i];
        @(posedge bclk);
    end
    sdata_in = 0;
    repeat (8) @(posedge bclk);

    // 3
    lrclk = 1;
    repeat (10) @(posedge bclk);

    $stop;
end

endmodule