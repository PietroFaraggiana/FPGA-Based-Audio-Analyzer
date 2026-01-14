/*******************************************************************************************
* Module: tb_lp_cic_filter
* Tests: 
* 1. System reset: Initialization of all internal registers and output signals.
* 2. DC Input response: Constant values applied to verify unity gain and bit growth handling.
* 3. Zero Input response: Verification that the filter returns to zero state after input clears.
*******************************************************************************************/
`timescale 1ns/1ps

module tb_lp_cic_filter;

parameter BUFFER_DEPTH = 512;
parameter DATA_WIDTH = 42;

reg clk = 0;
reg reset = 0;
reg signed [DATA_WIDTH-1:0] phase_in = 0;
reg signed [DATA_WIDTH-1:0] quadrature_in = 0;
reg [$clog2(BUFFER_DEPTH)-1:0] addr_in = 0;
reg valid_in = 0;

wire signed [DATA_WIDTH-1:0] phase_out;
wire signed [DATA_WIDTH-1:0] quadrature_out;
wire valid_out;

lp_cic_filter #(
    .BUFFER_DEPTH(BUFFER_DEPTH),
    .DATA_WIDTH(DATA_WIDTH)
) dut (
    .clk(clk),
    .reset(reset),
    .phase_in(phase_in),
    .quadrature_in(quadrature_in),
    .addr_in(addr_in),
    .valid_in(valid_in),
    .phase_out(phase_out),
    .quadrature_out(quadrature_out),
    .valid_out(valid_out)
);

always #10 clk = ~clk;

integer i;

initial begin
    // 1
    reset = 1;
    #100;
    reset = 0;
    @(posedge clk);

    // 2
    for (i = 0; i < (BUFFER_DEPTH * 3); i = i + 1) begin
        @(posedge clk);
        valid_in = 1;
        phase_in = 1000;
        quadrature_in = -1000;
        if (addr_in == BUFFER_DEPTH - 1) begin
            addr_in = 0;
        end else begin
            addr_in = addr_in + 1;
        end
    end

    // 3
    for (i = 0; i < (BUFFER_DEPTH * 2); i = i + 1) begin
        @(posedge clk);
        valid_in = 1;
        phase_in = 0;
        quadrature_in = 0;
        if (addr_in == BUFFER_DEPTH - 1) begin
            addr_in = 0;
        end else begin
            addr_in = addr_in + 1;
        end
    end

    valid_in = 0;
    #200;
    $stop;
end

always @(posedge clk) begin
    if (valid_out) begin
        $display("Time: %t | Phase: %d | Quad: %d", $time, phase_out, quadrature_out);
    end
end

endmodule