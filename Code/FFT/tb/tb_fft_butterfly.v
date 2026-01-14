/*******************************************************************************************
* Module: tb_fft_butterfly
* Tests: 
* 1. Identity test: Butterfly with twiddle factor approximately 1.0 (Real)
* 2. Quadrature rotation: Butterfly with twiddle factor -j (Imaginary)
* 3. Zero input test: Verifying output and valid flag with null inputs
*******************************************************************************************/
`timescale 1ns/1ps

module tb_fft_butterfly;
    parameter DATA_WIDTH = 24;
    parameter TWIDDLE_WIDTH = 24;

    reg clk = 0;
    reg reset;
    reg i_start;
    reg signed [DATA_WIDTH*2-1:0] i_data_a;
    reg signed [DATA_WIDTH*2-1:0] i_data_b;
    reg signed [TWIDDLE_WIDTH*2-1:0] i_twiddle;

    wire signed [DATA_WIDTH*2-1:0] o_data_a_out;
    wire signed [DATA_WIDTH*2-1:0] o_data_b_out;
    wire o_valid;

    always #10 clk = ~clk;

    fft_butterfly #(
        .DATA_WIDTH(DATA_WIDTH),
        .TWIDDLE_WIDTH(TWIDDLE_WIDTH)
    ) dut (
        .clk(clk),
        .reset(reset),
        .i_start(i_start),
        .i_data_a(i_data_a),
        .i_data_b(i_data_b),
        .i_twiddle(i_twiddle),
        .o_data_a_out(o_data_a_out),
        .o_data_b_out(o_data_b_out),
        .o_valid(o_valid)
    );

    initial begin
        reset = 1;
        i_start = 0;
        i_data_a = 0;
        i_data_b = 0;
        i_twiddle = 0;
        #40;
        reset = 0;
        #20;

        // \\1
        i_data_a = {24'd2000, 24'd0};
        i_data_b = {24'd1000, 24'd0};
        i_twiddle = {24'h7FFFFF, 24'd0};
        i_start = 1;
        #20;
        i_start = 0;
        #100;

        // \\2
        i_data_a = {24'd1000, 24'd1000};
        i_data_b = {24'd500, 24'd500};
        i_twiddle = {24'd0, -24'sh800000};
        i_start = 1;
        #20;
        i_start = 0;
        #100;

        // \\3
        i_data_a = 0;
        i_data_b = 0;
        i_twiddle = 0;
        i_start = 1;
        #20;
        i_start = 0;
        #100;

        $stop;
    end

endmodule