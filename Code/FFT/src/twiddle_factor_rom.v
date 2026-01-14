/************************************************************************************
* Module: twiddle_factor_rom
*
* Description:
* A synchronous ROM for the twiddle factors of a 512-point FFT.
* Uses the first 256 values (in Q1.23 format) and calculates the others.
* using the symmetry W_N^(k+N/2) = -W_N^k.
* The output has a latency of one clock cycle.
********************************************************************************/
module twiddle_factor_rom #(
    parameter ADDR_WIDTH = 9,
    parameter DATA_WIDTH = 48
) (
    input clk,
    input [ADDR_WIDTH-1:0] addr,
    output wire [DATA_WIDTH-1:0] twiddle_factor_q // wire because assigned in a concurrent assignment
);

    localparam PART_WIDTH = DATA_WIDTH / 32'd2;

    // ROM Array-1 for the sign and 2**(ADDR_WIDTH-1) deep
    reg [DATA_WIDTH-1:0] twiddle_rom [0:(32'd1<<(ADDR_WIDTH-32'd1))-32'd1];

    initial begin
        // hex file path
        $readmemh("C:/Users/pietr/Documents/Verilog/Progetto/FFT/twiddle_factors.hex", twiddle_rom);
    end

    // ROM address (excluding the MSB used for sign inversion)
    wire [ADDR_WIDTH-32'd2:0] rom_addr = addr[ADDR_WIDTH-32'd2:0];
    
    // Registers for RAM output and sign flag
    reg [DATA_WIDTH-1:0] ram_data_out;
    reg invert_flag_out;

    // Synchronous RAM read operation
    // Sequential logic block
    always @(posedge clk) begin
        // Read happens at posedge, so latency is 1 cycle
        ram_data_out <= twiddle_rom[rom_addr];
        // Store the sign inversion flag
        invert_flag_out <= addr[ADDR_WIDTH-1];
    end
    // Combinational logic block
    // C2
    wire [DATA_WIDTH-1:0] negated_data = {
        ~ram_data_out[DATA_WIDTH-1:PART_WIDTH] + 1'b1, // Real
        ~ram_data_out[PART_WIDTH-1:0] + 1'b1 // Imaginary
    };

    // MUX to choose between normal and negated data
    assign twiddle_factor_q = (invert_flag_out) ? negated_data : ram_data_out;

endmodule