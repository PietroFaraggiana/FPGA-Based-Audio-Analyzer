/*******************************************************************************
 * Module: fft_top
 *******************************************************************************/
module fft_top (
    // Clock and Global Reset
    input wire clk,
    input wire reset,
    // Interface towards Audio System
    input wire i_buffer_data_ready,
    input wire signed [23:0] i_buffer_data,
    output wire [8:0] o_buffer_read_addr,
    // FFT Result Interface
    output wire [8:0] o_fft_magnitude_addr,
    output wire [23:0] o_fft_magnitude_out,
    output wire o_fft_out_valid,
    // Status Flags
    output wire o_fft_done_pulse,
    output wire o_fft_busy
);
    // Parameters
    localparam DATA_WIDTH = 32'd24;
    localparam TWIDDLE_WIDTH = 32'd24;
    localparam FFT_POINTS = 32'd512;
    localparam ADDR_WIDTH = 32'd9; // $clog2(512)

    // Internal Signals
    wire [ADDR_WIDTH-1:0] ram_addr_a;
    wire [DATA_WIDTH*2-1:0] ram_data_in_a;
    wire ram_wr_en_a;
    wire [ADDR_WIDTH-1:0] ram_addr_b;
    wire [DATA_WIDTH*2-1:0] ram_data_in_b;
    wire ram_wr_en_b;
    
    wire [DATA_WIDTH*2-1:0] ram_data_out_a;
    wire [DATA_WIDTH*2-1:0] ram_data_out_b;

    wire [ADDR_WIDTH-1:0] twiddle_addr;
    wire [TWIDDLE_WIDTH*2-1:0] twiddle_factor_q;

    wire butterfly_start;
    wire butterfly_valid;
    wire [DATA_WIDTH*2-1:0] butterfly_a_out;
    wire [DATA_WIDTH*2-1:0] butterfly_b_out;

    wire magnitude_start;
    wire magnitude_valid;
    wire [DATA_WIDTH-1:0] magnitude_result;
    wire [DATA_WIDTH-1:0] controller_magnitude_out;

    // Working RAM
    fft_working_ram #(
        .DATA_WIDTH (DATA_WIDTH * 2), 
        .BUFFER_DEPTH (FFT_POINTS)
    ) u_fft_working_ram (
        .clk (clk),
        .i_addr_a (ram_addr_a),
        .i_data_a (ram_data_in_a),
        .i_wr_en_a (ram_wr_en_a),
        .o_data_a (ram_data_out_a),
        .i_addr_b (ram_addr_b),
        .i_data_b (ram_data_in_b),
        .i_wr_en_b (ram_wr_en_b),
        .o_data_b (ram_data_out_b)
    );

    // Twiddle Factor ROM
    twiddle_factor_rom #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (TWIDDLE_WIDTH * 2)
    ) u_twiddle_factor_rom (
        .clk (clk),
        .addr (twiddle_addr),
        .twiddle_factor_q (twiddle_factor_q)
    );

    // Butterfly
    fft_butterfly #(
        .DATA_WIDTH (DATA_WIDTH),
        .TWIDDLE_WIDTH (TWIDDLE_WIDTH)
    ) u_fft_butterfly (
        .clk (clk),
        .reset (reset),
        .i_start (butterfly_start),
        .i_data_a (ram_data_out_a),
        .i_data_b (ram_data_out_b),
        .i_twiddle (twiddle_factor_q),
        .o_data_a_out (butterfly_a_out),
        .o_data_b_out (butterfly_b_out),
        .o_valid (butterfly_valid)
    );

    // Magnitude Approximation
    magnitude_approximator #(
        .DATA_WIDTH (DATA_WIDTH)
    ) u_magnitude_approximator (
        .clk (clk),
        .reset (reset),
        .i_start (magnitude_start),
        .i_fft_complex (ram_data_out_a), 
        .o_magnitude (magnitude_result),
        .o_valid (magnitude_valid)
    );

    // Controller
    fft_controller #(
        .FFT_POINTS (FFT_POINTS),
        .DATA_WIDTH (DATA_WIDTH),
        .TWIDDLE_WIDTH (TWIDDLE_WIDTH)
    ) u_fft_controller (
        .clk (clk),
        .reset (reset),
        
        .i_data_ready (i_buffer_data_ready),
        .o_buffer_read_addr (o_buffer_read_addr),
        .i_buffer_data_in (i_buffer_data),
        
        .o_ram_addr_a (ram_addr_a),
        .o_ram_data_in_a (ram_data_in_a),
        .o_ram_wr_en_a (ram_wr_en_a),
        .i_ram_data_out_a (ram_data_out_a),
        
        .o_ram_addr_b (ram_addr_b),
        .o_ram_data_in_b (ram_data_in_b),
        .o_ram_wr_en_b (ram_wr_en_b),
        .i_ram_data_out_b (ram_data_out_b),
        
        .o_twiddle_addr (twiddle_addr),
        .i_twiddle_factor (twiddle_factor_q),
        
        .o_butterfly_start (butterfly_start),
        .i_butterfly_valid (butterfly_valid),
        .i_butterfly_a_out (butterfly_a_out),
        .i_butterfly_b_out (butterfly_b_out),
        
        .o_magnitude_start (magnitude_start),
        .i_magnitude_valid (magnitude_valid),
        .i_magnitude_in (magnitude_result),
        .o_magnitude_out (controller_magnitude_out),
        
        .o_fft_busy (o_fft_busy),
        .o_fft_done (o_fft_done_pulse)
    );

    assign o_fft_magnitude_addr = ram_addr_a; 
    assign o_fft_magnitude_out = controller_magnitude_out;
    assign o_fft_out_valid = magnitude_valid;

endmodule