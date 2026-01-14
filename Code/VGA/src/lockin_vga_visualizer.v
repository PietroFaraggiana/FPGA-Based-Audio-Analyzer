/*******************************************************************************
* Module: lockin_vga_visualizer
* 
* Description:
* Lock-in Amplifier Output Visualizer (Split Screen: Magnitude & Phase)
* Dual-port RAM with double buffering to prevent tearing.
* Optimized synchronizer.
* Split screen: left (0-319) = magnitude (A), right (320-639) = phase (phi).
*******************************************************************************/

module lockin_vga_visualizer #(
    parameter CORDIC_WIDTH = 42,
    parameter SCREEN_H = 480,
    parameter SCREEN_W = 640
)(
    input wire clk,
    input wire i_valid,
    input wire [CORDIC_WIDTH-1:0] i_magnitude,
    input wire signed [CORDIC_WIDTH-1:0] i_phase,

    input wire pixel_clk,
    input wire i_frame_over, // V-Sync tick for buffer swap
    input wire [9:0] pixel_x,
    input wire [9:0] pixel_y,
    input wire video_on,

    output reg [9:0] VGA_R,
    output reg [9:0] VGA_G,
    output reg [9:0] VGA_B
);

    localparam MAG_SHIFT = 27;
    localparam PHS_SHIFT = 33;

    // RAM Declaration: 2 Banks
    // Siize is 1023 to cover the address gap introduced by bit concatenation.
    // Address space used: 0-319 (Bank0) and 512-831 (Bank1).
    reg [17:0] video_ram [0:1023];

    // Registers for buffer management
    reg active_read_bank; 
    reg active_read_bank_sync1, active_read_bank_sync2;
    wire write_bank_select;

    // Buffer Swap Logic (pixel_clk domain)
    always @(posedge pixel_clk) begin
        if (i_frame_over) begin
            active_read_bank <= ~active_read_bank;
        end
    end

    // Ram write (clk domain)
    // Optimized 2-stage synchronizer
    always @(posedge clk) begin 
        active_read_bank_sync1 <= active_read_bank;
        active_read_bank_sync2 <= active_read_bank_sync1;
    end
    
    // Write to the opposite bank of the one being read
    assign write_bank_select = ~active_read_bank_sync2;

    // Data Scaling & RAM Write (System Domain)
   
    // Write pointer (0 to 319)
    reg [8:0] write_ptr;
    
    // Magnitude scaling and saturation
    wire [CORDIC_WIDTH-1:0] mag_shifted = i_magnitude >> MAG_SHIFT;
    wire [8:0] mag_scaled = (mag_shifted > SCREEN_H-20) ? (SCREEN_H-20) : mag_shifted[8:0];

    // Phase scaling and saturation
    wire signed [CORDIC_WIDTH-1:0] phs_shifted = i_phase >>> PHS_SHIFT; // >>> shift with sing
    wire signed [10:0] phs_calc = 11'sd240 - phs_shifted[10:0];
    wire [8:0] phs_scaled;
    assign phs_scaled = (phs_shifted > 'sd239) ? 9'd0 : (phs_shifted < -'sd239) ? 9'd479 : phs_calc[8:0];

    // Write Pointer Logic Points at new horizontal pixel column every new data
    always @(posedge clk) begin
        if (i_valid) begin
            if (write_ptr == 319)
                write_ptr <= 0;
            else
                write_ptr <= write_ptr + 1;
        end
    end

    // Double buffer
    // Magnitude at offset 0, Phase at offset 320 within the bank
    wire [9:0] write_addr_combined = {write_bank_select, write_ptr}; 

    // RAM Write
    always @(posedge clk) begin
        if (i_valid) begin
            video_ram[write_addr_combined] <= {mag_scaled, phs_scaled};
        end
    end

    // Read Logic and Pipeline (Pixel Clock Domain)
    wire [8:0] read_x_offset = (pixel_x < 320) ? pixel_x[8:0] : (pixel_x - 10'd320);
    wire [9:0] final_read_addr = {active_read_bank, read_x_offset};

    reg [17:0] ram_data_out;
    reg [9:0] pixel_x_d1, pixel_x_d2;
    reg [9:0] pixel_y_d1, pixel_y_d2;
    reg video_on_d1, video_on_d2;

    // #1 Read RAM & Latch Controls
    always @(posedge pixel_clk) begin
        ram_data_out <= video_ram[final_read_addr];
        
        pixel_x_d1 <= pixel_x;
        pixel_y_d1 <= pixel_y;
        video_on_d1 <= video_on;
    end

    // #2 Delay Controls to match RAM data
    always @(posedge pixel_clk) begin
        pixel_x_d2 <= pixel_x_d1;
        pixel_y_d2 <= pixel_y_d1;
        video_on_d2 <= video_on_d1;
    end
function is_char_pixel;
        input [9:0] px, py; //pixel coordinates
        input [9:0] ox, oy; //origin of character
        input [1:0] char_sel; //0 = A, 1 = Phi
        begin

            reg [9:0] dx, dy; 
            
            dx = px - ox; // relative x
            dy = py - oy; // relative y
            
            is_char_pixel = 0; // default
            
            if (dx < 8 && dy < 10) begin 
                case(char_sel)
                    0: // Lettera A
                       if (dy==4 || (dx==0 && dy>1) || (dx==7 && dy>1) || (dy==0 && dx>0 && dx<7)) 
                           is_char_pixel = 1; 
                    1: // Simbolo Phi
                       if (dx == 3 || dx == 4) is_char_pixel = 1;
                       else if ((dy == 1 || dy == 8) && (dx > 1 && dx < 6)) is_char_pixel = 1;
                       else if ((dx == 0 || dx == 7) && (dy > 2 && dy < 7)) is_char_pixel = 1;
                endcase
            end
        end
    endfunction

    wire pixel_is_text;
    //(signal, ox,oy, char_sel)
    assign pixel_is_text = is_char_pixel(pixel_x_d2, pixel_y_d2, 20, 20, 0) || is_char_pixel(pixel_x_d2, pixel_y_d2, 340, 20, 1);

    // Drawing Logic

    wire is_graph_pixel;
    // Determine if current pixel is part of the graph
    wire [8:0] mag_read = ram_data_out[17:9];
    wire [8:0] phs_read = ram_data_out[8:0];
    assign is_graph_pixel = (pixel_x_d2 < 320) ? (pixel_y_d2 == (SCREEN_H - 20 - mag_read)) : (pixel_y_d2 == phs_read);

    always @(posedge pixel_clk) begin
        if (!video_on_d2) begin
            VGA_R <= 10'd0;
            VGA_G <= 10'd0;
            VGA_B <= 10'd0;
        end else begin
            if (pixel_is_text || is_graph_pixel) begin
                // Blue color for Text and Graph
                VGA_R <= 10'd0;
                VGA_G <= 10'd0;
                VGA_B <= 10'd1023; 
            end else if (pixel_x_d2 == 320) begin
                // Black vertical separator line
                VGA_R <= 10'd0;
                VGA_G <= 10'd0;
                VGA_B <= 10'd0;
            end else begin
                // White background
                VGA_R <= 10'd1023;
                VGA_G <= 10'd1023;
                VGA_B <= 10'd1023;
            end
        end
    end

endmodule