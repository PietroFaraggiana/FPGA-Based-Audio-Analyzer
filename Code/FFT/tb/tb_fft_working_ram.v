/*******************************************************************************************
* Module: tb_fft_working_ram
* Tests: 
* 1. Write and Read operation on Port A
* 2. Write and Read operation on Port B
* 3. Simultaneous access: Write on Port A and Read on Port B
*******************************************************************************************/
`timescale 1ns/1ps

module tb_fft_working_ram;

    parameter DATA_WIDTH = 48;
    parameter BUFFER_DEPTH = 512;
    parameter ADDR_WIDTH = 9;

    reg clk = 0;
    reg [ADDR_WIDTH-1:0] i_addr_a;
    reg [DATA_WIDTH-1:0] i_data_a;
    reg i_wr_en_a;
    wire [DATA_WIDTH-1:0] o_data_a;
    reg [ADDR_WIDTH-1:0] i_addr_b;
    reg [DATA_WIDTH-1:0] i_data_b;
    reg i_wr_en_b;
    wire [DATA_WIDTH-1:0] o_data_b;

    fft_working_ram #(
        .DATA_WIDTH(DATA_WIDTH),
        .BUFFER_DEPTH(BUFFER_DEPTH)
    ) dut (
        .clk(clk),
        .i_addr_a(i_addr_a),
        .i_data_a(i_data_a),
        .i_wr_en_a(i_wr_en_a),
        .o_data_a(o_data_a),
        .i_addr_b(i_addr_b),
        .i_data_b(i_data_b),
        .i_wr_en_b(i_wr_en_b),
        .o_data_b(o_data_b)
    );

    always #10 clk = ~clk;

    initial begin
        i_addr_a = 0;
        i_data_a = 0;
        i_wr_en_a = 0;
        i_addr_b = 0;
        i_data_b = 0;
        i_wr_en_b = 0;
        #100;

        // 1
        @(posedge clk);
        i_addr_a = 9'd10;
        i_data_a = 48'hABCDE1234567;
        i_wr_en_a = 1;
        @(posedge clk);
        i_wr_en_a = 0;
        @(posedge clk);
        i_addr_a = 9'd10;
        #5;

        // 2
        @(posedge clk);
        i_addr_b = 9'd20;
        i_data_b = 48'h7654321EDCBA;
        i_wr_en_b = 1;
        @(posedge clk);
        i_wr_en_b = 0;
        @(posedge clk);
        i_addr_b = 9'd20;
        #5;

        // 3
        @(posedge clk);
        i_addr_a = 9'd30;
        i_data_a = 48'hFFFFFFFFFFFF;
        i_wr_en_a = 1;
        i_addr_b = 9'd10;
        i_wr_en_b = 0;
        @(posedge clk);
        i_wr_en_a = 0;
        #20;

        $stop;
    end

endmodule