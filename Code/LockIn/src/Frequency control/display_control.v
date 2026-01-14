/*******************************************************************************
 * Module: display_control
 * Description: Handles the visualization of the lock-in frequency and scale.
 * It converts the binary frequency input into BCD (Double Dabble) and drives 
 * 8x 7-segment displays (HEX0-HEX7).
 * HEX0-3: Frequency Value.
 * HEX4-7: Scale indicator.
 *******************************************************************************/

module display_control #(
    parameter FREQUENCY_RANGE = 8192
) (
    input wire clk,
    input wire reset, // Synchronous Active High Reset
    input wire [1:0] scale_in,
    input wire [$clog2(FREQUENCY_RANGE)-1:0] frequency_in,
    output reg [6:0] hex0,
    output reg [6:0] hex1,
    output reg [6:0] hex2,
    output reg [6:0] hex3,
    output reg [6:0] hex4,
    output reg [6:0] hex5,
    output reg [6:0] hex6,
    output reg [6:0] hex7
);
    localparam W = $clog2(FREQUENCY_RANGE);
    // Internal registers for the Double Dabble algorithm
    // 16 bits for BCD (4 digits x 4 bits) + W bits for binary
    reg [15+W:0] shift_reg; 
    reg [3:0] shift_counter;
    reg [1:0] state;
    // Output buffer
    reg [15:0] bcd_output; 
    // State Machine definitions
    localparam S_IDLE = 2'b00;
    localparam S_CONVERT = 2'b01;
    localparam S_UPDATE = 2'b10;
    // 7 segment decoder function (active low)
    function [6:0] get_hex;
        input [3:0] num;
        begin
            case(num)
                4'h0: get_hex = 7'b1000000; // 0
                4'h1: get_hex = 7'b1111001; // 1
                4'h2: get_hex = 7'b0100100; // 2
                4'h3: get_hex = 7'b0110000; // 3
                4'h4: get_hex = 7'b0011001; // 4
                4'h5: get_hex = 7'b0010010; // 5
                4'h6: get_hex = 7'b0000010; // 6
                4'h7: get_hex = 7'b1111000; // 7
                4'h8: get_hex = 7'b0000000; // 8
                4'h9: get_hex = 7'b0011000; // 9
                default: get_hex = 7'b1111111; // Error
            endcase
        end
    endfunction
    // Binary to BCD Conversion (Double Dabble FSM)
    wire [3:0] bcd_dig0, bcd_dig1, bcd_dig2, bcd_dig3;
    wire [3:0] bcd_dig0_c, bcd_dig1_c, bcd_dig2_c, bcd_dig3_c;
    // Extract current digit from the shift register
    assign bcd_dig0 = shift_reg[W+3:W];
    assign bcd_dig1 = shift_reg[W+7:W+4];
    assign bcd_dig2 = shift_reg[W+11:W+8];
    assign bcd_dig3 = shift_reg[W+15:W+12];
    // Add 3 if value >= 5
    assign bcd_dig0_c = (bcd_dig0 >= 5) ? (bcd_dig0 + 4'd3) : bcd_dig0;
    assign bcd_dig1_c = (bcd_dig1 >= 5) ? (bcd_dig1 + 4'd3) : bcd_dig1;
    assign bcd_dig2_c = (bcd_dig2 >= 5) ? (bcd_dig2 + 4'd3) : bcd_dig2;
    assign bcd_dig3_c = (bcd_dig3 >= 5) ? (bcd_dig3 + 4'd3) : bcd_dig3;

    always @(posedge clk) begin
        if (reset) begin
            state <= S_IDLE;
            shift_counter <= 0;
            shift_reg <= 0;
            bcd_output <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    // Clear the upper BCD bits
                    shift_reg <= {16'b0, frequency_in};
                    // We will need to shift W times
                    shift_counter <= W;
                    state <= S_CONVERT;
                end

                S_CONVERT: begin
                    // Take converted values and shift
                    shift_reg <= {bcd_dig3_c, bcd_dig2_c, bcd_dig1_c, bcd_dig0_c, shift_reg[W-1:0]} << 1;
                    // Shift till over
                    if (shift_counter == 1) begin
                        state <= S_UPDATE;
                    end else begin
                        shift_counter <= shift_counter - 1;
                    end
                end

                S_UPDATE: begin
                    // Store the result to be displayed
                    bcd_output <= shift_reg[W+15:W];
                    state <= S_IDLE; // Start over
                end
                
                default: state <= S_IDLE;
            endcase
        end
    end

    // Output Decoding
    always @(posedge clk) begin
        if (reset) begin
            hex0 <= 7'b1111111;
            hex1 <= 7'b1111111;
            hex2 <= 7'b1111111;
            hex3 <= 7'b1111111;
            hex4 <= 7'b1111111;
            hex5 <= 7'b1111111;
            hex6 <= 7'b1111111;
            hex7 <= 7'b1111111;
        end else begin
            // Update Frequency Display based on BCD output
            hex0 <= get_hex(bcd_output[3:0]);
            hex1 <= get_hex(bcd_output[7:4]);
            hex2 <= get_hex(bcd_output[11:8]);
            hex3 <= get_hex(bcd_output[15:12]);
            // Update Scale Display based on scale_in
            case (scale_in)
                2'b00: begin 
                    hex4 <= get_hex(4'd1); 
                    hex5 <= get_hex(4'd0); 
                    hex6 <= get_hex(4'd0); 
                    hex7 <= get_hex(4'd0); 
                end
                2'b01: begin 
                    hex4 <= get_hex(4'd0); 
                    hex5 <= get_hex(4'd1); 
                    hex6 <= get_hex(4'd0); 
                    hex7 <= get_hex(4'd0); 
                end
                2'b10: begin 
                    hex4 <= get_hex(4'd0); 
                    hex5 <= get_hex(4'd0); 
                    hex6 <= get_hex(4'd1); 
                    hex7 <= get_hex(4'd0); 
                end
                2'b11: begin 
                    hex4 <= get_hex(4'd0); 
                    hex5 <= get_hex(4'd0); 
                    hex6 <= get_hex(4'd0); 
                    hex7 <= get_hex(4'd1); 
                end
            endcase
        end
    end

endmodule