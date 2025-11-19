/************************************************************************************
* Module: fft_working_ram
* Description:
* Implements a synchronous dual-port RAM (Block RAM)
* optimized for inference on Altera/Intel FPGAs.
* - Read-first behavior in case of R/W conflicts at the same address.
* - Output registers are reset synchronously.
*
* Parameters:
* - DATA_WIDTH: Width of each data word.
* - BUFFER_DEPTH: Number of words that can be stored.
**********************************************************************************/
module fft_working_ram #(
    parameter DATA_WIDTH   = 48,
    parameter BUFFER_DEPTH = 512
) (
    // Global Signals
    input wire                      clk,
    input wire                      reset, // Synchronous reset

    // Port A
    input wire [$clog2(BUFFER_DEPTH)-1:0] i_addr_a,
    input wire [DATA_WIDTH-1:0]     i_data_a,
    input wire                      i_wr_en_a,
    output wire [DATA_WIDTH-1:0]    o_data_a,

    // Port B
    input wire [$clog2(BUFFER_DEPTH)-1:0] i_addr_b,
    input wire [DATA_WIDTH-1:0]     i_data_b,
    input wire                      i_wr_en_b,
    output wire [DATA_WIDTH-1:0]    o_data_b
);

    // RAM Memory Array
    reg [DATA_WIDTH-1:0] ram_memory [0:BUFFER_DEPTH-1];

    // Output Registers
    reg [DATA_WIDTH-1:0] reg_data_out_a;
    reg [DATA_WIDTH-1:0] reg_data_out_b;

    // Port A Logic
    always @(posedge clk) begin
        if (reset) begin
            reg_data_out_a <= 0;
        end else begin
            // Data is recorded, if i_wr_en_a is active on the same address, this captures the *old* value (read-first behavior).
            reg_data_out_a <= ram_memory[i_addr_a];
            
            // Write Operation
            if (i_wr_en_a) begin
                ram_memory[i_addr_a] <= i_data_a;
            end
        end
    end

    // port B Logic
    always @(posedge clk) begin
        if (reset) begin
            reg_data_out_b <= 0;
        end else begin
            // Read
            reg_data_out_b <= ram_memory[i_addr_b];

            // Write
            if (i_wr_en_b) begin
                ram_memory[i_addr_b] <= i_data_b;
            end
        end
    end

    // Output Assignments
    assign o_data_a = reg_data_out_a;
    assign o_data_b = reg_data_out_b;

endmodule