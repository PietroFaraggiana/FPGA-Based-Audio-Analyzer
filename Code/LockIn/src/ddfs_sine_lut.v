/************************************************************************************
* Module: ddfs_sine_lut
*
* Description: Synchronous ROM containing a full period of a sine wave.
* Port Q (Sine) reads input address, while port I (Cosine) reads input address + 90 degrees
************************************************************************************/
module ddfs_sine_lut #(
    parameter LUT_DEPTH = 10,
    parameter LUT_BITS = 18,
    parameter HEX_FILE = "C:/Users/pietr/Documents/Verilog/Progetto/LOCKIN/ddfs_sin_lut.hex" 
    ) (
    input clk,
    input [LUT_DEPTH-1:0] addr,
    output reg signed [LUT_BITS-1:0] sine_out,
    output reg signed [LUT_BITS-1:0] cosine_out
);

    // ROM Memory Array
    reg signed [LUT_BITS-1:0] sine_rom [0:(1<<LUT_DEPTH)-1];

    // Initialize ROM
    initial begin
        $readmemh(HEX_FILE, sine_rom);
    end

    // Normal address for Q
    wire [LUT_DEPTH-1:0] addr_sin = addr;
    // Offset address for I
    // 1/4 of a circle is LUT_DEPTH/4
    localparam OFFSET_90_DEG = 1 << (LUT_DEPTH - 2);
    // No overflow because overflown bits are cut and it starts again by 0 (1/4*4=1)
    wire [LUT_DEPTH-1:0] addr_cos = addr + OFFSET_90_DEG;
    // Synchronous Read Process
    always @(posedge clk) begin
        sine_out <= sine_rom[addr_sin];
        cosine_out <= sine_rom[addr_cos];
    end

endmodule