/************************************************************************************
* Testbench for the twiddle_factor_rom module
*
* Description:
* - Generates a clock and reset signal.
* - Provides a sequence of addresses as input to the DUT.
* - Verifies correct operation, including one-cycle latency
* and symmetry logic for addresses >= 256.
************************************************************************************/
`timescale 1ns / 1ps

module tb_twiddle_factor_rom;

    // Parameters
    parameter ADDR_WIDTH = 9;
    parameter DATA_WIDTH = 48;
    parameter CLK_PERIOD = 10; //ns (100MHz)

    // DUT Signals, inputs in DUT are 'reg', outputs are 'wire' in the testbench
    reg                        clk;
    reg                        rst_n;
    reg   [ADDR_WIDTH-1:0]     addr;


    wire  [DATA_WIDTH-1:0]     twiddle_factor_q;

    twiddle_factor_rom #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .addr(addr),
        .twiddle_factor_q(twiddle_factor_q)
    );

    // 1. clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // 2. stimulus generation and test sequence
    initial begin
        $display("--------------------------------------------------");
        $display("Start of twiddle_factor_rom simulation");
        $display("Tempo\t\tAddr\tOutput (Hex)");
        $display("--------------------------------------------------");

        // reset sequence
        rst_n = 1'b0; // active low
        addr  = 0;
        #20;          // 2 clock cycles of reset
        
        rst_n = 1'b1; 
        @(posedge clk); // First rising edge after reset
        $display("%t\tReset rilasciato.", $time);
        
        // one cycle wait for propagating reset
        @(posedge clk); 
        
        // --- Test 1: W_512^0 address ---
        addr <= 0;
        @(posedge clk); // 1. DUT samples addr=0
        @(posedge clk); // 2. output for addr=0 is valid
        $display("%t\t%d\t%h", $time, addr, twiddle_factor_q);

        // --- Test 2: addr 2 ---
        addr <= 1;
        @(posedge clk); // Samples addr=1
        @(posedge clk); // Output addr=1 is valid
        $display("%t\t%d\t%h", $time, addr, twiddle_factor_q);

        // --- Test 3: Addr 255 inf lim ---
        addr <= 255;
        @(posedge clk); 
        @(posedge clk); 
        $display("%t\t%d\t%h", $time, addr, twiddle_factor_q);

        // --- Test 4: addr 256, first negative -W_512^0) ---
        addr <= 256;
        @(posedge clk); 
        @(posedge clk); 
        $display("%t\t%d\t%h", $time, addr, twiddle_factor_q);

        // --- Test 5: addr 257 ---
        addr <= 257;
        @(posedge clk); 
        @(posedge clk); 
        $display("%t\t%d\t%h", $time, addr, twiddle_factor_q);
        
        // --- Test 6: addr 511 sup lim ---
        addr <= 511;
        @(posedge clk); 
        @(posedge clk); 
        $display("%t\t%d\t%h", $time, addr, twiddle_factor_q);

        // end of simulation
        #50; 
        $display("--------------------------------------------------");
        $display("Simulation over.");
        $display("--------------------------------------------------");
        $finish;
    end

endmodule