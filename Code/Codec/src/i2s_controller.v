/************************************************************************************
* Module: i2s_controller
*
* Description: Handles the I2S serial protocol to receive audio data from the 
* WM8731 Codec, parallelizing the data for double buffer. Codec is master. 
***********************************************************************************/
module i2s_controller (
    input wire bclk, // Bit Clock 48kHz*(32+32bit)=3.072MHz
    input wire lrclk, // Left/Right Clock
    input wire sdata_in, // Serial Data In (from Codec ADC)
    input wire reset,
    output reg [23:0] o_audio_data, // Parallel Output (Left Channel)
    output reg o_audio_valid // full parallel data valid flag
);

    // RX logic (sampled on posedge of bclk, if we had tx it would be negedge)
    reg [23:0] shift_reg_rx; // Shift register for receiving data
    reg lrclk_d1; // Delayed LRCLK for edge detection
    reg [4:0] bit_cnt; // bit counter

    always @(posedge bclk) begin
        if (reset) begin
            lrclk_d1 <= 1'b0;
            bit_cnt <= 5'd0;
            shift_reg_rx <= 24'd0;
            o_audio_data <= 24'd0;
            o_audio_valid <= 1'b0;
        end else begin
            lrclk_d1 <= lrclk;
            o_audio_valid <= 1'b0; // Default

            if (lrclk_d1 != lrclk) begin // Edge detected
                bit_cnt <= 5'd0; // Reset counter
                // If LRCLK goes high, we just finished receiving Left channel
                if (lrclk == 1'b1) begin
                    o_audio_data <= shift_reg_rx;
                    o_audio_valid <= 1'b1;
                end
            end else begin
                // Else bit counter increment and shift data
                if (bit_cnt < 5'd24) begin
                    bit_cnt <= bit_cnt + 5'd1;
                    shift_reg_rx <= {shift_reg_rx[22:0], sdata_in};
                end
            end
        end
    end
endmodule