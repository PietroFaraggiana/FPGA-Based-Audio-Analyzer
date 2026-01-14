/*******************************************************************************
 * Module: lockin_math_top
 *******************************************************************************/

module lockin_math_top #(
    parameter BUFFER_DEPTH = 512,
    parameter DATA_WIDTH = 24,
    parameter SIN_WIDTH = 18,
    parameter CORDIC_WIDTH = 42,
    parameter FREQ_RANGE = 8192
)(
    input wire clk,
    input wire key_0,
    input wire key_1,
    input wire key_2,
    input wire key_3,
    // Buffer
    input wire i_data_ready,
    input wire [DATA_WIDTH-1:0] i_buffer_data,
    output wire [$clog2(BUFFER_DEPTH)-1:0] o_buffer_addr,
    // Frequency control
    output wire [6:0] HEX0, HEX1, HEX2, HEX3,
    output wire [6:0] HEX4, HEX5, HEX6, HEX7,
    // Output
    output wire o_result_valid,
    output wire [CORDIC_WIDTH-1:0] o_magnitude,
    output wire signed [CORDIC_WIDTH-1:0] o_phase
);
    // Internal signals
    wire sys_rst;
    // Frequency controller to Lock-in controller
    wire [12:0] freq_user_select;
    wire [15:0] freq_active_tuning;
    // Lock-in controller to DDFS
    wire ddfs_sample_en;
    wire signed [SIN_WIDTH-1:0] osc_sine;
    wire signed [SIN_WIDTH-1:0] osc_cosine;
    wire osc_valid;
    // Lock-in controller to Mixer
    wire mixer_start;
    wire signed [DATA_WIDTH-1:0] mixer_data_in;
    wire signed [SIN_WIDTH-1:0] mixer_sin_in;
    wire signed [SIN_WIDTH-1:0] mixer_cos_in;
    // Mixer to Lock-in controller
    wire signed [CORDIC_WIDTH-1:0] mixer_res_phase;
    wire signed [CORDIC_WIDTH-1:0] mixer_res_quad;
    wire mixer_res_valid;
    // Lock-in controller to LP filter
    wire signed [CORDIC_WIDTH-1:0] filter_in_phase;
    wire signed [CORDIC_WIDTH-1:0] filter_in_quad;
    wire [$clog2(BUFFER_DEPTH)-1:0] filter_addr_ref;
    wire filter_in_valid;
    // LP filter to CORDIC
    wire signed [CORDIC_WIDTH-1:0] cordic_in_I;
    wire signed [CORDIC_WIDTH-1:0] cordic_in_Q;
    wire cordic_in_valid;

    // Module instantiations
    frequency_controller_top #(
        .FREQUENCY_RANGE(FREQ_RANGE),
        .W(13)
    ) u_frequency_controller_top (
        .clk (clk),
        .key_0 (key_0),
        .key_1 (key_1),
        .key_2 (key_2),
        .key_3 (key_3),
        .reset_active (sys_rst),
        .frequency_out (freq_user_select),
        .HEX0(HEX0), .HEX1(HEX1), .HEX2(HEX2), .HEX3(HEX3),
        .HEX4(HEX4), .HEX5(HEX5), .HEX6(HEX6), .HEX7(HEX7)
    );

    lockin_controller #(
        .BUFFER_DEPTH (BUFFER_DEPTH),
        .DATA_WIDTH (DATA_WIDTH),
        .FREQUENCY_SIZE_IN (13),
        .FREQUENCY_SIZE_OUT(16),
        .SIN_WIDTH (SIN_WIDTH)
    ) u_lockin_controller (
        .clk (clk),
        .reset (sys_rst),
        .tuning_word_in (freq_user_select),
        .ddfs_tuning_word (freq_active_tuning),
        .buffer_ready (i_data_ready),
        .buffer_addr (o_buffer_addr),
        .buffer_data (i_buffer_data),
        .mixer_start_en (mixer_start),
        .mixer_data_in (mixer_data_in),
        .mixer_sine_in (mixer_sin_in),
        .mixer_cosine_in (mixer_cos_in),
        .mixer_phase_out (mixer_res_phase),
        .mixer_quadrature_out (mixer_res_quad),
        .mixer_valid_out (mixer_res_valid),
        .cic_phase_in (filter_in_phase),
        .cic_quadrature_in (filter_in_quad),
        .cic_addr_in (filter_addr_ref),
        .cic_valid_in (filter_in_valid),
        .ddfs_sample_en (ddfs_sample_en),
        .ddfs_valid_out (osc_valid),
        .ddfs_sine_out (osc_sine),
        .ddfs_cosine_out (osc_cosine)
    );

    ddfs_core #(
        .ACC_WIDTH (16),
        .LUT_DEPTH (10),
        .LUT_BITS (SIN_WIDTH)
    ) u_ddfs_core (
        .clk (clk),
        .reset (sys_rst),
        .sample_en (ddfs_sample_en),
        .tuning_word (freq_active_tuning),
        .cosine_out (osc_cosine),
        .sine_out (osc_sine),
        .valid_out (osc_valid)
    );

    mixer #(
        .DATA_WIDTH (DATA_WIDTH),
        .SIN_WIDTH (SIN_WIDTH)
    ) u_mixer (
        .clk (clk),
        .reset (sys_rst),
        .start (mixer_start),
        .data_in (mixer_data_in),
        .sine_in (mixer_sin_in),
        .cosine_in (mixer_cos_in),
        .phase_out (mixer_res_phase),
        .quadrature_out (mixer_res_quad),
        .o_valid (mixer_res_valid)
    );

    lp_cic_filter #(
        .BUFFER_DEPTH (BUFFER_DEPTH),
        .DATA_WIDTH (CORDIC_WIDTH)
    ) u_lp_cic_filter (
        .clk (clk),
        .reset (sys_rst),
        .phase_in (filter_in_phase),
        .quadrature_in (filter_in_quad),
        .addr_in (filter_addr_ref),
        .valid_in (filter_in_valid),
        .phase_out (cordic_in_I),
        .quadrature_out (cordic_in_Q),
        .valid_out (cordic_in_valid)
    );

    cordic #(
        .WIDTH (CORDIC_WIDTH),
        .ITER (CORDIC_WIDTH)
    ) u_cordic (
        .clk (clk),
        .reset (sys_rst),
        .valid_in (cordic_in_valid),
        .I_in (cordic_in_I),
        .Q_in (cordic_in_Q),
        .valid_out (o_result_valid),
        .mag_out (o_magnitude),
        .phase_out (o_phase)
    );

endmodule