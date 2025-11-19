/********************************************************************************
 * Testbench for: vga_controller
 * 
 * Description:
 *   - Generates a 25 MHz clock.
 *   - Applies an active-low reset at the beginning of the simulation.
 *   - Runs the simulation for slightly more than two full video frames to allow
 *     for checking the wrapping behavior of the counters.
 ********************************************************************************/

// `timescale` directive defines the time units for the simulation
// 1ns is the unit of time, 1ps is the precision.
`timescale 1ns / 1ps

module vga_controller_tb;

    //----------------------------------------------------------------
    //-- Signal Declarations
    //----------------------------------------------------------------

    // Inputs to the DUT (Device Under Test) are declared as 'reg'
    reg pixel_clk;
    reg reset_n;

    // Outputs from the DUT are declared as 'wire'
    wire       h_sync;
    wire       v_sync;
    wire       video_on;
    wire [9:0] pixel_x;
    wire [9:0] pixel_y;

    //----------------------------------------------------------------
    //-- Instantiate the Device Under Test (DUT)
    //----------------------------------------------------------------
    
    // Connect the testbench signals to the vga_controller module
    // Using named port mapping for better readability
    vga_controller uut (
        .pixel_clk(pixel_clk),
        .reset_n(reset_n),
        .h_sync(h_sync),
        .v_sync(v_sync),
        .video_on(video_on),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y)
    );

    //----------------------------------------------------------------
    //-- Clock Generation
    //----------------------------------------------------------------
    
    // The clock period for 25 MHz is 40 ns (1 / 25,000,000 = 40e-9).
    // The clock signal should toggle every half-period (20 ns).
    initial begin
        pixel_clk = 0; // Start clock at 0
    end
    
    always begin
        #20 pixel_clk = ~pixel_clk; // Toggle every 20 ns
    end

    //----------------------------------------------------------------
    //-- Simulation Sequence
    //----------------------------------------------------------------
    
    initial begin
        // 1. Start with reset asserted
        $display("Starting simulation. Reset is asserted.");
        reset_n = 1'b0; // Active-low reset

        // 2. Hold reset for some time to ensure DUT is properly reset
        #100; // Wait for 100 ns

        // 3. De-assert reset and let the simulation run
        $display("Reset de-asserted. Simulation running.");
        reset_n = 1'b1;

        // 4. Let the simulation run for ~2.5 frames.
        //    One frame = 800 * 525 * 40ns = 16.8 ms.
        //    Let's run for 40 ms (40,000,000 ns).
        #40000000;
        
        // 5. Stop the simulation
        $display("Simulation finished.");
        $stop;
    end

endmodule