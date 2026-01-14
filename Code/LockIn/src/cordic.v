/*******************************************************************************
 * Module: cordic
 * 
 * Decription:CORDIC alghoritm vectoring mode. Calculates Magnitude and Phase 
 * from Cartesian coordinates (I, Q) and is 360° valid, compared to the usual
 * CORDIC alghorim due to is_flipped logic.
 *******************************************************************************/
module cordic #(
    parameter WIDTH = 42,
    parameter ITER = 42
)(
    input wire clk,
    input wire reset,
    input wire valid_in,
    input wire signed [WIDTH-1:0] I_in,
    input wire signed [WIDTH-1:0] Q_in,
    output reg valid_out,
    output reg signed [WIDTH-1:0] phase_out,
    output reg [WIDTH-1:0] mag_out
);
    // Guard bits to prevent overflow and maintain 
    localparam GUARD_BITS = 4;
    localparam EXT_WIDTH = WIDTH + GUARD_BITS;
    // Scale factor = 2^(WIDTH-3) = 2^39
    // PI = 3.1415926535... * 2^39 = 1727038317785 (decimal)
    localparam signed [EXT_WIDTH-1:0] PI_CONST = 46'sd1727038317785;
    localparam S_IDLE = 1'b0;
    localparam S_RUN = 1'b1;

    reg signed [EXT_WIDTH-1:0] x, y, z; // Work variable
    reg [5:0] iter_cnt;
    reg state;
    reg is_flipped;
    
    // Arctan LUT
    function signed [EXT_WIDTH-1:0] get_atan_val;
        input [5:0] k;
        begin
            case(k)
                0: get_atan_val = 46'sd431774406365;
                1: get_atan_val = 46'sd254865184517;
                2: get_atan_val = 46'sd134707833089;
                3: get_atan_val = 46'sd68424097458;
                4: get_atan_val = 46'sd34354228498;
                5: get_atan_val = 46'sd17196025091;
                6: get_atan_val = 46'sd8600980548;
                7: get_atan_val = 46'sd4300762413;
                8: get_atan_val = 46'sd2150419356;
                9: get_atan_val = 46'sd1075214389;
                10: get_atan_val = 46'sd537607907;
                11: get_atan_val = 46'sd268804005;
                12: get_atan_val = 46'sd134402008;
                13: get_atan_val = 46'sd67201005;
                14: get_atan_val = 46'sd33600503;
                15: get_atan_val = 46'sd16800251;
                16: get_atan_val = 46'sd8400126;
                17: get_atan_val = 46'sd4200063;
                18: get_atan_val = 46'sd2100031;
                19: get_atan_val = 46'sd1050016;
                20: get_atan_val = 46'sd525008;
                21: get_atan_val = 46'sd262504;
                22: get_atan_val = 46'sd131252;
                23: get_atan_val = 46'sd65626;
                24: get_atan_val = 46'sd32813;
                25: get_atan_val = 46'sd16406;
                26: get_atan_val = 46'sd8203;
                27: get_atan_val = 46'sd4102;
                28: get_atan_val = 46'sd2051;
                29: get_atan_val = 46'sd1025;
                30: get_atan_val = 46'sd513;
                31: get_atan_val = 46'sd256;
                32: get_atan_val = 46'sd128;
                33: get_atan_val = 46'sd64;
                34: get_atan_val = 46'sd32;
                35: get_atan_val = 46'sd16;
                36: get_atan_val = 46'sd8;
                37: get_atan_val = 46'sd4;
                38: get_atan_val = 46'sd2;
                39: get_atan_val = 46'sd1;
                40: get_atan_val = 46'sd1;
                41: get_atan_val = 46'sd0; 
                default: get_atan_val = 46'sd0;
            endcase
        end
    endfunction

    always @(posedge clk) begin
        if (reset) begin
            state <= S_IDLE;
            valid_out <= 1'b0;
            iter_cnt <= 6'd0;
            x <= 'sd0;
            y <= 'sd0;
            z <= 'sd0;
            is_flipped <= 1'b0;
            mag_out <= 'd0;
            phase_out <= 'sd0;
        end else begin
            valid_out <= 1'b0; 

            case (state)
                S_IDLE: begin
                // Bring vector in positive plane (1st and 4th quarter planes)
                    if (valid_in) begin
                        // if I is in the left half plane rotate 180°
                        if (I_in < 'sd0) begin
                            x <= -{{GUARD_BITS{I_in[WIDTH-1]}}, I_in};
                            y <= -{{GUARD_BITS{Q_in[WIDTH-1]}}, Q_in};
                            is_flipped <= 1'b1;
                        end else begin // If not keep as is
                            x <= {{GUARD_BITS{I_in[WIDTH-1]}}, I_in};
                            y <= {{GUARD_BITS{Q_in[WIDTH-1]}}, Q_in};
                            is_flipped <= 1'b0;
                        end
                        z <= 'sd0;
                        iter_cnt <= 6'd0;
                        state <= S_RUN;
                    end
                end

                S_RUN: begin
                    // CORDIC Iteration
                    if (y >= 'sd0) begin // If 1st quarter plane divide by 2^iter_count
                        x <= x + (y >>> iter_cnt);
                        y <= y - (x >>> iter_cnt);
                        // And ad atan(iter_count)
                        z <= z + get_atan_val(iter_cnt);
                    end else begin // If 4th qp do the opposite
                        x <= x - (y >>> iter_cnt);
                        y <= y + (x >>> iter_cnt);
                        z <= z - get_atan_val(iter_cnt);
                    end
                    // Keep doing it until last iteration
                    if (iter_cnt == ITER - 1) begin
                        state <= S_IDLE;
                        valid_out <= 1'b1;
                        
                        // Fix fase
                        // If original vector was in lef half plane the resault is off by PI
                        if (is_flipped) begin
                            if (z > 'sd0) begin
                                // Vector is in the 3rd qp, sub PI
                                phase_out <= z[WIDTH-1:0] - PI_CONST[WIDTH-1:0]; 
                            end else begin
                                // Vectpr is in 2nd qp, add PI (this way the resault is [-PI,+PI] and overflow is prevented)
                                phase_out <= z[WIDTH-1:0] + PI_CONST[WIDTH-1:0];
                            end
                        end else begin
                            phase_out <= z[WIDTH-1:0];
                        end
                        // Fix gain
                        // CORDIC algorithm lenghtens the vector every iteration. For 41 Iterations it is 1.647 longer
                        // If we overflew the original WIDTH, saturate
                        if (x[EXT_WIDTH-1:WIDTH-1] != 'sd0 && x[EXT_WIDTH-1:WIDTH-1] != -1) begin
                             mag_out <= {1'b0, {(WIDTH-1){1'b1}}}; 
                        end else begin
                             mag_out <= x[WIDTH-1:0];
                        end
                    end else begin
                        iter_cnt <= iter_cnt + 6'd1;
                    end
                end
            endcase
        end
    end

endmodule