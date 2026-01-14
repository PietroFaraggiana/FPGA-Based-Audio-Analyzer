/*******************************************************************************
* Module: fft_vga_visualizer
* 
* Description:
* FFT VGA Visualizer
* Dual-port RAM with double buffering to prevent screen tearing.
* 64 pixels to the sides, 1 pixel black border at the bottom of the screen. 
* Each of the 512 fourier points takes a pixel, not cut to 256 points to check simmetry.
*******************************************************************************/

module fft_vga_visualizer (
    input wire clk,
    input wire [8:0] i_fft_addr, // Address from FFT module
    input wire [23:0] i_fft_mag, // Magnitude from FFT module
    input wire i_fft_valid,

    input wire pixel_clk,
    input wire i_frame_over, // V-Sync tick for buffer swap
    input wire [9:0] pixel_x,
    input wire [9:0] pixel_y,
    input wire video_on,

    output reg [9:0] VGA_R,
    output reg [9:0] VGA_G,
    output reg [9:0] VGA_B
);

    localparam SCREEN_HEIGHT = 480;
    //640 px-512 elements = 128 px margin -> 64 px each side
    localparam H_OFFSET = 10'd64; 
    parameter MAG_SCALE_SHIFT = 10; 

    // Ram Declaration: 2 banks of 512x9 bits each
    reg [8:0] video_ram [0:1023];
    
    // Registers for buffer management
    reg active_read_bank; 
    reg active_read_bank_sync1, active_read_bank_sync2;
    wire write_bank_select;

    // Buffer Swap Logic (pixel_clk)
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
    
    // FFT data is written to the opposite bank to the one being read
    assign write_bank_select = ~active_read_bank_sync2;
    // Magnitude scaling for visualization (480 pixel=9 bits)
    wire [23:0] shifted_mag = i_fft_mag >> MAG_SCALE_SHIFT;
    // Magnitude still has 14 bits, we saturate at 480 ( shifting by 14 bits before would lose too much info on smaller values)
    wire [8:0] ram_data_in = (shifted_mag > SCREEN_HEIGHT) ? 9'd480 : shifted_mag[8:0];
    // Concatenate bank select with FFT address
    wire [9:0] final_write_addr = {write_bank_select, i_fft_addr};

    always @(posedge clk) begin
        if (i_fft_valid) begin
            video_ram[final_write_addr] <= ram_data_in;
        end
    end

    // Read logic (pixel_clk domain)
    wire [9:0] read_addr_offset = pixel_x - H_OFFSET; //start drawing from px 64
    wire [9:0] final_read_addr = {active_read_bank, read_addr_offset[8:0]};
    
    reg [8:0] ram_data_out; // Data read from RAM
    reg pixel_in_range_d1; // Delayed range check
    reg [8:0] bar_height; // Final masked height

    // Pipeline
    // #1 Ram Read (Avaiable next cycle)
    always @(posedge pixel_clk) begin
        ram_data_out <= video_ram[final_read_addr];
    end

    // Check if we are in drwaing range
    always @(posedge pixel_clk) begin
        if (pixel_x >= H_OFFSET && pixel_x < (H_OFFSET + 512)) 
            pixel_in_range_d1 <= 1'b1;
        else 
            pixel_in_range_d1 <= 1'b0;
    end

    // # 2 If in drawing range, draw
    always @(posedge pixel_clk) begin
        if (pixel_in_range_d1)
            bar_height <= ram_data_out;
        else
            bar_height <= 9'd0;
    end

    // Since RAM read + range flag takes 2 clock cycles total we must delay pixel_y and video_on by 2 cycles
    reg [9:0] pixel_y_d1, pixel_y_d2;
    reg video_on_d1, video_on_d2;
    
    // Pipeline delays
    always @(posedge pixel_clk) begin
        // Pipeline Stage 1
        pixel_y_d1 <= pixel_y;
        video_on_d1 <= video_on;

        // Pipeline Stage 2
        pixel_y_d2 <= pixel_y_d1;
        video_on_d2 <= video_on_d1;
    end

    // Drawing Logic
    // Bar drawing starts from top, px y 0 is at the top
    wire is_bar_pixel = (pixel_y_d2 >= (SCREEN_HEIGHT - bar_height));

    always @(posedge pixel_clk) begin
        if (!video_on_d2) begin 
            // white
            VGA_R <= 10'd0; 
            VGA_G <= 10'd0; 
            VGA_B <= 10'd0;
        end else begin
            if (bar_height > 0 && is_bar_pixel) begin
                // Blue bars
                VGA_R <= 10'd0; 
                VGA_G <= 10'd0; 
                VGA_B <= 10'd1023;
            end else begin
                // White background
                VGA_R <= 10'd1023; 
                VGA_G <= 10'd1023; 
                VGA_B <= 10'd1023;
                
                // Black border at the bottom of the screen
                if (pixel_y_d2 == 479) begin
                    VGA_R <= 0; 
                    VGA_G <= 0; 
                    VGA_B <= 0;
                end
            end
        end
    end

endmodule