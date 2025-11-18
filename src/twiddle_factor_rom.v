/************************************************************************************
* Module: twiddle_factor_rom
*
* Description:
* A synchronous ROM for the twiddle factors of a 512-point FFT.
* Uses the first 256 values ​​(in Q1.23 format) and calculates the others
* using the symmetry W_N^(k+N/2) = -W_N^k.
* The output is logged, introducing a latency of one clock cycle.
*
* Parameters:
* ADDR_WIDTH - Address width (9 by 512 points)
* DATA_WIDTH - Data width (48 bits: 24 real + 24 imaginary)
*
********************************************************************************/
module twiddle_factor_rom #(
    parameter ADDR_WIDTH = 9,
    parameter DATA_WIDTH = 48
) (
    input                       clk,
    input                       rst_n, // Async low active Reset
    input      [ADDR_WIDTH-1:0] addr,
    output reg [DATA_WIDTH-1:0] twiddle_factor_q
);

    // Width of real and imaginary parts
    localparam PART_WIDTH = DATA_WIDTH / 2;

    // Internal memory to hold the first 256 twiddle factors 
    reg [DATA_WIDTH-1:0] twiddle_rom [0:(1<<(ADDR_WIDTH-1))-1];

    //Memory Initialization
    initial begin
        $readmemh("C:/Users/pietr/Documents/Verilog/Progetto/FFT/twiddle_factors.hex", twiddle_rom);
    end

    // Reading logic

    // 1. Combinational Logic
    // The address for the physical ROM (256 elements) uses only the low bits of addr
    wire [ADDR_WIDTH-2:0] rom_addr = addr[ADDR_WIDTH-2:0];

    // Read directly from ROM
    wire [DATA_WIDTH-1:0] rom_data = twiddle_rom[rom_addr];

    // C2's complement negation of the ROM data
    wire [DATA_WIDTH-1:0] negated_rom_data = {
        ~rom_data[DATA_WIDTH-1:PART_WIDTH] + 1'b1, // Real
        ~rom_data[PART_WIDTH-1:0]          + 1'b1  // Imaginary
    };

    // MSB of the address selects between original and negated data 
    wire [DATA_WIDTH-1:0] comb_out = (addr[ADDR_WIDTH-1]) ? negated_rom_data : rom_data;


    // 2. Sequential Logic (Pipelining)
    always @(posedge clk) begin
    if (!rst_n) begin 
        twiddle_factor_q <= 0;
    end else begin
        twiddle_factor_q <= comb_out;
    end
end

endmodule