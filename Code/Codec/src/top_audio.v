/*******************************************************************************************
* Module : top_audio
*
* Description: Connects the WM8731 codec interface modules to lock-in or FFT processing unit.
* It handles PLL and CDC.
*******************************************************************************************/
module top_audio (
    input wire clk,
    input wire reset,
    
    // Codec Interface
    output wire o_aud_xck, // MCLK (18.432 MHz) to Codec
    input wire i_aud_bclk,
    input wire i_aud_adclrck,
    input wire i_aud_adcdat,
    output wire o_i2c_sclk,
    inout wire io_i2c_sdat,
    // Interface to DSP
    input wire [8:0] i_read_addr,
    output wire [23:0] o_audio_sample,
    output wire o_buffer_ready,
    // Debug
    output wire o_config_done
);

    // PLL Generation (MCLK)
    wire pll_locked;
    audio_pll u_pll (
        .inclk0 (clk),
        .c0 (o_aud_xck),
        .locked (pll_locked)
    );

    // I2C Configuration
    i2c_config_codec_standard u_i2c_config_codec_standard (
        .clk (clk),
        .reset (reset),
        .scl (o_i2c_sclk),
        .sda (io_i2c_sdat),
        .done (o_config_done)
    );

    // I2S Controller
    wire [23:0] i2s_data_bclk;
    wire i2s_valid_bclk;

    i2s_controller u_i2s_controller (
        .bclk (i_aud_bclk),
        .lrclk (i_aud_adclrck),
        .sdata_in (i_aud_adcdat),
        .reset (reset),
        .o_audio_data (i2s_data_bclk),
        .o_audio_valid (i2s_valid_bclk)
    );

    // CDC: BCLK Domain to System Clock Domain
    reg [2:0] valid_sync; // Synchronizer for valid signal
    reg [23:0] audio_data_sys; 
    wire valid_pulse_sys = (valid_sync[1] && !valid_sync[2]); // Rising edge detector
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            valid_sync <= 3'd0;
            audio_data_sys <= 24'd0;
        end else begin
            valid_sync <= {valid_sync[1:0], i2s_valid_bclk}; // Shift register in synchronizer
            if (valid_sync[1] && !valid_sync[2]) begin // Rising edge detected
                audio_data_sys <= i2s_data_bclk;
            end
        end
    end

    // Double Buffer (System Clock Domain)
    i2s_double_buffer #(
        .DATA_WIDTH(24),
        .BUFFER_DEPTH(512)
    ) u_i2s_double_buffer (
        .clk (clk),
        .reset (reset),
        .i_audio_valid (valid_pulse_sys),
        .i_audio_data (audio_data_sys),
        .i_read_addr (i_read_addr),
        .o_data_out (o_audio_sample),
        .o_data_ready (o_buffer_ready)
    );

endmodule