/******************************************************************************
* Module: BigBrother
*
* Description: The module contains the pin names assigned by DE2_pin_assignments.qsf
* It is made by combining the audio system, FFT processing, lock-in amplifier and VGA display.
* It uses a multiplexer to switch between FFT and lock-in modes based on a user input switch.
******************************************************************************/

module BigBrother (
    input wire CLOCK_50, 
    input wire [3:0] KEY,
    input wire [17:0] SW,
    output wire [6:0] HEX0, HEX1, HEX2, HEX3,
    output wire [6:0] HEX4, HEX5, HEX6, HEX7,
    output wire [8:0] LEDG,
    output wire [17:0] LEDR,
    inout wire I2C_SDAT,
    output wire I2C_SCLK,
    // Audio CODEC Interface
    output wire AUD_XCK,
    input wire AUD_BCLK,
    output wire AUD_DACDAT,
    output wire AUD_DACLRCK,
    input wire AUD_ADCDAT,
    input wire AUD_ADCLRCK,
    //VGA Interface (ADV7123)
    output wire VGA_HS,
    output wire VGA_VS,
    output wire [9:0] VGA_R,
    output wire [9:0] VGA_G,
    output wire [9:0] VGA_B,
    output wire VGA_CLK,
    output wire VGA_BLANK,
    output wire VGA_SYNC
);

    wire sys_rst_n;
    wire sys_rst_high;
    assign sys_rst_n = KEY[0];
    assign sys_rst_high = ~sys_rst_n;

    reg vga_clk_reg;
    always @(posedge CLOCK_50) begin
        vga_clk_reg <= ~vga_clk_reg;
    end
    wire clk_vga_25m = vga_clk_reg;


    // Multiplexing logic
    wire mode_select = SW[0]; // 0 = Lockin, 1 = FFT

    // LED debugging
    assign LEDR[0] = mode_select;
    assign LEDG[0] = ~mode_select;
    assign LEDG[7] = sys_rst_n;

    wire config_done; 

    assign LEDR[17] = config_done;
    assign AUD_DACDAT = 1'b0;
    assign AUD_DACLRCK = 1'b0;

    // Audio system and memory
    wire [8:0] audio_buffer_read_addr;
    wire [23:0] audio_buffer_data_out;
    wire audio_buffer_ready;
    wire [8:0] fft_read_addr_req;
    wire [8:0] lockin_read_addr_req;

    assign audio_buffer_read_addr = (mode_select) ? fft_read_addr_req : lockin_read_addr_req;

    // Instantations
    top_audio u_top_audio (
        .clk (CLOCK_50),
        .reset (sys_rst_high), 
        .o_aud_xck (AUD_XCK),
        .i_aud_bclk (AUD_BCLK),
        .i_aud_adclrck (AUD_ADCLRCK),
        .i_aud_adcdat (AUD_ADCDAT),
        .o_i2c_sclk (I2C_SCLK),
        .io_i2c_sdat (I2C_SDAT),
        .i_read_addr (audio_buffer_read_addr),
        .o_audio_sample (audio_buffer_data_out),
        .o_buffer_ready (audio_buffer_ready),
        .o_config_done (config_done)
    );
    wire [8:0] fft_vga_addr;
    wire [23:0] fft_vga_mag;
    wire fft_vga_valid;
    wire fft_busy;
    wire fft_done;
    wire fft_start_trigger = audio_buffer_ready && (mode_select == 1'b1);

    fft_top u_fft_top (
        .clk (CLOCK_50),
        .reset (sys_rst_high), 
        .i_buffer_data_ready (fft_start_trigger),
        .i_buffer_data (audio_buffer_data_out),
        .o_buffer_read_addr (fft_read_addr_req),
        .o_fft_magnitude_addr (fft_vga_addr),
        .o_fft_magnitude_out (fft_vga_mag),
        .o_fft_out_valid (fft_vga_valid),
        .o_fft_done_pulse (fft_done),
        .o_fft_busy (fft_busy)
    );
    wire [41:0] lockin_mag_out;
    wire [41:0] lockin_phs_out;
    wire lockin_valid_out;
    wire [6:0] li_hex0, li_hex1, li_hex2, li_hex3;
    wire [6:0] li_hex4, li_hex5, li_hex6, li_hex7;
    wire lockin_start_trigger = audio_buffer_ready && (mode_select == 1'b0);
    lockin_math_top #(
        .BUFFER_DEPTH (512),
        .DATA_WIDTH (24),
        .SIN_WIDTH (18),
        .CORDIC_WIDTH (42),
        .FREQ_RANGE (8192)
    ) u_lockin_math_top (
        .clk (CLOCK_50),
        .key_0 (KEY[0]),
        .key_1 (KEY[1]),
        .key_2 (KEY[2]),
        .key_3 (KEY[3]),
        
        .i_data_ready (lockin_start_trigger),
        .i_buffer_data (audio_buffer_data_out),
        .o_buffer_addr (lockin_read_addr_req),
        .HEX0(li_hex0), .HEX1(li_hex1), .HEX2(li_hex2), .HEX3(li_hex3),
        .HEX4(li_hex4), .HEX5(li_hex5), .HEX6(li_hex6), .HEX7(li_hex7),
        .o_result_valid (lockin_valid_out),
        .o_magnitude (lockin_mag_out),
        .o_phase (lockin_phs_out)
    );

    assign HEX0 = (mode_select == 1'b0) ? li_hex0 : 7'h7F;
    assign HEX1 = (mode_select == 1'b0) ? li_hex1 : 7'h7F;
    assign HEX2 = (mode_select == 1'b0) ? li_hex2 : 7'h7F;
    assign HEX3 = (mode_select == 1'b0) ? li_hex3 : 7'h7F;
    assign HEX4 = (mode_select == 1'b0) ? li_hex4 : 7'h7F;
    assign HEX5 = (mode_select == 1'b0) ? li_hex5 : 7'h7F;
    assign HEX6 = (mode_select == 1'b0) ? li_hex6 : 7'h7F;
    assign HEX7 = (mode_select == 1'b0) ? li_hex7 : 7'h7F;
    
    wire vga_blank_n_net;
    wire vga_sync_n_net;

    vga_top_system u_vga_top_system (
        .clk (CLOCK_50),
        .pixel_clk (clk_vga_25m),
        .reset (sys_rst_high),
        .i_switch_mode (mode_select), 
        .fft_addr (fft_vga_addr),
        .fft_mag (fft_vga_mag),
        .fft_valid (fft_vga_valid),
        .lockin_valid (lockin_valid_out),
        .lockin_mag (lockin_mag_out),
        .lockin_phs (lockin_phs_out),
        .o_vga_hsync (VGA_HS),
        .o_vga_vsync (VGA_VS),
        .o_vga_r (VGA_R),
        .o_vga_g (VGA_G),
        .o_vga_b (VGA_B),
        .o_vga_blank_n (vga_blank_n_net),
        .o_vga_sync_n (vga_sync_n_net),
        .o_pixel_clk (VGA_CLK)
    );

    assign VGA_BLANK = vga_blank_n_net;
    assign VGA_SYNC = vga_sync_n_net;

endmodule