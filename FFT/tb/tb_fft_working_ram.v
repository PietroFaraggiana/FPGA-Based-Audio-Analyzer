/*******************************************************************************
 * Module: tb_fft_working_ram
 * Description:
 *   Testbench for the "fft_working_ram" module.
 *   Target Simulator: ModelSim.
 *   Standard: Verilog-1995 (Pre-2001 compatible).
 *
 *   Verifies:
 *   - Read and Write operations on Port A.
 *   - Read and Write operations on Port B.
 *   - Simultaneous operations.
 *   - "Read-first" behavior during R/W conflicts.
 *   - Synchronous Reset behavior.
 ******************************************************************************/
`timescale 1ns / 1ps

module tb_fft_working_ram;

    // -------------------------------------------------------------------------
    // Parameters
    // -------------------------------------------------------------------------
    parameter DATA_WIDTH   = 48;
    parameter BUFFER_DEPTH = 512;
    
    // Address width = log2(512) = 9
    parameter ADDR_WIDTH   = 9; 

    // -------------------------------------------------------------------------
    // Testbench Signals
    // -------------------------------------------------------------------------
    reg                     clk;
    reg                     reset;

    // --- Port A Signals ---
    reg  [ADDR_WIDTH-1:0]   i_addr_a;
    reg  [DATA_WIDTH-1:0]   i_data_a;
    reg                     i_wr_en_a;
    wire [DATA_WIDTH-1:0]   o_data_a;

    // --- Port B Signals ---
    reg  [ADDR_WIDTH-1:0]   i_addr_b;
    reg  [DATA_WIDTH-1:0]   i_data_b;
    reg                     i_wr_en_b;
    wire [DATA_WIDTH-1:0]   o_data_b;

    // Test variables
    integer                 errors;

    // -------------------------------------------------------------------------
    // DUT Instantiation (Device Under Test)
    // -------------------------------------------------------------------------
    fft_working_ram #(
        .DATA_WIDTH(DATA_WIDTH),
        .BUFFER_DEPTH(BUFFER_DEPTH)
    ) dut (
        .clk(clk),
        .reset(reset),
        
        // Port A
        .i_addr_a(i_addr_a),
        .i_data_a(i_data_a),
        .i_wr_en_a(i_wr_en_a),
        .o_data_a(o_data_a),

        // Port B
        .i_addr_b(i_addr_b),
        .i_data_b(i_data_b),
        .i_wr_en_b(i_wr_en_b),
        .o_data_b(o_data_b)
    );

    // -------------------------------------------------------------------------
    // Clock Generation
    // -------------------------------------------------------------------------
    initial begin
        clk = 0;
        forever #10 clk = ~clk; // 50 MHz clock
    end

    // -------------------------------------------------------------------------
    // Main Stimulus Process
    // -------------------------------------------------------------------------
    initial begin
        // 1. Initialization
        $display("==================================================");
        $display("Starting Testbench for fft_working_ram");
        $display("==================================================");
        
        errors = 0;
        reset = 1;
        i_addr_a = 0; i_data_a = 0; i_wr_en_a = 0;
        i_addr_b = 0; i_data_b = 0; i_wr_en_b = 0;

        // Hold reset
        #100;
        @(negedge clk);
        reset = 0;
        $display("[T= %0t] Reset released.", $time);

        // ---------------------------------------------------------------------
        // Test Case 1: Write and Read Port A
        // ---------------------------------------------------------------------
        $display("[T= %0t] Test 1: Writing to Port A (Addr 10)", $time);
        
        @(negedge clk);
        i_addr_a  = 10;
        i_data_a  = 48'hAAAA_BBBB_CCCC;
        i_wr_en_a = 1;

        @(negedge clk);
        i_wr_en_a = 0; 

        // Read back
        @(negedge clk);
        i_addr_a = 10;
        
        @(negedge clk); // Wait for output register
        if (o_data_a !== 48'hAAAA_BBBB_CCCC) begin
            $display("ERROR Test 1: Port A Read Mismatch. Expected AA..CC, Got %h", o_data_a);
            errors = errors + 1;
        end else begin
            $display("PASS Test 1: Port A Read Correct.");
        end

        // ---------------------------------------------------------------------
        // Test Case 2: Write and Read Port B
        // ---------------------------------------------------------------------
        $display("[T= %0t] Test 2: Writing to Port B (Addr 20)", $time);
        
        @(negedge clk);
        i_addr_b  = 20;
        i_data_b  = 48'h1111_2222_3333;
        i_wr_en_b = 1;

        @(negedge clk);
        i_wr_en_b = 0;

        // Read back
        @(negedge clk);
        i_addr_b = 20;
        
        @(negedge clk);
        if (o_data_b !== 48'h1111_2222_3333) begin
            $display("ERROR Test 2: Port B Read Mismatch. Expected 11..33, Got %h", o_data_b);
            errors = errors + 1;
        end else begin
            $display("PASS Test 2: Port B Read Correct.");
        end

        // ---------------------------------------------------------------------
        // Test Case 3: Simultaneous Access (Write A, Read B)
        // ---------------------------------------------------------------------
        $display("[T= %0t] Test 3: Simultaneous Write A / Read B", $time);
        
        @(negedge clk);
        // Write new data to Addr 30 via Port A
        i_addr_a  = 30;
        i_data_a  = 48'hDEAD_BEEF_0000;
        i_wr_en_a = 1;

        // Read existing data from Addr 10 via Port B (Written in Test 1)
        i_addr_b  = 10;
        i_wr_en_b = 0;

        @(negedge clk);
        i_wr_en_a = 0;

        // Check Port B output immediately 
        if (o_data_b !== 48'hAAAA_BBBB_CCCC) begin
            $display("ERROR Test 3: Port B Simultaneous Read Failed. Got %h", o_data_b);
            errors = errors + 1;
        end else begin
            $display("PASS Test 3: Port B Simultaneous Read Correct.");
        end

        // Verify the write to Port A happened
        @(negedge clk);
        i_addr_a = 30;
        @(negedge clk);
        if (o_data_a !== 48'hDEAD_BEEF_0000) begin
            $display("ERROR Test 3: Port A Verification Failed.");
            errors = errors + 1;
        end

        // ---------------------------------------------------------------------
        // Test Case 4: Read-First Behavior (Conflict Check)
        // ---------------------------------------------------------------------
        $display("[T= %0t] Test 4: Checking Read-First Behavior", $time);

        // Setup: Write "OLD" value (using valid Hex) to Address 5
        @(negedge clk);
        i_addr_a  = 5;
        i_data_a  = 48'h0000_0000_AAA1; // Was OLD1 (invalid hex)
        i_wr_en_a = 1;
        @(negedge clk);
        i_wr_en_a = 0;

        // Conflict Cycle: Write "NEW" value to Address 5, Read Address 5 same time
        @(negedge clk);
        i_addr_a  = 5;
        i_data_a  = 48'hFFFF_FFFF_BBB2; // Was NEW2 (invalid hex)
        i_wr_en_a = 1; 

        // At the next rising edge, o_data_a should capture RAM[5] *before* the new write
        @(negedge clk);
        
        // Check output: Should be AAA1 (Old value), not BBB2
        if (o_data_a === 48'h0000_0000_AAA1) begin
            $display("PASS Test 4: Read-First Logic Works (Output is OLD value).");
        end else if (o_data_a === 48'hFFFF_FFFF_BBB2) begin
            $display("ERROR Test 4: Write-Through detected instead of Read-First.");
            errors = errors + 1;
        end else begin
            $display("ERROR Test 4: Unknown value %h", o_data_a);
            errors = errors + 1;
        end

        i_wr_en_a = 0;

        // Next cycle: Read again. Now it should be BBB2.
        @(negedge clk);
        if (o_data_a === 48'hFFFF_FFFF_BBB2) begin
            $display("PASS Test 4: New value successfully written.");
        end else begin
            $display("ERROR Test 4: New value not in memory.");
            errors = errors + 1;
        end

        // ---------------------------------------------------------------------
        // Test Case 5: Reset Behavior
        // ---------------------------------------------------------------------
        $display("[T= %0t] Test 5: Reset Output Check", $time);
        
        @(negedge clk);
        reset = 1;

        @(negedge clk);
        if (o_data_a === 0 && o_data_b === 0) begin
             $display("PASS Test 5: Outputs cleared on Reset.");
        end else begin
             $display("ERROR Test 5: Outputs did not clear. A=%h, B=%h", o_data_a, o_data_b);
             errors = errors + 1;
        end
        
        reset = 0;

        // ---------------------------------------------------------------------
        // Summary
        // ---------------------------------------------------------------------
        #50;
        $display("==================================================");
        if (errors == 0) begin
            $display("SIMULATION PASSED: All tests completed successfully.");
        end else begin
            $display("SIMULATION FAILED: %d errors detected.", errors);
        end
        $display("==================================================");
        
        $stop;
    end

endmodule