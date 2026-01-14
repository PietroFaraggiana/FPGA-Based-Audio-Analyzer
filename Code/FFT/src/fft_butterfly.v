/*******************************************************************************
* Module: fft_butterfly
*
* Description:
* Computational module for a Radix-2 FFT Butterfly (DIT - Decimation In Time).
* Performs operations: 
* A' = (A + B) / 2
* B' = ((A - B) * W) / 2
* 3-Stage Pipeline for high frequency.
* Round-to-nearest in complex multiplication (improves Audio SNR).
* Divides by 2 to prevent overflow.
*******************************************************************************/
module fft_butterfly #(
    parameter DATA_WIDTH = 24,
    parameter TWIDDLE_WIDTH = 24
) (
    input wire clk,
    input wire reset,
    input wire i_start, // flag to indicate valid input data
    input wire signed [DATA_WIDTH*2-1:0] i_data_a, // Complex input A (Real and Imaginary parts concatenated) 
    input wire signed [DATA_WIDTH*2-1:0] i_data_b, // Complex input B (Real and Imaginary parts concatenated)
    input wire signed [TWIDDLE_WIDTH*2-1:0] i_twiddle, // Twiddle factor W (Real and Imaginary parts concatenated)
    output wire signed [DATA_WIDTH*2-1:0] o_data_a_out, // Complex output A' (Real and Imaginary parts concatenated)
    output wire signed [DATA_WIDTH*2-1:0] o_data_b_out, // Complex output B' (Real and Imaginary parts concatenated)
    output wire o_valid // flag to indicate valid output data
);

    localparam PRODUCT_WIDTH = DATA_WIDTH + TWIDDLE_WIDTH; // Width after multiplication

    wire signed [DATA_WIDTH-1:0] a_re = i_data_a[DATA_WIDTH*2-1 -: DATA_WIDTH]; // real A
    wire signed [DATA_WIDTH-1:0] a_im = i_data_a[DATA_WIDTH-1 -: DATA_WIDTH]; // imag A

    wire signed [DATA_WIDTH-1:0] b_re = i_data_b[DATA_WIDTH*2-1 -: DATA_WIDTH]; // real B
    wire signed [DATA_WIDTH-1:0] b_im = i_data_b[DATA_WIDTH-1 -: DATA_WIDTH]; // imag B

    wire signed [TWIDDLE_WIDTH-1:0] w_re = i_twiddle[TWIDDLE_WIDTH*2-1 -: TWIDDLE_WIDTH]; // real W
    wire signed [TWIDDLE_WIDTH-1:0] w_im = i_twiddle[TWIDDLE_WIDTH-1 -: TWIDDLE_WIDTH]; // imag W

    // Pipeline Registers 
    // Pipeline 1 input registration
    reg signed [DATA_WIDTH-1:0] p1_a_re, p1_a_im;
    reg signed [DATA_WIDTH-1:0] p1_b_re, p1_b_im;
    reg signed [TWIDDLE_WIDTH-1:0] p1_w_re, p1_w_im;
    reg p1_valid; // flag

    // Pipeline 2 complex multiplication results rounded
    reg signed [DATA_WIDTH-1:0] p2_prod_re, p2_prod_im;
    reg signed [DATA_WIDTH-1:0] p2_a_re, p2_a_im;
    reg p2_valid; // flag
    
    // Pipeline 3 butterfly outputs
    reg signed [DATA_WIDTH*2-1:0] p3_a_out, p3_b_out;
    reg p3_valid; // flag

    // Pipeline logic
    // #1
    always @(posedge clk) begin
        if (reset) begin
            p1_valid <= 1'b0;
            p1_a_re <= {DATA_WIDTH{1'b0}}; p1_a_im <= {DATA_WIDTH{1'b0}};
            p1_b_re <= {DATA_WIDTH{1'b0}}; p1_b_im <= {DATA_WIDTH{1'b0}};
            p1_w_re <= {TWIDDLE_WIDTH{1'b0}}; p1_w_im <= {TWIDDLE_WIDTH{1'b0}};
        end else begin
            p1_valid <= i_start;
            if (i_start) begin
                p1_a_re <= a_re;
                p1_a_im <= a_im;
                p1_b_re <= b_re;
                p1_b_im <= b_im;
                p1_w_re <= w_re;
                p1_w_im <= w_im;
            end
        end
    end
    //#2 
    // (b_re + j b_im) * (w_re + j w_im)
    wire signed [PRODUCT_WIDTH-1:0] term1 = p1_b_re * p1_w_re;
    wire signed [PRODUCT_WIDTH-1:0] term2 = p1_b_im * p1_w_im;
    wire signed [PRODUCT_WIDTH-1:0] term3 = p1_b_re * p1_w_im;
    wire signed [PRODUCT_WIDTH-1:0] term4 = p1_b_im * p1_w_re;
    wire signed [PRODUCT_WIDTH-1:0] prod_re_full = term1 - term2;
    wire signed [PRODUCT_WIDTH-1:0] prod_im_full = term3 + term4;

    // We shift right by (TWIDDLE_WIDTH-1) to return to the original format.
    // To round to nearest, we add half of the LSB weight (1 << (SHIFT-1)) before shifting.
    localparam SHIFT_VAL = TWIDDLE_WIDTH - 1;
    wire signed [PRODUCT_WIDTH-1:0] round_const = 1'b1 <<< (SHIFT_VAL - 1);
    wire signed [DATA_WIDTH-1:0] prod_re_scaled = (prod_re_full + round_const) >>> SHIFT_VAL;
    wire signed [DATA_WIDTH-1:0] prod_im_scaled = (prod_im_full + round_const) >>> SHIFT_VAL;

    always @(posedge clk) begin
        if (reset) begin
            p2_valid <= 1'b0;
            p2_a_re <= {DATA_WIDTH{1'b0}}; p2_a_im <= {DATA_WIDTH{1'b0}};
            p2_prod_re <= {DATA_WIDTH{1'b0}}; p2_prod_im <= {DATA_WIDTH{1'b0}};
        end else begin
            p2_valid <= p1_valid; //append previous valid flag
            if (p1_valid) begin
                p2_a_re <= p1_a_re;
                p2_a_im <= p1_a_im;
                p2_prod_re <= prod_re_scaled;
                p2_prod_im <= prod_im_scaled;
            end
        end
    end

    // #3
    // A' = A + (B*W)/2, B' = A - (B*W)/2
    // Addition on DATA_WIDTH+1 bits to prevent loosing onformation, then drop the LSB to divide by 2.
    wire signed [DATA_WIDTH:0] sum_re = {p2_a_re[DATA_WIDTH-1], p2_a_re} + {p2_prod_re[DATA_WIDTH-1], p2_prod_re};
    wire signed [DATA_WIDTH:0] sum_im = {p2_a_im[DATA_WIDTH-1], p2_a_im} + {p2_prod_im[DATA_WIDTH-1], p2_prod_im};  
    wire signed [DATA_WIDTH:0] diff_re = {p2_a_re[DATA_WIDTH-1], p2_a_re} - {p2_prod_re[DATA_WIDTH-1], p2_prod_re};
    wire signed [DATA_WIDTH:0] diff_im = {p2_a_im[DATA_WIDTH-1], p2_a_im} - {p2_prod_im[DATA_WIDTH-1], p2_prod_im};

    always @(posedge clk) begin
        if (reset) begin
            p3_valid <= 1'b0;
            p3_a_out <= {(DATA_WIDTH*2){1'b0}};
            p3_b_out <= {(DATA_WIDTH*2){1'b0}};
        end else begin
            p3_valid <= p2_valid;
            if (p2_valid) begin
                p3_a_out <= {sum_re[DATA_WIDTH:1], sum_im[DATA_WIDTH:1]};
                p3_b_out <= {diff_re[DATA_WIDTH:1], diff_im[DATA_WIDTH:1]};
            end
        end
    end
    
    // Output Assignment
    assign o_data_a_out = p3_a_out;
    assign o_data_b_out = p3_b_out;
    assign o_valid = p3_valid;

endmodule