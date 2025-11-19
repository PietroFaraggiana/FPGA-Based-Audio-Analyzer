/*******************************************************************************
*
* Clocking:
* This module requires a pixel clock of 25.175 MHz. This comes from 800x525pixels*59.94Hz (real 60Hz) = 25.175MHz.
* The 25 MHz clock available on many FPGAs is usually close enough to work with most modern monitors.
*
* Timing Parameters (640x480 @ 60Hz):
* Horizontal:
*
* Visible Area:  640 pixels
* Front Porch:    16 pixels
* Sync Pulse:     96 pixels
* Back Porch:     48 pixels
* Total:         800 pixels
*
*Vertical:
*
* Visible Area:  480 lines
* Front Porch:    10 lines
* Sync Pulse:      2 lines
* Back Porch:     33 lines
* Total:         525 lines
* 
* The front porch is necessary to prepare the beam to go back to the start of the next line or frame;
* the syc pulse is the physical time required for the beam to move back;
* the back porch is the time to get ready (stabilization) to start drawing again.
*******************************************************************************/
module vga_controller (
    // Inputs
    input wire       pixel_clk,  // 25.175 MHz
    input wire       reset_n,    // Active-low

    // Outputs
    output reg       h_sync,     // Active low
    output reg       v_sync,     // Active low
    output wire      video_on,   // Opposite of blanking
    output wire [9:0] pixel_x,   // Horizontal coordinate
    output wire [9:0] pixel_y    // Vertical coordinate
);
    //Parameters for VGA Timing
    localparam H_DISPLAY    = 640;
    localparam H_FP         = 16;
    localparam H_SYNC       = 96;
    localparam H_BP         = 48;
    localparam H_TOTAL      = H_DISPLAY + H_FP + H_SYNC + H_BP;

    localparam V_DISPLAY    = 480;
    localparam V_FP         = 10;
    localparam V_SYNC       = 2;
    localparam V_BP         = 33;
    localparam V_TOTAL      = V_DISPLAY + V_FP + V_SYNC + V_BP;

    // Counters
    reg [9:0] h_count; // 0-799
    reg [9:0] v_count; // 0-524

    always @(posedge pixel_clk or negedge reset_n) begin
        if (!reset_n) begin
            h_count <= 0;
            v_count <= 0;
        end 
        else begin

            if (h_count < H_TOTAL - 1) begin
                h_count <= h_count + 1;
            end 
            else begin
                h_count <= 0;
                if (v_count < V_TOTAL - 1) begin
                    v_count <= v_count + 1;
                end 
                else begin
                    v_count <= 0;
                end
            end
        end
    end
    // Output assignments
    assign pixel_x = h_count;
    assign pixel_y = v_count;
    assign video_on = (h_count < H_DISPLAY) && (v_count < V_DISPLAY);

    // Hsync and Vsync generation
    always @(posedge pixel_clk or negedge reset_n) begin
        if (!reset_n) begin
            h_sync <= 1'b1;
        end 
        else begin
            if ((h_count >= H_DISPLAY + H_FP) && (h_count < H_DISPLAY + H_FP + H_SYNC)) begin
                h_sync <= 1'b0;
            end 
            else begin
                h_sync <= 1'b1;
            end
        end
    end

    always @(posedge pixel_clk or negedge reset_n) begin
        if (!reset_n) begin
            v_sync <= 1'b1;
        end 
        else begin
            if ((v_count >= V_DISPLAY + V_FP) && (v_count < V_DISPLAY + V_FP + V_SYNC)) begin
                v_sync <= 1'b0;
            end 
            else begin
                v_sync <= 1'b1;
            end
        end
    end

endmodule