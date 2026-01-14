/*******************************************************************************
 * Module: lockin_controller
 * Description: FSM for the lock-in submodule. Reads data from the double buffer,
 * controls the DDFS, feeds Data and Sin/Cos to the mixer, captures Mixer output
 * and sends it to the LP Filter.
 *******************************************************************************/

module lockin_controller #(
    parameter BUFFER_DEPTH = 512,
    parameter DATA_WIDTH = 24,
    parameter FREQUENCY_SIZE_IN = 13,
    parameter FREQUENCY_SIZE_OUT = 16,
    parameter SIN_WIDTH = 18
) (
    input wire clk,
    input wire reset,
    input wire [FREQUENCY_SIZE_IN-1:0] tuning_word_in,
    output reg [FREQUENCY_SIZE_OUT-1:0] ddfs_tuning_word,
    // Input Buffer Interface
    input wire buffer_ready, 
    output reg [$clog2(BUFFER_DEPTH)-1:0] buffer_addr,
    input wire [DATA_WIDTH-1:0] buffer_data,
    // Mixer Interface
    output reg mixer_start_en,
    output reg signed [DATA_WIDTH-1:0] mixer_data_in,
    output reg signed [SIN_WIDTH-1:0] mixer_sine_in,
    output reg signed [SIN_WIDTH-1:0] mixer_cosine_in,
    // Inputs FROM Mixer
    input wire signed [(DATA_WIDTH + SIN_WIDTH)-1:0] mixer_phase_out,
    input wire signed [(DATA_WIDTH + SIN_WIDTH)-1:0] mixer_quadrature_out,
    input wire mixer_valid_out,
    // LP Filter Interface
    output reg signed [(DATA_WIDTH + SIN_WIDTH)-1:0] cic_phase_in, 
    output reg signed [(DATA_WIDTH + SIN_WIDTH)-1:0] cic_quadrature_in, 
    output reg [$clog2(BUFFER_DEPTH)-1:0] cic_addr_in, 
    output reg cic_valid_in, 
    // DDFS Interface
    output reg ddfs_sample_en,
    input wire ddfs_valid_out,
    input wire signed [SIN_WIDTH-1:0] ddfs_sine_out,
    input wire signed [SIN_WIDTH-1:0] ddfs_cosine_out
);

    // Internal Width for Mixer Results
    localparam MIXER_OUT_WIDTH = DATA_WIDTH + SIN_WIDTH;
    // State Machine
    localparam S_IDLE = 3'd0;
    localparam S_FETCH = 3'd1;
    localparam S_WAIT_DATA = 3'd2;
    localparam S_MIX_START = 3'd3;
    localparam S_WAIT_MIX = 3'd4;
    localparam S_OUTPUT = 3'd5;
    reg [2:0] state;
    reg [$clog2(BUFFER_DEPTH)-1:0] sample_counter;
    always @(posedge clk) begin
        if (reset) begin
            state <= S_IDLE;
            sample_counter <= 'd0;
            buffer_addr <= 'd0;
            ddfs_sample_en <= 1'b0;
            mixer_start_en <= 1'b0;
            cic_valid_in <= 1'b0;
            ddfs_tuning_word <= 'd0;
            mixer_data_in <= 'd0;
            mixer_sine_in <= 'd0;
            mixer_cosine_in <= 'd0;
            cic_phase_in <= 'd0;
            cic_quadrature_in <= 'd0;
            cic_addr_in <= 'd0;
        end else begin
            ddfs_sample_en <= 1'b0;
            mixer_start_en <= 1'b0;
            cic_valid_in <= 1'b0;

            case (state)
                S_IDLE: begin
                    // Initialize and wait for buffer to be ready
                    sample_counter <= 'd0;
                    if (buffer_ready) begin
                        // 16 bit tuning word for DDFS
                        ddfs_tuning_word <= { {(FREQUENCY_SIZE_OUT-FREQUENCY_SIZE_IN){1'b0}}, tuning_word_in };
                        state <= S_FETCH;
                    end
                end

                S_FETCH: begin
                    // Read data from buffer address
                    buffer_addr <= sample_counter;
                    ddfs_sample_en <= 1'b1;
                    state <= S_WAIT_DATA;
                end

                S_WAIT_DATA: begin
                    // Wait for DDFS to be valid
                    if (ddfs_valid_out) begin
                        state <= S_MIX_START;
                    end
                end

                S_MIX_START: begin
                    // Provide data to mixer and start
                    mixer_data_in <= buffer_data;
                    mixer_sine_in <= ddfs_sine_out;
                    mixer_cosine_in <= ddfs_cosine_out;
                    mixer_start_en <= 1'b1;
                    state <= S_WAIT_MIX;
                end

                S_WAIT_MIX: begin
                    // Wait for mixer output to be valid
                    if (mixer_valid_out) begin
                        cic_phase_in <= mixer_phase_out;
                        cic_quadrature_in <= mixer_quadrature_out;
                        cic_addr_in <= sample_counter;
                        cic_valid_in <= 1'b1;
                        state <= S_OUTPUT;
                    end
                end

                S_OUTPUT: begin
                    // Check if all samples have been processed
                    if (sample_counter == BUFFER_DEPTH - 1'b1) begin
                        state <= S_IDLE;
                    end else begin
                        sample_counter <= sample_counter + 1'b1;
                        state <= S_FETCH;
                    end
                end
                
                default: state <= S_IDLE;
            endcase
        end
    end

endmodule