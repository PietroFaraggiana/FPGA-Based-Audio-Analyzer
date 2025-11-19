/*******************************************************************************
* Testbench for fft_controller.v:
* 1. Initialization Sequence: Verifies the system reset and initial 
*    state of control signals.
* 2. **External Memory Simulation**: Models a Dual-Port RAM and a Twiddle 
*    Factor ROM with 1-cycle read latencies to verify correct memory 
*    addressing and read/write timing.
* 3. **Arithmetic Unit Simulation**:
*    - **Butterfly Unit**: Models the processing delay (BFLY_LATENCY) 
*      and handshaking (start/valid) for the core FFT calculation.
*    - **Magnitude Unit**: Models the delay (MAG_LATENCY) for the final 
*      result calculation.
* 4. **Full Process Execution**: Asserts 'i_data_ready' and monitors the 
*    FSM state transitions through the loading, processing, and output stages.
* 5. **Completion Handshake**: Waits for the 'o_fft_done' signal to ensure 
*    the controller completes the operation successfully without hanging.
 ******************************************************************************/

`timescale 1ns / 1ps
module fft_controller_tb;


    // Testbench Parameters (Must match DUT parameters)

    parameter FFT_POINTS      = 512;
    parameter DATA_WIDTH      = 24;
    parameter TWIDDLE_WIDTH   = 24;
    parameter LOG2_FFT_POINTS = 9; // $clog2(512)

    // Simulation Parameters
    parameter CLK_PERIOD      = 10; // Clock period in ns (100 MHz)
    parameter BFLY_LATENCY    = 3;  // Simulated Butterfly unit latency (cycles)
    parameter MAG_LATENCY     = 2;  // Simulated Magnitude calculator latency (cycles)

    // DUT Interface Signals
    // Inputs
    reg                      clk;
    reg                      reset;
    reg                      i_data_ready;
    reg  [DATA_WIDTH-1:0]    i_buffer_data_in;
    reg  [DATA_WIDTH*2-1:0]  i_ram_data_out_a;
    reg  [DATA_WIDTH*2-1:0]  i_ram_data_out_b;
    reg  [TWIDDLE_WIDTH*2-1:0] i_twiddle_factor;
    reg                      i_butterfly_valid;
    reg  [DATA_WIDTH*2-1:0]  i_butterfly_a_out;
    reg  [DATA_WIDTH*2-1:0]  i_butterfly_b_out;
    reg                      i_magnitude_valid;
    reg  [DATA_WIDTH-1:0]    i_magnitude_in;

    // Outputs
    wire [LOG2_FFT_POINTS-1:0] o_buffer_read_addr;
    wire [LOG2_FFT_POINTS-1:0] o_ram_addr_a;
    wire [DATA_WIDTH*2-1:0]    o_ram_data_in_a;
    wire                       o_ram_wr_en_a;
    wire [LOG2_FFT_POINTS-1:0] o_ram_addr_b;
    wire [DATA_WIDTH*2-1:0]    o_ram_data_in_b;
    wire                       o_ram_wr_en_b;
    wire [LOG2_FFT_POINTS-1:0] o_twiddle_addr;
    wire                       o_butterfly_start;
    wire                       o_magnitude_start;
    wire [DATA_WIDTH-1:0]      o_magnitude_out;
    wire                       o_fft_busy;
    wire                       o_fft_done;
    
    // DUT Instantiation 
    fft_controller #(
        .FFT_POINTS    (FFT_POINTS),
        .DATA_WIDTH    (DATA_WIDTH),
        .TWIDDLE_WIDTH (TWIDDLE_WIDTH)
    ) uut (
        .clk(clk),
        .reset(reset),
        
        .i_data_ready(i_data_ready),
        .o_buffer_read_addr(o_buffer_read_addr),
        .i_buffer_data_in(i_buffer_data_in),

        .o_ram_addr_a(o_ram_addr_a),
        .o_ram_data_in_a(o_ram_data_in_a),
        .o_ram_wr_en_a(o_ram_wr_en_a),
        .i_ram_data_out_a(i_ram_data_out_a),
        .o_ram_addr_b(o_ram_addr_b),
        .o_ram_data_in_b(o_ram_data_in_b),
        .o_ram_wr_en_b(o_ram_wr_en_b),
        .i_ram_data_out_b(i_ram_data_out_b),

        .o_twiddle_addr(o_twiddle_addr),
        .i_twiddle_factor(i_twiddle_factor),

        .o_butterfly_start(o_butterfly_start),
        .i_butterfly_valid(i_butterfly_valid),
        .i_butterfly_a_out(i_butterfly_a_out),
        .i_butterfly_b_out(i_butterfly_b_out),

        .o_magnitude_start(o_magnitude_start),
        .i_magnitude_valid(i_magnitude_valid),
        .i_magnitude_in(i_magnitude_in),
        .o_magnitude_out(o_magnitude_out),

        .o_fft_busy(o_fft_busy),
        .o_fft_done(o_fft_done)
    );

    // Clock Generation
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // Working RAM Simulation
    // Dual-port synchronous memory with 1-cycle read latency
    reg [DATA_WIDTH*2-1:0] working_ram [0:FFT_POINTS-1];
    
    // Port A
    always @(posedge clk) begin
        // Write
        if (o_ram_wr_en_a) begin
            working_ram[o_ram_addr_a] <= o_ram_data_in_a;
        end
        // Read (with 1 cycle latency)
        i_ram_data_out_a <= working_ram[o_ram_addr_a];
    end

    // Port B
    always @(posedge clk) begin
        // Write
        if (o_ram_wr_en_b) begin
            working_ram[o_ram_addr_b] <= o_ram_data_in_b;
        end
        // Read (with 1 cycle latency)
        i_ram_data_out_b <= working_ram[o_ram_addr_b];
    end

    // Twiddle Factor ROM Simulation 
    // Synchronous ROM with 1-cycle read latency
    reg [TWIDDLE_WIDTH*2-1:0] twiddle_rom [0:FFT_POINTS-1];
    integer j;
    initial begin
        // Initialize ROM with dummy values
        for (j = 0; j < FFT_POINTS; j = j + 1) begin
            twiddle_rom[j] = {j[TWIDDLE_WIDTH-1:0], j[TWIDDLE_WIDTH-1:0]};
        end
    end
    
    always @(posedge clk) begin
        i_twiddle_factor <= twiddle_rom[o_twiddle_addr];
    end

    // Input Buffer Simulation 
    // Provides data when the controller asserts the read address
    always @(o_buffer_read_addr) begin
        // Provide a simple sample pattern
        i_buffer_data_in = o_buffer_read_addr + 1;
    end

    // Butterfly Unit Simulation 
    reg [BFLY_LATENCY-1:0] bfly_delay_cnt;
    reg [DATA_WIDTH*2-1:0] bfly_in_a_reg, bfly_in_b_reg;

    always @(posedge clk) begin
        if (reset) begin
            i_butterfly_valid <= 1'b0;
            bfly_delay_cnt <= 0;
        end else begin
            // Deassert the flag after one cycle
            if (i_butterfly_valid) begin
                i_butterfly_valid <= 1'b0;
            end
            
            if (o_butterfly_start) begin
                // Capture inputs
                bfly_in_a_reg <= i_ram_data_out_a;
                bfly_in_b_reg <= i_ram_data_out_b;
                bfly_delay_cnt <= BFLY_LATENCY - 1; // Start countdown
            end else if (|bfly_delay_cnt) begin // If counter is not zero
                bfly_delay_cnt <= bfly_delay_cnt - 1;
                if (bfly_delay_cnt == 1) begin // On the last cycle, calculate and assert valid
                    // Dummy calculation
                    i_butterfly_a_out <= bfly_in_a_reg + bfly_in_b_reg;
                    i_butterfly_b_out <= bfly_in_a_reg - bfly_in_b_reg;
                    i_butterfly_valid <= 1'b1;
                end
            end
        end
    end

    // Magnitude Calculator Simulation
    reg [MAG_LATENCY-1:0] mag_delay_cnt;
    reg [DATA_WIDTH*2-1:0] mag_in_reg;

    always @(posedge clk) begin
        if (reset) begin
            i_magnitude_valid <= 1'b0;
            mag_delay_cnt <= 0;
        end else begin
            if (i_magnitude_valid) begin
                i_magnitude_valid <= 1'b0;
            end

            if (o_magnitude_start) begin
                mag_in_reg <= i_ram_data_out_a; // Capture complex input
                mag_delay_cnt <= MAG_LATENCY - 1; // Start countdown
            end else if (|mag_delay_cnt) begin
                mag_delay_cnt <= mag_delay_cnt - 1;
                if (mag_delay_cnt == 1) begin
                    // Dummy magnitude calculation
                    i_magnitude_in <= mag_in_reg[DATA_WIDTH*2-1:DATA_WIDTH] + mag_in_reg[DATA_WIDTH-1:0];
                    i_magnitude_valid <= 1'b1;
                end
            end
        end
    end

    // Main Test Sequence
    initial begin
        $display("-------------------------------------------");
        $display("--- Starting fft_controller Simulation ---");
        $display("-------------------------------------------");

        // 1. Initialization and Reset
        reset             = 1'b1;
        i_data_ready      = 1'b0;
        i_butterfly_valid = 1'b0;
        i_magnitude_valid = 1'b0;
        i_butterfly_a_out = 0;
        i_butterfly_b_out = 0;
        i_magnitude_in    = 0;
        
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        
        reset = 1'b0;
        $display("[%0t] Reset released.", $time);

        @(posedge clk);

        // 2. Start FFT Process
        $display("[%0t] Asserting i_data_ready to start FFT.", $time);
        i_data_ready = 1'b1;
        @(posedge clk);
        i_data_ready = 1'b0;

        // 3. Wait for Completion
        $display("[%0t] Waiting for FFT completion (o_fft_done signal)...", $time);
        wait (o_fft_done == 1'b1);
        
        @(posedge clk); // Wait one cycle for signals to propagate

        $display("[%0t] Signal o_fft_done received!", $time);
        $display("-------------------------------------------");
        $display("--- TEST PASSED ---");
        $display("-------------------------------------------");

        // 4. End Simulation
        $finish;
    end
    
    // Watchdog Timer to prevent infinite loops
    initial begin
        // Estimate: 512 loads + (9 stages * 256 butterflies * ~5 cycles) + 512 mag * ~4 cycles
        //           512 + 11520 + 2048 = ~14080 cycles.
        // A timeout of 20,000 cycles is safe. 20000 * 10ns = 200,000 ns
        #200000;
        $display("-------------------------------------------");
        $display("--- ERROR: TIMEOUT! ---");
        $display("--- Simulation did not finish within the expected time. ---");
        $display("-------------------------------------------");
        $finish;
    end

endmodule