/*******************************************************************************
* Module: vga_top_system
* 
* Description:
* Top-level module for the VGA visualization system.
* Selects between FFT and Lock-in Amplifier visualization modes.
*******************************************************************************/

module vga_top_system (
    input wire clk,
    input wire pixel_clk,
    input wire reset,
    input wire i_switch_mode, // 0 = Lock-in, 1 = FFT
    // Inputs from FFT Module
    input wire [8:0] fft_addr,
    input wire [23:0] fft_mag,
    input wire fft_valid,
    // Inputs from Lock-in Module
    input wire lockin_valid,
    input wire [41:0] lockin_mag,
    input wire [41:0] lockin_phs,
    // VGA Physical Outputs for Altera DE2
    output wire o_vga_hsync,
    output wire o_vga_vsync,
    output wire [9:0] o_vga_r,
    output wire [9:0] o_vga_g,
    output wire [9:0] o_vga_b,
    output wire o_vga_blank_n,
    output wire o_vga_sync_n,
    output wire o_pixel_clk
);

    // Internal VGA Controller Signals
    wire [9:0] pixel_x;
    wire [9:0] pixel_y;
    wire video_on;
    wire frame_over; // Signal to trigger buffer swap

    // Visualizer Outputs
    wire [9:0] fft_r, fft_g, fft_b;
    wire [9:0] lockin_r, lockin_g, lockin_b; 

    // VGA Controller
    vga_controller u_vga_controller (
        .pixel_clk (pixel_clk),
        .reset (reset),
        .h_sync (o_vga_hsync),
        .v_sync (o_vga_vsync),
        .video_on (video_on),
        .pixel_x (pixel_x),
        .pixel_y (pixel_y),
        .frame_over (frame_over)
    );

    // FFT Visualizer
    fft_vga_visualizer U_fft_vga_visualizer (
        .clk (clk),
        .i_fft_addr (fft_addr),
        .i_fft_mag (fft_mag),
        .i_fft_valid (fft_valid),
        .pixel_clk (pixel_clk),
        .i_frame_over (frame_over),
        .pixel_x (pixel_x),
        .pixel_y (pixel_y),
        .video_on (video_on),
        .VGA_R (fft_r),
        .VGA_G (fft_g),
        .VGA_B (fft_b)
    );

    // 3. Lock-In Visualizer
    lockin_vga_visualizer #(
        .CORDIC_WIDTH(42),
        .SCREEN_H(480),
        .SCREEN_W(640)
    ) u_lockin_vga_visualizer (
        .clk (clk),
        .i_valid (lockin_valid),
        .i_magnitude (lockin_mag),
        .i_phase (lockin_phs),
        .pixel_clk (pixel_clk),
        .i_frame_over (frame_over),
        .pixel_x (pixel_x),
        .pixel_y (pixel_y),
        .video_on (video_on),
        .VGA_R (lockin_r),
        .VGA_G (lockin_g),
        .VGA_B (lockin_b)
    );

    // Multiplexer and DE2 Outputs
    // Switch between modes
    assign o_vga_r = (i_switch_mode) ? fft_r : lockin_r;
    assign o_vga_g = (i_switch_mode) ? fft_g : lockin_g;
    assign o_vga_b = (i_switch_mode) ? fft_b : lockin_b;

    // Control signals
    // Active Low: 0 turns off colors during blanking
    assign o_vga_blank_n = video_on;
    
    // 1 to disable Sync-on-Green
    assign o_vga_sync_n = 1'b1;

    // Invert clock for DAC to ensure signal stability/hold time
    assign o_pixel_clk = ~pixel_clk;

endmodule