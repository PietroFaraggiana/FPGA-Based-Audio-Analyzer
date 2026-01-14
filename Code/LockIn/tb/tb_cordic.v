/*******************************************************************************************
* Module: tb_cordic
* Tests: 
* 1. Input positive I and Q to test Quadrant 1 (45 degrees)
* 2. Input negative I and positive Q to test Quadrant 2 (135 degrees)
* 3. Input negative I and negative Q to test Quadrant 3 (-135 degrees)
* 4. Input positive I and negative Q to test Quadrant 4 (-45 degrees)
* 5. Input positive I and zero Q to test 0 degrees phase
*******************************************************************************************/
`timescale 1ns/1ps

module tb_cordic();

parameter WIDTH = 42;
parameter ITER = 42;

reg clk = 0;
reg reset;
reg valid_in;
reg signed [WIDTH-1:0] I_in;
reg signed [WIDTH-1:0] Q_in;

wire valid_out;
wire signed [WIDTH-1:0] phase_out;
wire [WIDTH-1:0] mag_out;

always #10 clk = ~clk;

cordic #(
    .WIDTH(WIDTH),
    .ITER(ITER)
) dut (
    .clk(clk),
    .reset(reset),
    .valid_in(valid_in),
    .I_in(I_in),
    .Q_in(Q_in),
    .valid_out(valid_out),
    .phase_out(phase_out),
    .mag_out(mag_out)
);

task drive_sample;
    input signed [WIDTH-1:0] i_val;
    input signed [WIDTH-1:0] q_val;
    begin
        @(posedge clk);
        I_in <= i_val;
        Q_in <= q_val;
        valid_in <= 1'b1;
        @(posedge clk);
        valid_in <= 1'b0;
        wait(valid_out);
        @(posedge clk);
    end
endtask

initial begin
    reset = 1;
    valid_in = 0;
    I_in = 0;
    Q_in = 0;
    #100;
    reset = 0;
    #40;

    // 1
    drive_sample((42'sd1 <<< 37), (42'sd1 <<< 37));

    // 2
    drive_sample(-(42'sd1 <<< 37), (42'sd1 <<< 37));

    // 3
    drive_sample(-(42'sd1 <<< 37), -(42'sd1 <<< 37));

    // 4
    drive_sample((42'sd1 <<< 37), -(42'sd1 <<< 37));

    // 5
    drive_sample((42'sd1 <<< 38), 42'sd0);

    #200;
    $stop;
end

endmodule