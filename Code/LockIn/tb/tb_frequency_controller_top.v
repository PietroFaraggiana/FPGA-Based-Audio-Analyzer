/*******************************************************************************************
* Module: tb_frequency_controller_top
* Tests: 
* 1. System reset via key_0 to initialize internal registers
* 2. Frequency increment via key_1 to verify basic operation
* 3. Scale modification via key_3 to change increment/decrement step
* 4. Frequency increment with the new scale applied
* 5. Frequency decrement via key_2
* 6. Final reset to verify return to default state
*******************************************************************************************/
`timescale 1ns/1ps

module tb_frequency_controller_top;

parameter FREQUENCY_RANGE = 8192;
parameter W = 13;

reg clk = 0;
reg key_0 = 1;
reg key_1 = 1;
reg key_2 = 1;
reg key_3 = 1;

wire reset_active;
wire [W-1:0] frequency_out;
wire [6:0] hex0;
wire [6:0] hex1;
wire [6:0] hex2;
wire [6:0] hex3;
wire [6:0] hex4;
wire [6:0] hex5;
wire [6:0] hex6;
wire [6:0] hex7;

always #10 clk = ~clk;

frequency_controller_top #(
    .FREQUENCY_RANGE(FREQUENCY_RANGE),
    .W(W)
) dut (
    .clk(clk),
    .key_0(key_0),
    .key_1(key_1),
    .key_2(key_2),
    .key_3(key_3),
    .reset_active(reset_active),
    .frequency_out(frequency_out),
    .HEX0(hex0),
    .HEX1(hex1),
    .HEX2(hex2),
    .HEX3(hex3),
    .HEX4(hex4),
    .HEX5(hex5),
    .HEX6(hex6),
    .HEX7(hex7)
);

task press_button;
    input integer index;
    begin
        case (index)
            0: key_0 = 0;
            1: key_1 = 0;
            2: key_2 = 0;
            3: key_3 = 0;
        endcase
        #100;
        key_0 = 1;
        key_1 = 1;
        key_2 = 1;
        key_3 = 1;
        #100;
    end
endtask

initial begin
    #100;

    // 1
    press_button(0);

    // 2
    repeat (3) press_button(1);

    // 3
    press_button(3);

    // 4
    repeat (2) press_button(1);

    // 5
    press_button(2);

    // 6
    press_button(0);

    #200;
    $stop;
end

endmodule