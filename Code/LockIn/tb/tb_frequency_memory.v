/*******************************************************************************************
* Module: tb_frequency_memory
* Tests: 
* 1. System reset to initialize frequency and scale
* 2. Frequency increment with step 1 (Scale 0)
* 3. Scale change to step 10 (Scale 1) and increment
* 4. Scale change to step 100 (Scale 2) and increment
* 5. Frequency decrement with floor saturation at zero
* 6. Scale change to step 1000 (Scale 3) and increment
* 7. Frequency saturation at maximum range value
*******************************************************************************************/
`timescale 1ns/1ps

module tb_frequency_memory;

    parameter FREQUENCY_RANGE = 8192;
    reg clk = 0;
    reg reset = 0;
    reg btn_up = 0;
    reg btn_down = 0;
    reg btn_scale = 0;
    wire [$clog2(FREQUENCY_RANGE)-1:0] frequency_out;
    wire [1:0] scale_out;

    frequency_memory #(
        .FREQUENCY_RANGE(FREQUENCY_RANGE)
    ) dut (
        .clk(clk),
        .reset(reset),
        .btn_up(btn_up),
        .btn_down(btn_down),
        .btn_scale(btn_scale),
        .frequency_out(frequency_out),
        .scale_out(scale_out)
    );

    always #10 clk = ~clk;

    initial begin
        // 1
        reset = 1;
        #40;
        reset = 0;
        #20;

        // 2
        btn_up = 1;
        #20;
        btn_up = 0;
        #40;

        // 3
        btn_scale = 1;
        #20;
        btn_scale = 0;
        #20;
        btn_up = 1;
        #20;
        btn_up = 0;
        #40;

        // 4
        btn_scale = 1;
        #20;
        btn_scale = 0;
        #20;
        btn_up = 1;
        #20;
        btn_up = 0;
        #40;

        // 5
        btn_down = 1;
        #20;
        btn_down = 0;
        #20;
        btn_down = 1;
        #20;
        btn_down = 0;
        #40;

        // 6
        btn_scale = 1;
        #20;
        btn_scale = 0;
        #20;
        btn_up = 1;
        #20;
        btn_up = 0;
        #40;

        // 7
        btn_up = 1;
        #160;
        btn_up = 0;
        #100;

        $stop;
    end

endmodule