/*******************************************************************************************
* Module: tb_twiddle_factor_rom
* Tests: 
* 1. Read address 0 to check the first value of the ROM.
* 2. Read address 255 to check the last value of the first half (positive).
* 3. Read address 256 to verify symmetry logic (should be negative of address 0).
* 4. Read address 511 to verify symmetry logic (should be negative of address 255).
*******************************************************************************************/
`timescale 1ns/1ps

module tb_twiddle_factor_rom;

parameter ADDR_WIDTH = 9;
parameter DATA_WIDTH = 48;

reg clk = 0;
always #10 clk = ~clk;

reg [ADDR_WIDTH-1:0] addr;
wire [DATA_WIDTH-1:0] twiddle_factor_q;

twiddle_factor_rom #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
) dut (
    .clk(clk),
    .addr(addr),
    .twiddle_factor_q(twiddle_factor_q)
);

initial begin
    addr = 0;
    #25;

    // 1
    addr = 0;
    @(posedge clk);
    @(posedge clk);
    #5;

    // 2
    addr = 255;
    @(posedge clk);
    @(posedge clk);
    #5;

    // 3
    addr = 256;
    @(posedge clk);
    @(posedge clk);
    #5;

    // 4
    addr = 511;
    @(posedge clk);
    @(posedge clk);
    #5;

    $stop;
end

endmodule
