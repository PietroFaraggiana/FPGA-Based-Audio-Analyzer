/*******************************************************************************
 * Module: lp_cic_filter
 * Description: Implements a 2nd Order CIC Filter with decimation 512 (BUFFER_DEPTH)
 * Internal Precision 60 bits (to prevent overflow)
 * H(z) = ((1 - z^-R)/(1 - z^-1))^N
 * Integrators at fs, Combs at fs/R.
*******************************************************************************/

module lp_cic_filter #(
    parameter BUFFER_DEPTH = 512, // Decimation Factor (R)
    parameter DATA_WIDTH = 42 
)(
    input wire clk,
    input wire reset,
    input wire signed [DATA_WIDTH-1:0] phase_in,
    input wire signed [DATA_WIDTH-1:0] quadrature_in,
    input wire [$clog2(BUFFER_DEPTH)-1:0] addr_in,
    input wire valid_in,
    output reg signed [DATA_WIDTH-1:0] phase_out,
    output reg signed [DATA_WIDTH-1:0] quadrature_out,
    output reg valid_out
);

    // Bit width calculations
    // Order N = 2, Decimation R = 512 (clog2 512=9)
    // Bit growth = 2 * 9 = 18
    // Internal width = 42 + 18 = 60 bits.
    localparam GROWTH_BITS = 2 * $clog2(BUFFER_DEPTH);
    localparam INTERNAL_WIDTH = DATA_WIDTH + GROWTH_BITS;
    // Integrator stages
    reg signed [INTERNAL_WIDTH-1:0] int1_phase, int2_phase;
    reg signed [INTERNAL_WIDTH-1:0] int1_quad, int2_quad;
    // Comb stages (delayed)
    reg signed [INTERNAL_WIDTH-1:0] comb1_phase_d, comb2_phase_d;
    reg signed [INTERNAL_WIDTH-1:0] comb1_quad_d, comb2_quad_d;
    // Temp variables
    reg signed [INTERNAL_WIDTH-1:0] diff_phase_stg1, diff_phase_stg2;
    reg signed [INTERNAL_WIDTH-1:0] diff_quad_stg1, diff_quad_stg2;

    always @(posedge clk) begin
        if (reset) begin
            // Reset integrators
            int1_phase <= {INTERNAL_WIDTH{1'b0}};
            int2_phase <= {INTERNAL_WIDTH{1'b0}};
            int1_quad <= {INTERNAL_WIDTH{1'b0}};
            int2_quad <= {INTERNAL_WIDTH{1'b0}};
            // Reset comb delays
            comb1_phase_d <= {INTERNAL_WIDTH{1'b0}};
            comb2_phase_d <= {INTERNAL_WIDTH{1'b0}};
            comb1_quad_d <= {INTERNAL_WIDTH{1'b0}};
            comb2_quad_d <= {INTERNAL_WIDTH{1'b0}};
            // Reset outputs
            phase_out <= {DATA_WIDTH{1'b0}};
            quadrature_out<= {DATA_WIDTH{1'b0}};
            valid_out <= 1'b0;
        end else begin
            valid_out <= 1'b0;

            // Integrator stage
            if (valid_in) begin
                int1_phase <= int1_phase + phase_in;
                int2_phase <= int2_phase + int1_phase;
                int1_quad <= int1_quad + quadrature_in;
                int2_quad <= int2_quad + int1_quad;
            end
            // Comb stage and decimation
            if (valid_in && (addr_in == BUFFER_DEPTH - 1)) begin
                // Phase math
                diff_phase_stg1 = int2_phase - comb1_phase_d;
                comb1_phase_d <= int2_phase;
                diff_phase_stg2 = diff_phase_stg1 - comb2_phase_d;
                comb2_phase_d <= diff_phase_stg1;
                // Remove bit growth for output
                phase_out <= diff_phase_stg2 >>> GROWTH_BITS;
                // Quadrature math
                diff_quad_stg1 = int2_quad - comb1_quad_d;
                comb1_quad_d <= int2_quad;
                diff_quad_stg2 = diff_quad_stg1 - comb2_quad_d;
                comb2_quad_d <= diff_quad_stg1;
                quadrature_out <= diff_quad_stg2 >>> GROWTH_BITS;
                valid_out <= 1'b1;
            end
        end
    end
endmodule