/*******************************************************************************
 * Module: button_edge_detector
 * Description: Detects the falling edge of active-low buttons (DE2 Keys).
 * Generates a single clock cycle pulse (active high) when pressed.
 *******************************************************************************/
module button_edge_detector (
    input wire clk,
    input wire [3:0] keys_in,
    output reg [3:0] pulse_out
);
    // Registers for edge detection
    reg [3:0] keys_sync; // Synchronized button states
    reg [3:0] keys_prev; // Previous button states

    always @(posedge clk) begin
        // State shifts
        keys_prev <= keys_sync;
        keys_sync <= keys_in;
        //Edge detection logic
        // Key 0
        // If key is pressed and was not pressed before, generate pulse
        if (!keys_sync[0] && keys_prev[0]) pulse_out[0] <= 1'b1;
        else pulse_out[0] <= 1'b0;
        // Key 1
        if (!keys_sync[1] && keys_prev[1]) pulse_out[1] <= 1'b1;
        else pulse_out[1] <= 1'b0;
        // Key 2
        if (!keys_sync[2] && keys_prev[2]) pulse_out[2] <= 1'b1;
        else pulse_out[2] <= 1'b0;
        // Key 3
        if (!keys_sync[3] && keys_prev[3]) pulse_out[3] <= 1'b1;
        else pulse_out[3] <= 1'b0;
    end
endmodule