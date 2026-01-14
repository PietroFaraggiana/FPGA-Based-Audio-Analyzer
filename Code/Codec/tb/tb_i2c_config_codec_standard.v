/*******************************************************************************************
* Module: tb_i2c_config_codec_standard
* Tests: 
* 1.Initial reset of the system and signal initialization
* 2. Wait for reset release and monitor I2C transmission until done signal
*******************************************************************************************/
`timescale 1ns/1ps

module tb_i2c_config_codec_standard;

    reg clk = 0;
    always #10 clk = ~clk;

    reg reset = 0;
    wire scl;
    wire sda;
    wire done;

    i2c_config_codec_standard dut (
        .clk(clk),
        .reset(reset),
        .scl(scl),
        .sda(sda),
        .done(done)
    );

    reg sda_slave_drive = 0;
    assign sda = sda_slave_drive ? 1'b0 : 1'bz;

    always @(negedge scl) begin
    if (dut.state == 4'd4 || dut.state == 4'd5)
        sda_slave_drive <= 1;
    else
        sda_slave_drive <= 0;
    end

    initial begin
        //1
        reset = 1;
        #200;
        reset = 0;
        //2
        wait(done == 1'b1);
        #1000;
        $stop;
    end

    endmodule