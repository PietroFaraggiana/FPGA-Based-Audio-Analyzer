/*******************************************************************************
 * Module: tb_magnitude_approximator
 *
 * Description:
 *   Testbench for the Magnitude Approximator module.
 *   It generates the system clock and synchronous reset, and drives the
 *   Device Under Test (DUT) with various test vectors to verify the
 *   "Alpha Max plus Beta Min" algorithm implementation.
 *
 * Test Scenarios:
 *   1. Basic Functionality: Verified with pure Real and pure Imaginary inputs.
 *   2. Signed Arithmetic: Checks if negative inputs are correctly converted 
 *      to absolute values (Stage 1).
 *   3. Algorithm Accuracy: Uses diagonal inputs (Re=Im) to verify the 
 *      approximate calculation logic (Max + 0.375 * Min).
 *   4. Saturation Logic: Inputs maximum positive values to test the output 
 *      range handling.
 *   5. Pipeline Throughput: Injects back-to-back data (Burst Mode) to ensure 
 *      the module processes one sample per clock cycle with valid output.
 *
 * Expected Latency: 3 Clock Cycles.
 *******************************************************************************/
`timescale 1ns / 1ps

module tb_magnitude_approximator;

    // -------------------------------------------------------------------------
    // Parameters
    // -------------------------------------------------------------------------
    parameter DATA_WIDTH = 24;
    parameter CLK_PERIOD = 10; // 100 MHz

    // -------------------------------------------------------------------------
    // Signals
    // -------------------------------------------------------------------------
    reg                         clk;
    reg                         reset;
    reg                         i_start;
    reg  [DATA_WIDTH*2-1:0]     i_fft_complex;

    wire [DATA_WIDTH-1:0]       o_magnitude;
    wire                        o_valid;

    // -------------------------------------------------------------------------
    // DUT Instantiation (Device Under Test)
    // -------------------------------------------------------------------------
    magnitude_approximator #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk            (clk),
        .reset          (reset),
        .i_start        (i_start),
        .i_fft_complex  (i_fft_complex),
        .o_magnitude    (o_magnitude),
        .o_valid        (o_valid)
    );

    // -------------------------------------------------------------------------
    // Clock Generation
    // -------------------------------------------------------------------------
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // -------------------------------------------------------------------------
    // Task: Drive Input
    // Sends a Real and Imaginary pair for one clock cycle
    // -------------------------------------------------------------------------
    task drive_input;
        input [DATA_WIDTH-1:0] re;
        input [DATA_WIDTH-1:0] im;
        begin
            // Concatenate Re and Im into the complex input vector
            // Note: ModelSim handles 2's complement assignment to regs automatically
            i_fft_complex = {re, im}; 
            i_start       = 1'b1;
            @(posedge clk);
            i_start       = 1'b0;
            // Don't care about data when start is low, but clearing helps waveform view
            i_fft_complex = { {DATA_WIDTH{1'b0}}, {DATA_WIDTH{1'b0}} }; 
        end
    endtask

    // -------------------------------------------------------------------------
    // Main Stimulus Process
    // -------------------------------------------------------------------------
    initial begin
        // 1. Initialize
        $display("\n*** Simulation Started ***");
        reset         = 1'b1;
        i_start       = 1'b0;
        i_fft_complex = 0;

        // 2. Hold Reset
        #(CLK_PERIOD * 5);
        @(posedge clk);
        reset = 1'b0;
        $display("--- Reset Released ---");
        @(posedge clk);

        // 3. Test Case: Pure Real (Positive)
        // Re = 1000, Im = 0 -> Mag should be ~1000
        $display("Input: (1000, 0)");
        drive_input(24'd1000, 24'd0);
        #(CLK_PERIOD * 4); // Wait for pipeline

        // 4. Test Case: Pure Imaginary (Negative)
        // Re = 0, Im = -2000 -> Mag should be ~2000
        // Note: -2000 in 24-bit 2's complement
        $display("Input: (0, -2000)");
        drive_input(24'd0, -24'd2000); 
        #(CLK_PERIOD * 4);

        // 5. Test Case: Equal Components (Approximation Check)
        // Re = 1000, Im = 1000
        // Algo: Max + 0.375*Min = 1000 + 375 = 1375
        // Real Math: sqrt(1000^2 + 1000^2) = 1414
        $display("Input: (1000, 1000) -> Expected approx: 1375");
        drive_input(24'd1000, 24'd1000);
        #(CLK_PERIOD * 4);

        // 6. Test Case: Saturation Logic
        // Input max positive integer on both Re and Im.
        // The approximation will exceed the DATA_WIDTH. 
        // Output should saturate to max value (all 1s).
        $display("Input: Max Positive Values (Testing Saturation)");
        drive_input({1'b0, {DATA_WIDTH-1{1'b1}}}, {1'b0, {DATA_WIDTH-1{1'b1}}});
        #(CLK_PERIOD * 4);

        // 7. Test Case: Pipelining (Burst Mode)
        // Send 3 values back-to-back to ensure the pipeline works at full speed
        $display("--- Testing Pipeline (Burst) ---");
        
        // Cycle 1: 100, 0
        i_fft_complex = {24'd100, 24'd0};
        i_start = 1;
        @(posedge clk);
        
        // Cycle 2: 0, 200
        i_fft_complex = {24'd0, 24'd200};
        i_start = 1;
        @(posedge clk);
        
        // Cycle 3: 300, 400 (3-4-5 Triangle, approx: 400 + 300*0.375 = 512.5)
        i_fft_complex = {24'd300, 24'd400};
        i_start = 1;
        @(posedge clk);

        // End Burst
        i_start = 0;
        i_fft_complex = 0;

        #(CLK_PERIOD * 10);
        $display("*** Simulation Finished ***\n");
        $stop;
    end

    // -------------------------------------------------------------------------
    // Monitor Process
    // -------------------------------------------------------------------------
    // Prints the result whenever o_valid goes high
    always @(posedge clk) begin
        if (o_valid) begin
            $display("Time %t | Result Valid: Magnitude = %d", $time, o_magnitude);
        end
    end

endmodule