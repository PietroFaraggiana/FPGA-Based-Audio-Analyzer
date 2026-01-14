/*******************************************************************************************
* Module : i2c_config_codec_standard
*
* Description: Configures the WM8731 audio codec using an FSM bit-bang I2C protocol.
* In this protocol the FPGA is the master while the CODEC is the slave.
* SCL and SDA use open-drain mode (mandatory on DE2 board). In order to set the CODEC a 
* sequence of 10 bytes is sent to the WM8731 registers.
* After the sequence finishes, 'done' remains high (one shot protocol).
*******************************************************************************************/
module i2c_config_codec_standard (
    input wire clk,
    input wire reset,
    output wire scl, // I2C clock line (open-drain)
    inout wire sda, // I2C data line (open-drain)
    output reg done // Flag
);

    localparam DEVICE_ADDR = 7'b0011010; // WM8731 I2C address
    localparam TOTAL_REGS = 4'd10;

    // Clock divider (100 kHz from 50 MHz) for the I2C protocol
    reg [7:0] clk_div = 8'd0; // 8 bit counter
    reg i2c_tick  = 1'b0; // 200 kHz tick

    always @(posedge clk) begin
        if (reset) begin
            clk_div <= 8'd0; 
            i2c_tick  <= 1'b0;
        end else begin
            if (clk_div == 8'd249) begin
                clk_div <= 8'd0;
                i2c_tick  <= 1'b1;
            end else begin
                clk_div <= clk_div + 8'd1;
                i2c_tick  <= 1'b0;
            end
        end
    end

    // Register values for WM8731 configuration
    reg [15:0] current_reg; // [15:9] Register Address, [8:0] Data
    reg [3:0] reg_index;

    always @(*) begin
        case (reg_index)
            4'd0: current_reg = 16'h1E00; // Reset
            4'd1: current_reg = 16'h0C00; // Power Down control: every 1 enables a chip function, evry 0 disables it.
            4'd2: current_reg = 16'h0815; // Analog Audio Path: 1's are DACSEL (Digital audio sent to output), INSEL (Audio from mic), MICBOOST (+20dB)
            4'd3: current_reg = 16'h0A00; // Digital Audio Path: all 0's (De emphasis, Soft mute, DC filtering)
            4'd4: current_reg = 16'h0E4A; // Digital auduio interface format: master, 24 bit, I2S
            4'd5: current_reg = 16'h1002; // Sampling control: Normal mode (18.432 MHz), BOSR (384fs), 48kHz
            4'd6: current_reg = 16'h1201; // Active control: Digital interface active
            4'd7: current_reg = 16'h0097; // Left line in: 0dB
            4'd8: current_reg = 16'h0297; // Right line in: 0dB
            4'd9: current_reg = 16'h0479; // Headphone L gain (for debugging, playback)
            default: current_reg = 16'h0679; // Headphone R gain
        endcase
    end

    // Open drain managment
    reg sda_out = 1'b1; // Data line output
    reg sda_drive = 1'b1; // 1 FPGA trasmits, 0 Chip transmits (z and chip pulls low for ACK)
    reg scl_drive = 1'b0; // clock control

    // If sda_drive is 1, we drive sda_out, else we set it to high impedance
    assign sda = sda_drive ? sda_out : 1'bz;
    // If scl_drive is 1, we drive SCL low, else we set it to high impedance
    assign scl = scl_drive ? 1'b0 : 1'bz;

    // FSM States
    localparam S_IDLE = 4'd0;
    localparam S_START = 4'd1;
    localparam S_BIT_LOW = 4'd2;
    localparam S_BIT_HIGH= 4'd3;
    localparam S_ACK_LOW = 4'd4;
    localparam S_ACK_HIGH= 4'd5;
    localparam S_STOP1 = 4'd6;
    localparam S_STOP2 = 4'd7;
    localparam S_DONE = 4'd8;

    reg [3:0] state = S_IDLE;
    // Transmission packet: 7 bit address + 1 bit R/W + 16 bit register's data
    reg [23:0] tx_packet;
    // Which bit is being sent
    reg [4:0] bit_index = 5'd23;

    // FSM Logic
    // SCL high: data stable
    // SCL low: data can change
    always @(posedge clk) begin
        if (reset) begin
            state <= S_IDLE;
            reg_index <= 4'd0;
            bit_index <= 5'd23;
            done <= 1'b0;
            sda_out <= 1'b1;
            sda_drive <= 1'b1;
            scl_drive <= 1'b0;
        end
        else if (i2c_tick ) begin
            case (state)
            S_IDLE: begin 
            //Ready to load
                scl_drive <= 1'b0; // Data stable
                sda_out <= 1'b1; 
                sda_drive <= 1'b1; // FPGA drives SDA
                tx_packet <= { DEVICE_ADDR, 1'b0, current_reg[15:8], current_reg[7:0] };
                bit_index <= 5'd23;
                if (!done) state <= S_START;
            end
            S_START: begin 
            // Start condition (rule violation SDA goes low while SCL is high)
                sda_out <= 1'b0;
                state <= S_BIT_LOW;
            end
            S_BIT_LOW: begin
            // Lower SCL, set data
                scl_drive <= 1'b1;
                sda_drive <= 1'b1;
                sda_out <= tx_packet[bit_index];
                state <= S_BIT_HIGH;
            end
            S_BIT_HIGH: begin
            // Read data + ACK
                scl_drive <= 1'b0; // Data stable
                if (bit_index == 5'd16 || bit_index == 5'd8 || bit_index == 5'd0)
                    state <= S_ACK_LOW;
                else begin
                    bit_index <= bit_index - 5'd1;
                    state <= S_BIT_LOW;
                end
            end
            S_ACK_LOW: begin
            // ACK bit from CODEC
                scl_drive <= 1'b1; // Data can change
                sda_drive <= 1'b0;  // Chip drives SDA for ACK
                state <= S_ACK_HIGH;
            end
            S_ACK_HIGH: begin
            // ACK bit read
                scl_drive <= 1'b0; // Data stable
                if (sda == 1'b0) begin // handshake OK (ACK)
                // If not finished, continue sending bits
                    bit_index <= (bit_index == 5'd0) ? 5'd0 : (bit_index - 5'd1);
                    sda_drive <= 1'b1; // FPGA drives SDA
                    if (bit_index == 5'd0) 
                    // Last bit sent, go to STOP1
                        state <= S_STOP1;
                    else 
                        state <= S_BIT_LOW; // Continue sending bits
                end 
                else begin
                    // handshake NOT OK (NACK)
                    state <= S_IDLE; // start again
                end
            end
            S_STOP1: begin
            // Stop condition 1
                scl_drive <= 1'b1; // Data can change
                sda_out <= 1'b0; // SDA low
                state <= S_STOP2;
            end
            S_STOP2: begin
            // Stop condition 2
                scl_drive <= 1'b0; // Data stable
                sda_out <= 1'b1;
                // Check if more registers to configure
                if (reg_index < TOTAL_REGS - 4'd1) begin
                    reg_index <= reg_index + 4'd1;
                    state <= S_IDLE;
                end else begin
                    done <= 1'b1;
                    state <= S_DONE;
                end
            end
            S_DONE: begin
                //Nothing
             end
            endcase
        end
    end

endmodule