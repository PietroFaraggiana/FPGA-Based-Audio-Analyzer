module fft_controller #(
    parameter FFT_POINTS     = 512,
    parameter DATA_WIDTH     = 24,
    parameter TWIDDLE_WIDTH  = 24
) (
    // Global Signals
    input wire                      clk,
    input wire                      reset, // Sincronous Active High Reset

    // Interfaces

    // Double Buffer Interface
    input wire                      i_data_ready,
    output reg [$clog2(FFT_POINTS)-1:0] o_buffer_read_addr, 
    input wire [DATA_WIDTH-1:0]     i_buffer_data_in,

    // Working RAM Interface
    output reg [$clog2(FFT_POINTS)-1:0] o_ram_addr_a,      
    output reg [DATA_WIDTH*2-1:0]       o_ram_data_in_a,   
    output reg                          o_ram_wr_en_a,     
    input wire [DATA_WIDTH*2-1:0]       i_ram_data_out_a,

    output reg [$clog2(FFT_POINTS)-1:0] o_ram_addr_b,      
    output reg [DATA_WIDTH*2-1:0]       o_ram_data_in_b,   
    output reg                          o_ram_wr_en_b,     
    input wire [DATA_WIDTH*2-1:0]       i_ram_data_out_b,

    // Twiddle Factor ROM Interface
    output reg [$clog2(FFT_POINTS)-1:0] o_twiddle_addr,    
    input wire [TWIDDLE_WIDTH*2-1:0]    i_twiddle_factor,

    // FFT Butterfly Interface
    output reg                          o_butterfly_start, 
    input wire                          i_butterfly_valid,
    input wire [DATA_WIDTH*2-1:0]       i_butterfly_a_out,
    input wire [DATA_WIDTH*2-1:0]       i_butterfly_b_out,
    
    // Magnitude Approximator Interface
    output reg                          o_magnitude_start, 
    input wire                          i_magnitude_valid,
    input wire [DATA_WIDTH-1:0]         i_magnitude_in,
    output wire [DATA_WIDTH-1:0]        o_magnitude_out,

    // Global Status Outputs
    output wire                     o_fft_busy,
    output wire                     o_fft_done
);

    localparam LOG2_FFT_POINTS = $clog2(FFT_POINTS);

    // State Encoding
    localparam S_IDLE                   = 5'd0;
    localparam S_LOAD_SAMPLES           = 5'd1;
    localparam S_COMPUTE_INIT           = 5'd2;
    localparam S_COMPUTE_READ_ADDR      = 5'd3;
    localparam S_COMPUTE_START_BFY      = 5'd4;
    localparam S_COMPUTE_WAIT_VALID     = 5'd5;
    localparam S_COMPUTE_WRITE          = 5'd6;
    localparam S_MAG_READ_ADDR          = 5'd7;
    localparam S_MAG_START_CALC         = 5'd8;
    localparam S_MAG_WAIT_VALID         = 5'd9;
    localparam S_MAG_OUTPUT             = 5'd10;
    localparam S_DONE                   = 5'd11;

    reg [4:0] state_reg, state_next;

    // Counters 
    reg [LOG2_FFT_POINTS-1:0]   load_counter_reg, load_counter_next;
    reg [LOG2_FFT_POINTS-1:0]   stage_reg, stage_next;
    reg [LOG2_FFT_POINTS-1:0]   group_idx_reg, group_idx_next;
    reg [LOG2_FFT_POINTS-1:0]   bfly_idx_reg, bfly_idx_next;
    
    reg [LOG2_FFT_POINTS-1:0]   addr_a_reg, addr_b_reg; 

    // Address Calculation Logic
    wire [LOG2_FFT_POINTS-1:0] m_half;
    wire [LOG2_FFT_POINTS-1:0] m;
    wire [LOG2_FFT_POINTS-1:0] addr_a, addr_b;
    wire [LOG2_FFT_POINTS-1:0] twiddle_addr;

    // m and m/2 calculation
    assign m_half = 1'b1 << stage_reg;       
    assign m      = 1'b1 << (stage_reg + 1); 

    assign addr_a = (group_idx_reg * m) + bfly_idx_reg;
    assign addr_b = addr_a + m_half;
    assign twiddle_addr = bfly_idx_reg * (FFT_POINTS >> (stage_reg + 1)); // FFT_POINTS / m

    // Loop limits
    // Not localparams because depend on stage_reg
    wire [LOG2_FFT_POINTS-1:0] num_groups;
    wire [LOG2_FFT_POINTS-1:0] bfly_per_group;
    
    assign num_groups     = 1'b1 << (LOG2_FFT_POINTS - 1 - stage_reg);
    assign bfly_per_group = 1'b1 << stage_reg;

    // Sequential Logic
    always @(posedge clk) begin
        if (reset) begin 
            state_reg        <= S_IDLE;
            load_counter_reg <= 0;
            stage_reg        <= 0;
            group_idx_reg    <= 0;
            bfly_idx_reg     <= 0;
            addr_a_reg       <= 0;
            addr_b_reg       <= 0;
        end else begin
            state_reg        <= state_next;
            load_counter_reg <= load_counter_next;
            stage_reg        <= stage_next;
            group_idx_reg    <= group_idx_next;
            bfly_idx_reg     <= bfly_idx_next;

            if (state_reg == S_COMPUTE_START_BFY) begin
                addr_a_reg <= addr_a;
                addr_b_reg <= addr_b;
            end
        end
    end
    
    // Bit Reversal Logic
    wire [LOG2_FFT_POINTS-1:0] bit_reversed_addr;
    genvar i;
    generate
        for (i = 0; i < LOG2_FFT_POINTS; i = i + 1) begin : bit_rev_gen
            assign bit_reversed_addr[i] = load_counter_reg[LOG2_FFT_POINTS-1-i];
        end
    endgenerate

    // Combinational logic
    always @(*) begin
        state_next          = state_reg;
        load_counter_next   = load_counter_reg;
        stage_next          = stage_reg;
        group_idx_next      = group_idx_reg;
        bfly_idx_next       = bfly_idx_reg;

        o_buffer_read_addr  = load_counter_reg;
        o_ram_addr_a        = 0;
        o_ram_data_in_a     = 0;
        o_ram_wr_en_a       = 1'b0;
        o_ram_addr_b        = 0;
        o_ram_data_in_b     = 0;
        o_ram_wr_en_b       = 1'b0;
        o_twiddle_addr      = 0;
        o_butterfly_start   = 1'b0;
        o_magnitude_start   = 1'b0;
        
        case (state_reg)
            S_IDLE: begin
                if (i_data_ready) begin
                    state_next = S_LOAD_SAMPLES;
                    load_counter_next = 0;
                end
            end

            S_LOAD_SAMPLES: begin
                o_ram_wr_en_a   = 1'b1;
                o_ram_addr_a    = bit_reversed_addr;
                o_ram_data_in_a = {i_buffer_data_in, {DATA_WIDTH{1'b0}}};
                
                if (load_counter_reg == FFT_POINTS - 1) begin
                    state_next = S_COMPUTE_INIT;
                end else begin
                    load_counter_next = load_counter_reg + 1;
                end
            end

            S_COMPUTE_INIT: begin
                state_next      = S_COMPUTE_READ_ADDR;
                stage_next      = 0;
                group_idx_next  = 0;
                bfly_idx_next   = 0;
            end

            S_COMPUTE_READ_ADDR: begin
                o_ram_addr_a        = addr_a;
                o_ram_addr_b        = addr_b;
                o_twiddle_addr      = twiddle_addr;
                state_next          = S_COMPUTE_START_BFY;
            end
            
            S_COMPUTE_START_BFY: begin
                o_butterfly_start   = 1'b1;
                state_next          = S_COMPUTE_WAIT_VALID;
            end
            
            S_COMPUTE_WAIT_VALID: begin
                if(i_butterfly_valid) begin
                    state_next = S_COMPUTE_WRITE;
                end
            end

            S_COMPUTE_WRITE: begin
                o_ram_wr_en_a   = 1'b1;
                o_ram_wr_en_b   = 1'b1;
                o_ram_addr_a    = addr_a_reg;
                o_ram_addr_b    = addr_b_reg;
                o_ram_data_in_a = i_butterfly_a_out;
                o_ram_data_in_b = i_butterfly_b_out;

                if (stage_reg == LOG2_FFT_POINTS - 1 && group_idx_reg == num_groups - 1 && bfly_idx_reg == bfly_per_group - 1) begin
                    state_next = S_MAG_READ_ADDR;
                    load_counter_next = 0; 
                end else if (group_idx_reg == num_groups - 1 && bfly_idx_reg == bfly_per_group - 1) begin
                    state_next = S_COMPUTE_READ_ADDR;
                    stage_next = stage_reg + 1;
                    group_idx_next = 0;
                    bfly_idx_next = 0;
                end else if (bfly_idx_reg == bfly_per_group - 1) begin
                    state_next = S_COMPUTE_READ_ADDR;
                    group_idx_next = group_idx_reg + 1;
                    bfly_idx_next = 0;
                end else begin
                    state_next = S_COMPUTE_READ_ADDR;
                    bfly_idx_next = bfly_idx_reg + 1;
                end
            end
            
            S_MAG_READ_ADDR: begin
                o_ram_addr_a = load_counter_reg;
                state_next   = S_MAG_START_CALC;
            end

            S_MAG_START_CALC: begin
                o_magnitude_start = 1'b1;
                state_next        = S_MAG_WAIT_VALID;
            end
            
            S_MAG_WAIT_VALID: begin
                if(i_magnitude_valid) begin
                    state_next = S_MAG_OUTPUT;
                end
            end
            
            S_MAG_OUTPUT: begin
                if(load_counter_reg == FFT_POINTS - 1) begin
                    state_next = S_DONE;
                end else begin
                    load_counter_next = load_counter_reg + 1;
                    state_next = S_MAG_READ_ADDR;
                end
            end

            S_DONE: begin
                state_next = S_IDLE;
            end

            default: begin
                state_next = S_IDLE;
            end
        endcase
    end
    
    // Output Assignments
    assign o_fft_busy = (state_reg != S_IDLE);
    assign o_fft_done = (state_reg == S_DONE);
    assign o_magnitude_out = i_magnitude_in;

endmodule