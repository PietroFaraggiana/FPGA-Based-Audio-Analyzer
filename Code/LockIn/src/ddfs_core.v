/************************************************************************************
* Module: ddfs_core
*
* Description:
* Direct Digital Frequency Synthesizer (DDFS) for I/Q Audio Analysis.
* 1. Receives a 48kHz strobe (sample_en).
* 2. Updates the 16-bit Phase Accumulator.
* 3. Uses the top 10 bits to address the Sine/Cosine LUT.
* 4. Outputs 18-bit signed Sine (Q) and Cosine (I) waves.
*
* Latency:
* Data is valid 1 clock cycle after 'sample_en' goes high.
********************************************************************************/
module ddfs_core #(
    parameter ACC_WIDTH = 16, // Phase accumulator width
    parameter LUT_DEPTH = 10, // LUT address width
    parameter LUT_BITS = 18 // LUT data width
)(
    input clk,
    input reset,
    input sample_en, // Audio rate strobe (48 kHz)
    input [ACC_WIDTH-1:0] tuning_word,
    output signed [LUT_BITS-1:0] cosine_out,
    output signed [LUT_BITS-1:0] sine_out,
    output reg valid_out // High 1 cycle after sample_en
);

    // Phase Accumulator
    reg [ACC_WIDTH-1:0] phase_acc;
    always @(posedge clk) begin
        if (reset) begin
            phase_acc <= {ACC_WIDTH{1'b0}};
            valid_out <= 1'b0;
        end else begin
            // DDFS clock is sample_en
            if (sample_en) begin
                phase_acc <= phase_acc + tuning_word;
            end
            // Delay the enable signal by 1 clock to match LUT latency
            valid_out <= sample_en; 
        end
    end

    // LUT Address Mapping
    // Take the MSBs of the accumulator
    wire [LUT_DEPTH-1:0] lut_addr;
    assign lut_addr = phase_acc[ACC_WIDTH-1 : ACC_WIDTH-LUT_DEPTH];

    // LUT Instantiation
    ddfs_sine_lut #(
        .LUT_DEPTH(LUT_DEPTH),
        .LUT_BITS(LUT_BITS)
    ) u_ddfs_sine_lut (
        .clk (clk),
        .addr (lut_addr),
        .sine_out (sine_out),
        .cosine_out (cosine_out)
    );

endmodule