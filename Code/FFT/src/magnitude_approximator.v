/************************************************************************************
* Module: magnitude_approximator
*
* Description:
* Computes an approximation of the magnitude of a complex number efficiently for FPGA implementation.
* This is done by using an "alpha max plus beta min" algorithm that avoids the use of complex multipliers or a full CORDIC, saving resources.
* The approximation is calculated as:
* Magnitude = max(|Re|, |Im|) + 0.375 * min(|Re|, |Im|)
* The "* 0.375" operation is implemented with a right shift and an addition
* (min/4 + min/8), making it very fast and lightweight.
* The module includes saturation logic to prevent overflow in the event that the result exceeds the maximum representable value.
* The module is pipelined in 3 stages to maximize the operating frequency.
***********************************************************************************/
module magnitude_approximator #(
    parameter DATA_WIDTH = 24 // Width of the real and imaginary parts
) (
    input wire clk,
    input wire reset,
    input wire i_start,
    input wire signed [DATA_WIDTH*2-1:0] i_fft_complex, // Complex input (Re and Im concatenated)
    output wire [DATA_WIDTH-1:0] o_magnitude,
    output wire o_valid
);

    // Separate real and imaginary parts from the input
    wire signed [DATA_WIDTH-1:0] re_in = i_fft_complex[DATA_WIDTH*2-1 -: DATA_WIDTH];
    wire signed [DATA_WIDTH-1:0] im_in = i_fft_complex[DATA_WIDTH-1 -: DATA_WIDTH];


    // Pipeline Registers
    // Pipeline 1 abs(Re) and abs(Im) registers
    reg [DATA_WIDTH-1:0] p1_abs_re;
    reg [DATA_WIDTH-1:0] p1_abs_im;
    reg p1_valid;

    // Pipeline 2 max and min registers
    reg [DATA_WIDTH-1:0] p2_max;
    reg [DATA_WIDTH-1:0] p2_min;
    reg p2_valid;

    // Pipeline 3 Calculated magnitude output register
    reg [DATA_WIDTH-1:0] p3_magnitude;
    reg p3_valid;


    // Pipeline Logic
    // #1 Absolute value calculation
    always @(posedge clk) begin
        if (reset) begin
            p1_valid <= 1'b0;
            p1_abs_re <= {DATA_WIDTH{1'b0}};// It is not necessary to reset p1_abs_re/im but done for clarity
            p1_abs_im <= {DATA_WIDTH{1'b0}};
        end else begin
            p1_valid <= i_start;
            if (i_start) begin // if we get the start signal
                // Real
                if (re_in[DATA_WIDTH-1]) begin // if negative C2 convert
                    p1_abs_re <= ~re_in + 1'b1;// take the abs value
                end else begin
                    p1_abs_re <= re_in;
                end

                // Imaginary
                if (im_in[DATA_WIDTH-1]) begin // if negative C2 convert
                    p1_abs_im <= ~im_in + 1'b1;
                end else begin
                    p1_abs_im <= im_in;
                end
            end
        end
    end

    // #2 Max and Min calculation
    always @(posedge clk) begin
        if (reset) begin
            p2_valid <= 1'b0;
            p2_max <= {DATA_WIDTH{1'b0}};
            p2_min <= {DATA_WIDTH{1'b0}};
        end else begin
            p2_valid <= p1_valid;
            if (p1_valid) begin
                if (p1_abs_re > p1_abs_im) begin
                    p2_max <= p1_abs_re;
                    p2_min <= p1_abs_im;
                end else begin
                    p2_max <= p1_abs_im;
                    p2_min <= p1_abs_re;
                end
            end
        end
    end

    // #3 Magnitude approximation calculation
    wire [DATA_WIDTH-1:0] min_div_4 = p2_min >> 2'd2;
    wire [DATA_WIDTH-1:0] min_div_8 = p2_min >> 2'd3;
    wire [DATA_WIDTH-1:0] min_scaled = min_div_4 + min_div_8;
    
    wire [DATA_WIDTH:0] magnitude_full = {1'b0, p2_max} + {1'b0, min_scaled};

    always @(posedge clk) begin
        if (reset) begin
            p3_valid     <= 1'b0;
            p3_magnitude <= {DATA_WIDTH{1'b0}};
        end else begin
            p3_valid <= p2_valid;
            if (p2_valid) begin
                if (magnitude_full[DATA_WIDTH]) begin
                    p3_magnitude <= {DATA_WIDTH{1'b1}}; // Overflow saturation
                end else begin
                    p3_magnitude <= magnitude_full[DATA_WIDTH-1:0];
                end
            end
        end
    end

    // assign outputs
    assign o_magnitude = p3_magnitude;
    assign o_valid = p3_valid;

endmodule