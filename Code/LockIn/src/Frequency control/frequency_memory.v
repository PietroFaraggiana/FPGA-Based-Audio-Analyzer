/*******************************************************************************
 * Module: frequency_memory
 * Description: Stores current frequency state and handles increment/decrement
 * logic based on selected scale.
 *******************************************************************************/
module frequency_memory #(
    parameter FREQUENCY_RANGE = 8192
) (
    input wire clk,
    input wire reset,
    input wire btn_up,
    input wire btn_down,
    input wire btn_scale,
    output reg [$clog2(FREQUENCY_RANGE)-1:0] frequency_out,
    output reg [1:0] scale_out
);
    localparam W = $clog2(FREQUENCY_RANGE);

    // Increment step, same size as frequency_range because it will be added to it
    reg [W-1:0] step_value;

    always @(posedge clk) begin
        if (reset) begin
            frequency_out <= {W{1'b0}};
            scale_out <= 2'd0;
            step_value <= 1;
        end else begin
            // Scale Handling
            if (btn_scale) begin
                case (scale_out)
                    2'd0: begin // Scale is 1, go to 10
                        scale_out <= 2'd1;
                        step_value <= 10;
                    end
                    2'd1: begin // Scale is 10, go to 100
                        scale_out <= 2'd2;
                        step_value <= 100;
                    end
                    2'd2: begin // Scale is 100, go to 1000
                        scale_out <= 2'd3;
                        step_value <= 1000;
                    end
                    2'd3: begin // Scale is 1000, go to 1
                        scale_out <= 2'd0;
                        step_value <= 1; 
                    end
                    default: begin // Error, go to 1
                        scale_out <= 2'd0;
                        step_value <= 1;
                    end
                endcase
            end

            // Frequency Update
            if (btn_up) begin
                // Sum or saturation
                if ((FREQUENCY_RANGE - 1 - frequency_out) >= step_value)
                    frequency_out <= frequency_out + step_value;
                else
                    frequency_out <= FREQUENCY_RANGE - 1; 
            end else if (btn_down) begin
                // Subtraction or lim inf
                if (frequency_out >= step_value)
                    frequency_out <= frequency_out - step_value;
                else
                    frequency_out <= {W{1'b0}};
            end
        end
    end
endmodule