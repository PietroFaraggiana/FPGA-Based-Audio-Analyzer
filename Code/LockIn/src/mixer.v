/************************************************************************************
* Module: mixer
*
* Description: Performs signed multiplication: Data(24b) * Sin/Cos(18b).
* No truncation is performed here to maximize precision for the CIC filter.
* Latency: 2 Clock Cycles.
********************************************************************************/
module mixer #(
    parameter DATA_WIDTH = 24,
    parameter SIN_WIDTH = 18
) (
    input wire clk,
    input wire reset,
    input wire start,
    input wire signed [DATA_WIDTH-1:0] data_in,
    input wire signed [SIN_WIDTH-1:0] sine_in,
    input wire signed [SIN_WIDTH-1:0] cosine_in,
    output wire signed [(DATA_WIDTH + SIN_WIDTH)-1:0] phase_out, //#bits{m*n}=m+n
    output wire signed [(DATA_WIDTH + SIN_WIDTH)-1:0] quadrature_out,
    output wire o_valid
);

    localparam PRODUCT_WIDTH = DATA_WIDTH + SIN_WIDTH;
    //Pipeline
    // 1: Input registration
    reg signed [DATA_WIDTH-1:0] data_reg; // Audio sample
    reg signed [SIN_WIDTH-1:0] sine_factor; // Sine output
    reg signed [SIN_WIDTH-1:0] cosine_factor; // Cosine output
    reg p1_valid;

    always @(posedge clk) begin
        if (reset) begin
            p1_valid <= 1'b0;
            data_reg <= {DATA_WIDTH{1'b0}};
            sine_factor <= {SIN_WIDTH{1'b0}};
            cosine_factor <= {SIN_WIDTH{1'b0}};
        end else begin
            p1_valid <= start;
            if (start) begin
                data_reg <= data_in;
                sine_factor <= sine_in;
                cosine_factor <= cosine_in;
            end
        end
    end
    // I and Q multiplication
    wire signed [PRODUCT_WIDTH-1:0] phase_full = data_reg * sine_factor;
    wire signed [PRODUCT_WIDTH-1:0] quadrature_full = data_reg * cosine_factor;
    
    // 2: Output registration
    reg signed [PRODUCT_WIDTH-1:0] phase_reg;
    reg signed [PRODUCT_WIDTH-1:0] quadrature_reg;
    reg p2_valid;

    always @(posedge clk) begin
        if (reset) begin
            p2_valid <= 1'b0;
            phase_reg <= {PRODUCT_WIDTH{1'b0}};
            quadrature_reg <= {PRODUCT_WIDTH{1'b0}};
        end else begin
            p2_valid <= p1_valid;
            if (p1_valid) begin
                phase_reg <= phase_full;
                quadrature_reg <= quadrature_full;
            end
        end
    end

    // Output Assignments
    assign phase_out = phase_reg;
    assign quadrature_out = quadrature_reg;
    assign o_valid = p2_valid;

endmodule