/*******************************************************************************
* Module: fft_controller
* 
* Description:
* This module implements the main control logic for a Radix-2, Decimation-In-Time 
* (DIT) FFT processor. It orchestrates data flow between memory and arithmetic units.
*
* The working procedure is divided into three main phases:
* 1. Data Loading & Bit Reversal: Reads sequential time-domain samples from 
*    the input interface and stores them into the Working RAM using bit-reversed 
*    addressing to prepare for in-place computation (DIT).
*
* 2. FFT Execution (Butterfly Loop): Manages the three-loop structure 
*    (Stage, Group, Butterfly) required by the Cooley-Tukey algorithm. 
*    - Generates read/write addresses for the Dual-Port RAM.
*    - Fetches the correct coefficients from the Twiddle Factor ROM.
*    - Handshakes with the external Butterfly Unit (Start/Valid protocol).
*
* 3. Magnitude Post-Processing: Sequentially reads the complex frequency 
*    bins from RAM, passes them to the Magnitude Approximator, and streams 
*    the final real-valued results to the output.
******************************************************************************/
module fft_controller #(
    parameter FFT_POINTS = 512,
    parameter DATA_WIDTH = 24,
    parameter TWIDDLE_WIDTH = 24
) (
    // Global Signals
    input wire clk,
    input wire reset, 
    // Double Buffer Interface
    input wire i_data_ready,
    output reg [$clog2(FFT_POINTS)-1:0] o_buffer_read_addr, 
    input wire [DATA_WIDTH-1:0] i_buffer_data_in,
    // Working RAM Interface
    //Port A
    output reg [$clog2(FFT_POINTS)-1:0] o_ram_addr_a, //address
    output reg [DATA_WIDTH*2-1:0] o_ram_data_in_a, // data in
    output reg o_ram_wr_en_a, // enable write
    input wire [DATA_WIDTH*2-1:0] i_ram_data_out_a, //data out
    //Port B
    output reg [$clog2(FFT_POINTS)-1:0] o_ram_addr_b, //address
    output reg [DATA_WIDTH*2-1:0] o_ram_data_in_b, // data in
    output reg o_ram_wr_en_b, // enable write
    input wire [DATA_WIDTH*2-1:0] i_ram_data_out_b, //data out
    // Twiddle Factor ROM Interface
    output reg [$clog2(FFT_POINTS)-1:0] o_twiddle_addr, // address
    input wire [TWIDDLE_WIDTH*2-1:0] i_twiddle_factor, // data out
    // FFT Butterfly Interface
    output reg o_butterfly_start, // start flag
    input wire i_butterfly_valid, // valid flag
    input wire [DATA_WIDTH*2-1:0] i_butterfly_a_out, // A' output
    input wire [DATA_WIDTH*2-1:0] i_butterfly_b_out, // B' outputs
    // Magnitude Approximator Interface
    output reg o_magnitude_start, // start flag
    input wire i_magnitude_valid, // valid flag
    input wire [DATA_WIDTH-1:0] i_magnitude_in, //complex input
    output wire [DATA_WIDTH-1:0] o_magnitude_out, //magnitude output
    // FSM Output
    output wire o_fft_busy,
    output wire o_fft_done
);

    localparam LOG2_FFT_POINTS = $clog2(FFT_POINTS); // Number of bits to address FFT_POINTS

    // State Encoding
    localparam S_IDLE = 5'd0;
    localparam S_LOAD_READ_REQ = 5'd1;
    localparam S_LOAD_WRITE = 5'd2;
    localparam S_COMPUTE_INIT = 5'd3;
    localparam S_COMPUTE_READ_ADDR = 5'd4;
    localparam S_COMPUTE_START_BFY = 5'd5;
    localparam S_COMPUTE_WAIT_VALID = 5'd6;
    localparam S_COMPUTE_WRITE = 5'd7;
    localparam S_MAG_READ_ADDR = 5'd8;
    localparam S_MAG_START_CALC = 5'd9;
    localparam S_MAG_WAIT_VALID = 5'd10;
    localparam S_MAG_OUTPUT = 5'd11;
    localparam S_DONE = 5'd12;

    reg [4:0] state_reg, state_next;

    reg [LOG2_FFT_POINTS-1:0] load_counter_reg, load_counter_next; //how many data loaded
    reg [LOG2_FFT_POINTS-1:0] stage_reg, stage_next; // Indicates the current FFT alghorithm stage
    reg [LOG2_FFT_POINTS-1:0] group_idx_reg, group_idx_next; // current group inside the stage
    reg [LOG2_FFT_POINTS-1:0] bfly_idx_reg, bfly_idx_next; //current butterfly inside the group
    reg [LOG2_FFT_POINTS-1:0] addr_a_reg, addr_b_reg; // memorizes an address to use i the next cycle


    // Bit reversal logic
    reg [LOG2_FFT_POINTS-1:0] write_counter_reg, write_counter_next; // address for writing with bit reversal
    wire [LOG2_FFT_POINTS-1:0] bit_reversed_write_addr; // bit-reversed address for writing
    
    genvar i; //generate variable
    generate
        for (i = 0; i < LOG2_FFT_POINTS; i = i + 1) begin : bit_rev_gen // i goes from 0 to LOG2_FFT_POINTS-1, every for cycle goes up by 1
            assign bit_reversed_write_addr[i] = write_counter_reg[LOG2_FFT_POINTS-1-i]; //connects bit i of the output to bit LOG2_FFT_POINTS-1-i of the input
        end
    endgenerate

    // Address Calculation Logic
    wire [LOG2_FFT_POINTS-1:0] m_half = 1'b1 << stage_reg; // distance between butterfly's data points
    wire [LOG2_FFT_POINTS-1:0] m = 1'b1 << (stage_reg + 1'b1); // full butterfly span (doube of m_half)

    wire [LOG2_FFT_POINTS-1:0] addr_a = (group_idx_reg * m) + bfly_idx_reg; // Address offset for first data point
    wire [LOG2_FFT_POINTS-1:0] addr_b = addr_a + m_half; // Second data point
    wire [LOG2_FFT_POINTS-1:0] twiddle_addr = bfly_idx_reg * (FFT_POINTS >> (stage_reg + 1'b1)); // Twiddle factor address calculation

    wire [LOG2_FFT_POINTS-1:0] num_groups = 1'b1 << (LOG2_FFT_POINTS - 1 - stage_reg);
    wire [LOG2_FFT_POINTS-1:0] bfly_per_group = 1'b1 << stage_reg;

    // Sequential Logic
    always @(posedge clk) begin
        if (reset) begin 
            state_reg <= S_IDLE;
            load_counter_reg <= {LOG2_FFT_POINTS{1'b0}};
            write_counter_reg <= {LOG2_FFT_POINTS{1'b0}};
            stage_reg <= {LOG2_FFT_POINTS{1'b0}};
            group_idx_reg <= {LOG2_FFT_POINTS{1'b0}};
            bfly_idx_reg <= {LOG2_FFT_POINTS{1'b0}};
            addr_a_reg <= {LOG2_FFT_POINTS{1'b0}};
            addr_b_reg <= {LOG2_FFT_POINTS{1'b0}};
        end else begin
            state_reg <= state_next;
            load_counter_reg <= load_counter_next;
            write_counter_reg<= write_counter_next;
            stage_reg <= stage_next;
            group_idx_reg <= group_idx_next;
            bfly_idx_reg <= bfly_idx_next;

            if (state_reg == S_COMPUTE_START_BFY) begin
                addr_a_reg <= addr_a;
                addr_b_reg <= addr_b;
            end
        end
    end

    // Combinational logic
    always @(*) begin
        // Defaults to prevent latches
        state_next = state_reg;
        load_counter_next = load_counter_reg;
        write_counter_next = write_counter_reg;
        stage_next = stage_reg;
        group_idx_next = group_idx_reg;
        bfly_idx_next = bfly_idx_reg;

        o_buffer_read_addr = {LOG2_FFT_POINTS{1'b0}};
        o_ram_addr_a = {LOG2_FFT_POINTS{1'b0}};
        o_ram_data_in_a = {(DATA_WIDTH*2){1'b0}};
        o_ram_wr_en_a = 1'b0;
        o_ram_addr_b = {LOG2_FFT_POINTS{1'b0}};
        o_ram_data_in_b = {(DATA_WIDTH*2){1'b0}};
        o_ram_wr_en_b = 1'b0;
        o_twiddle_addr = {LOG2_FFT_POINTS{1'b0}};
        o_butterfly_start = 1'b0;
        o_magnitude_start = 1'b0;
        
        case (state_reg)// cases of the current state
            // State 0: Idle
            S_IDLE: begin
                if (i_data_ready) begin
                    state_next = S_LOAD_READ_REQ;
                    load_counter_next = {LOG2_FFT_POINTS{1'b0}}; // Reset load counter
                    write_counter_next = {LOG2_FFT_POINTS{1'b0}}; // Reset write counter
                end
            end

            // State 1: Read request (Pipeline Fill)
            S_LOAD_READ_REQ: begin
                o_buffer_read_addr = load_counter_reg; // find the address to read from buffer (0)
                load_counter_next = load_counter_reg + 1'b1; // increment the load counter
                state_next = S_LOAD_WRITE;
            end

            // State 2: Lettura Pipelined e Scrittura
            S_LOAD_WRITE: begin
                o_buffer_read_addr = load_counter_reg; // prefetch next read
                // write to RAM with bit-reversed address
                o_ram_wr_en_a = 1'b1; 
                o_ram_addr_a = bit_reversed_write_addr;
                o_ram_data_in_a = {i_buffer_data_in, {DATA_WIDTH{1'b0}}}; // Real data from mic concatenated with imaginary part as 0

                // Group write counter increment
                if (write_counter_reg == FFT_POINTS - 1) begin // if all data written
                    state_next = S_COMPUTE_INIT;
                end else begin // else keep writing
                    write_counter_next = write_counter_reg + 1'b1;
                    if (load_counter_reg < FFT_POINTS) begin // continue reading until all data loaded
                        load_counter_next = load_counter_reg + 1'b1;
                    end
                    // Stay in WRITE state to continue writing if not over
                    state_next = S_LOAD_WRITE;
                end
            end
            // State 3: Initialize FFT Computation by resetting 3 nested loops indices
            S_COMPUTE_INIT: begin
                state_next = S_COMPUTE_READ_ADDR;
                stage_next = {LOG2_FFT_POINTS{1'b0}};
                group_idx_next = {LOG2_FFT_POINTS{1'b0}};
                bfly_idx_next = {LOG2_FFT_POINTS{1'b0}};
            end
            // State 4: Read Addresses from working RAM and Twiddle Factor ROM
            S_COMPUTE_READ_ADDR: begin
                o_ram_addr_a = addr_a;
                o_ram_addr_b = addr_b;
                o_twiddle_addr = twiddle_addr;
                state_next = S_COMPUTE_START_BFY;
            end

            // State 5: Start Butterfly computation
            S_COMPUTE_START_BFY: begin
                // Keeps addresses stable during the butterfly computation
                o_ram_addr_a = addr_a; 
                o_ram_addr_b = addr_b;
                o_twiddle_addr = twiddle_addr;
                // Latency of 1 cycle for RAM and ROM outputs to be valid
                o_butterfly_start = 1'b1;
                state_next = S_COMPUTE_WAIT_VALID;
            end
            
            // State 6: Wait for Butterfly valid signal
            S_COMPUTE_WAIT_VALID: begin
                if(i_butterfly_valid) begin
                    state_next = S_COMPUTE_WRITE;
                end
            end

            // State 7: Write Butterfly outputs back to Working RAM
            S_COMPUTE_WRITE: begin
                // Keep addresses stable and write the results
                o_ram_wr_en_a = 1'b1;
                o_ram_wr_en_b = 1'b1;
                o_ram_addr_a = addr_a_reg; 
                o_ram_addr_b = addr_b_reg;
                o_ram_data_in_a = i_butterfly_a_out;
                o_ram_data_in_b = i_butterfly_b_out;
                // Nested loop control
                if (stage_reg == LOG2_FFT_POINTS - 1 && group_idx_reg == num_groups - 1 && bfly_idx_reg == bfly_per_group - 1) begin 
                // Last butterfly of the last group of the last stage?
                    state_next = S_MAG_READ_ADDR;
                    load_counter_next = {LOG2_FFT_POINTS{1'b0}}; 
                end else if (group_idx_reg == num_groups - 1 && bfly_idx_reg == bfly_per_group - 1) begin
                // Last butterfly of the last group of the current stage?
                    state_next = S_COMPUTE_READ_ADDR;
                    stage_next = stage_reg + 1'b1;
                    group_idx_next = {LOG2_FFT_POINTS{1'b0}};
                    bfly_idx_next = {LOG2_FFT_POINTS{1'b0}};
                end else if (bfly_idx_reg == bfly_per_group - 1) begin
                // Last butterfly of the current group?
                    state_next = S_COMPUTE_READ_ADDR;
                    group_idx_next = group_idx_reg + 1'b1;
                    bfly_idx_next = {LOG2_FFT_POINTS{1'b0}};
                end else begin
                // Continue with next butterfly in the current group
                    state_next = S_COMPUTE_READ_ADDR;
                    bfly_idx_next = bfly_idx_reg + 1'b1;
                end
            end
            
            // State 8: Read address for Magnitude calculation
            S_MAG_READ_ADDR: begin
                o_ram_addr_a = load_counter_reg; // pointed at 0 at S_COMPUTE_WRITE
                state_next = S_MAG_START_CALC;
            end

            // State 9: Start Magnitude calculation
            S_MAG_START_CALC: begin
                // Latency of 1 cycle for RAM output to be valid
                o_ram_addr_a = load_counter_reg;
                o_magnitude_start = 1'b1;
                state_next = S_MAG_WAIT_VALID;
            end

            // State 10: Wait for Magnitude valid signal
            S_MAG_WAIT_VALID: begin
                o_ram_addr_a = load_counter_reg;
                if(i_magnitude_valid) begin
                    state_next = S_MAG_OUTPUT;
                end
            end
            
            // State 11: Output Magnitude result and increment address
            S_MAG_OUTPUT: begin
                o_ram_addr_a = load_counter_reg;
                if(load_counter_reg == FFT_POINTS - 1) begin // Last magnitude output?
                    state_next = S_DONE;
                end else begin // Continue outputting magnitudes
                    load_counter_next = load_counter_reg + 1'b1;
                    state_next = S_MAG_READ_ADDR;
                end
            end

            // State 12: FFT Done
            S_DONE: begin
                state_next = S_IDLE;
            end

            default: state_next = S_IDLE;
        endcase
    end
    
    assign o_fft_busy = (state_reg != S_IDLE);
    assign o_fft_done = (state_reg == S_DONE);
    assign o_magnitude_out = i_magnitude_in;

endmodule