/*******************************************************************************************
* Module: tb_button_edge_detector
* Tests: 
* 1. Press and release of a single key (Key 0) to verify pulse generation.
* 2. Simultaneous press of all keys to verify multi-channel detection.
* 3. Release of all keys to ensure no pulses are generated on the rising edge.
*******************************************************************************************/
`timescale 1ns/1ps

module tb_button_edge_detector;

reg clk = 0;
reg [3:0] keys_in;
wire [3:0] pulse_out;

always #10 clk = ~clk;

button_edge_detector dut (
    .clk(clk),
    .keys_in(keys_in),
    .pulse_out(pulse_out)
);

initial begin
    keys_in = 4'b1111;
    #100;

    // 1
    keys_in[0] = 0;
    #40;
    keys_in[0] = 1;
    #100;

    // 2
    keys_in = 4'b0000;
    #40;

    // 3
    keys_in = 4'b1111;
    #100;

    $stop;
end

endmodule