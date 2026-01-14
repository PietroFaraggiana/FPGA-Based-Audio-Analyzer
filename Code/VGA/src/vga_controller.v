/*******************************************************************************
* Module: vga_controller
*
* Description:
* VGA Timing Generator for 640x480 resolution @ 60Hz refresh rate.
* Requires a 25 MHz input pixel clock.
* Performs operations:
* - Generates Horizontal (HSYNC) and Vertical (VSYNC) synchronization signals (Active Low).
* - Calculates current Pixel X and Pixel Y coordinates within the active area.
* - Generates a 'video_on' flag for the visible display area.
* - Generates a 'frame_over' pulse at the start of VSYNC to synchronize external logic.
*******************************************************************************/

module vga_controller (
    input wire pixel_clk, // 25 MHz pixel clock
    input wire reset,
    output reg h_sync, // Horizontal sync
    output reg v_sync, // Vertical sync
    output wire video_on, // Video on signal (!blank)
    output wire [9:0] pixel_x, // Current pixel x position
    output wire [9:0] pixel_y, // Current pixel y position
    output wire frame_over // frame is over, start new frame
);
    //VGA 640x480 @ 60Hz timing parameters
    // Horizontal parameters
    localparam H_DISPLAY = 640;
    localparam H_FP = 16;
    localparam H_SYNC = 96;
    localparam H_BP = 48;
    localparam H_TOTAL = 800;
    // Vertical parameters
    localparam V_DISPLAY = 480;
    localparam V_FP = 10;
    localparam V_SYNC = 2;
    localparam V_BP = 33;
    localparam V_TOTAL = 525;

    reg [9:0] h_count;
    reg [9:0] v_count;

    // Counters
    always @(posedge pixel_clk) begin
        if (reset) begin
            h_count <= 0;
            v_count <= 0;
        end else begin
            if (h_count < H_TOTAL - 1)
                h_count <= h_count + 1;
            else begin
                h_count <= 0;
                if (v_count < V_TOTAL - 1)
                    v_count <= v_count + 1;
                else
                    v_count <= 0;
            end
        end
    end

    // Outputs
    assign pixel_x = h_count;
    assign pixel_y = v_count;
    assign video_on = (h_count < H_DISPLAY) && (v_count < V_DISPLAY);
    
    // We can exchane buffers here
    assign frame_over = (v_count == V_DISPLAY + V_FP) && (h_count == 0);

    // Sync generation
    always @(posedge pixel_clk) begin
        if (reset) begin
            h_sync <= 1'b1;
            v_sync <= 1'b1;
        end else begin
            h_sync <= ~((h_count >= H_DISPLAY + H_FP) && (h_count < H_DISPLAY + H_FP + H_SYNC));
            v_sync <= ~((v_count >= V_DISPLAY + V_FP) && (v_count < V_DISPLAY + V_FP + V_SYNC));
        end
    end
endmodule