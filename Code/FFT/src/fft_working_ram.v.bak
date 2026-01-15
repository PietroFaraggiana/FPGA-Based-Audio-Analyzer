/************************************************************************************
* Module: fft_working_ram
* Description:
* Implements a synchronous dual-port RAM. Due to problems inferring M4k blocks the line (* ramstyle = "no_rw_check" *) was used.
**********************************************************************************/
module fft_working_ram #(
    parameter DATA_WIDTH = 48,
    parameter BUFFER_DEPTH = 512
) (
    input wire clk,

    // Port A
    input wire [$clog2(BUFFER_DEPTH)-1:0] i_addr_a, //$clog2 calculates the log2 at compile time
    input wire [DATA_WIDTH-1:0] i_data_a,
    input wire i_wr_en_a,
    output reg [DATA_WIDTH-1:0] o_data_a,
    input wire [$clog2(BUFFER_DEPTH)-1:0] i_addr_b,
    input wire [DATA_WIDTH-1:0] i_data_b,
    input wire i_wr_en_b,
    output reg [DATA_WIDTH-1:0] o_data_b
);
    // RAM memory declaration
    reg [DATA_WIDTH-1:0] ram_memory [0:BUFFER_DEPTH-1];
    // Port A
    always @(posedge clk) begin
        if (i_wr_en_a) begin
            ram_memory[i_addr_a] <= i_data_a;
        end
        o_data_a <= ram_memory[i_addr_a];
    end

    // Port B
    always @(posedge clk) begin
        if (i_wr_en_b) begin
            ram_memory[i_addr_b] <= i_data_b;
        end
        o_data_b <= ram_memory[i_addr_b];
    end

endmodule