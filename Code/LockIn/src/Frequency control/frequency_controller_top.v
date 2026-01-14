/*******************************************************************************
 * Module: frequency_controller_top
 *******************************************************************************/
module frequency_controller_top #(
    parameter FREQUENCY_RANGE = 8192,
    parameter W = 13
) (
    input wire clk,
    input wire key_0,
    input wire key_1,
    input wire key_2,
    input wire key_3,
    
    output wire reset_active, // Debug
    output wire [W-1:0] frequency_out,
    
    output wire [6:0] HEX0,
    output wire [6:0] HEX1,
    output wire [6:0] HEX2,
    output wire [6:0] HEX3,
    output wire [6:0] HEX4,
    output wire [6:0] HEX5,
    output wire [6:0] HEX6,
    output wire [6:0] HEX7
);

    wire [3:0] keys_in;
    wire [3:0] pulse_out;
    wire [1:0] scale_current;
    assign keys_in = {key_3, key_2, key_1, key_0}; 
    assign reset_active = pulse_out[0];

    // Button
    button_edge_detector u_buttons (
        .clk(clk),
        .keys_in(keys_in),
        .pulse_out(pulse_out)
    );

    // Frequency
    frequency_memory #(
        .FREQUENCY_RANGE(FREQUENCY_RANGE)
    ) u_freq_mem (
        .clk(clk),
        .reset(pulse_out[0]),
        .btn_up(pulse_out[1]),
        .btn_down(pulse_out[2]),
        .btn_scale(pulse_out[3]),
        .frequency_out(frequency_out),
        .scale_out(scale_current)
    );

    // Display
    display_control #(
        .FREQUENCY_RANGE(FREQUENCY_RANGE) 
    ) u_display (
        .clk(clk),
        .reset(pulse_out[0]),
        .scale_in(scale_current),
        .frequency_in(frequency_out),
        .hex0(HEX0), .hex1(HEX1), .hex2(HEX2), .hex3(HEX3),
        .hex4(HEX4), .hex5(HEX5), .hex6(HEX6), .hex7(HEX7)
    );
endmodule