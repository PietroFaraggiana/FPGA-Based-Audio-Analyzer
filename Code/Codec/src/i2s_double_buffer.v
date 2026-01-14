/************************************************************************************
* Module: i2s_double_buffer
*
* Description: Implements a double buffering mechanism for audio samples.
* While one buffer is being filled with new data (by I2S), the other
* is available read-only to a processing unit (lock-in, FFT).
* When the write buffer is full, the roles of the two buffers are swapped.
***********************************************************************************/
module i2s_double_buffer #(
    parameter DATA_WIDTH = 24,
    parameter BUFFER_DEPTH = 512
) (
    input wire clk,
    input wire reset,
    input wire i_audio_valid,
    input wire [DATA_WIDTH-1:0] i_audio_data,
    input wire [$clog2(BUFFER_DEPTH)-1:0] i_read_addr,
    output reg [DATA_WIDTH-1:0] o_data_out,
    output wire o_data_ready
);

    localparam ADDR_WIDTH = $clog2(BUFFER_DEPTH);

    // Single memory buffer, dual bank
    reg [DATA_WIDTH-1:0] mem_buffer [0:(BUFFER_DEPTH*2)-1];

    // Registers for write and read control
    reg [ADDR_WIDTH-1:0] write_addr;
    reg write_buffer_sel; // 0 o 1 (Bank select)
    reg read_buffer_sel;
    reg o_data_ready_reg;

    // Write logic
    always @(posedge clk) begin
        if (reset) begin
            write_addr <= {ADDR_WIDTH{1'b0}};
            write_buffer_sel <= 1'b0;
            read_buffer_sel <= 1'b1;
            o_data_ready_reg <= 1'b0;
        end else begin
            o_data_ready_reg <= 1'b0; // Default
            // New sample arrives
            if (i_audio_valid) begin
                mem_buffer[{write_buffer_sel, write_addr}] <= i_audio_data;
                // Increment address or swap buffers if full
                if (write_addr == BUFFER_DEPTH[ADDR_WIDTH-1:0] - 1'b1) begin
                    write_addr <= {ADDR_WIDTH{1'b0}};
                    write_buffer_sel <= ~write_buffer_sel;
                    read_buffer_sel <= write_buffer_sel;
                    o_data_ready_reg <= 1'b1;
                end else begin
                    write_addr <= write_addr + 1'b1;
                end
            end
        end
    end

    // Read logic
    always @(posedge clk) begin
        o_data_out <= mem_buffer[{read_buffer_sel, i_read_addr}];
    end

    assign o_data_ready = o_data_ready_reg;

endmodule