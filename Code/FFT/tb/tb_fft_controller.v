/*******************************************************************************************
* Module: tb_fft_controller
* Tests: 
* 1. System Reset: Initialize all signals and apply reset to the controller.
* 2. Start FFT Process: Assert i_data_ready to trigger the data loading phase.
* 3. Execution and Completion: Monitor the FSM flow until o_fft_done is asserted.
*******************************************************************************************/
`timescale 1ns/1ps

module tb_fft_controller;

    parameter FFT_POINTS = 512;
    parameter DATA_WIDTH = 24;
    parameter TWIDDLE_WIDTH = 24;
    parameter LOG2_FFT_POINTS = 9;
    parameter BFLY_LATENCY = 3;
    parameter MAG_LATENCY = 2;

    reg clk = 0;
    reg reset;
    reg i_data_ready;
    reg [DATA_WIDTH-1:0] i_buffer_data_in;
    reg [DATA_WIDTH*2-1:0] i_ram_data_out_a;
    reg [DATA_WIDTH*2-1:0] i_ram_data_out_b;
    reg [TWIDDLE_WIDTH*2-1:0] i_twiddle_factor;
    reg i_butterfly_valid;
    reg [DATA_WIDTH*2-1:0] i_butterfly_a_out;
    reg [DATA_WIDTH*2-1:0] i_butterfly_b_out;
    reg i_magnitude_valid;
    reg [DATA_WIDTH-1:0] i_magnitude_in;

    wire [LOG2_FFT_POINTS-1:0] o_buffer_read_addr;
    wire [LOG2_FFT_POINTS-1:0] o_ram_addr_a;
    wire [DATA_WIDTH*2-1:0] o_ram_data_in_a;
    wire o_ram_wr_en_a;
    wire [LOG2_FFT_POINTS-1:0] o_ram_addr_b;
    wire [DATA_WIDTH*2-1:0] o_ram_data_in_b;
    wire o_ram_wr_en_b;
    wire [LOG2_FFT_POINTS-1:0] o_twiddle_addr;
    wire o_butterfly_start;
    wire o_magnitude_start;
    wire [DATA_WIDTH-1:0] o_magnitude_out;
    wire o_fft_busy;
    wire o_fft_done;

    fft_controller #(
        .FFT_POINTS(FFT_POINTS),
        .DATA_WIDTH(DATA_WIDTH),
        .TWIDDLE_WIDTH(TWIDDLE_WIDTH)
    ) dut (
        .clk(clk),
        .reset(reset),
        .i_data_ready(i_data_ready),
        .o_buffer_read_addr(o_buffer_read_addr),
        .i_buffer_data_in(i_buffer_data_in),
        .o_ram_addr_a(o_ram_addr_a),
        .o_ram_data_in_a(o_ram_data_in_a),
        .o_ram_wr_en_a(o_ram_wr_en_a),
        .i_ram_data_out_a(i_ram_data_out_a),
        .o_ram_addr_b(o_ram_addr_b),
        .o_ram_data_in_b(o_ram_data_in_b),
        .o_ram_wr_en_b(o_ram_wr_en_b),
        .i_ram_data_out_b(i_ram_data_out_b),
        .o_twiddle_addr(o_twiddle_addr),
        .i_twiddle_factor(i_twiddle_factor),
        .o_butterfly_start(o_butterfly_start),
        .i_butterfly_valid(i_butterfly_valid),
        .i_butterfly_a_out(i_butterfly_a_out),
        .i_butterfly_b_out(i_butterfly_b_out),
        .o_magnitude_start(o_magnitude_start),
        .i_magnitude_valid(i_magnitude_valid),
        .i_magnitude_in(i_magnitude_in),
        .o_magnitude_out(o_magnitude_out),
        .o_fft_busy(o_fft_busy),
        .o_fft_done(o_fft_done)
    );

    always #10 clk = ~clk;

    reg [DATA_WIDTH*2-1:0] working_ram [0:FFT_POINTS-1];
    always @(posedge clk) begin
        if (o_ram_wr_en_a) working_ram[o_ram_addr_a] <= o_ram_data_in_a;
        i_ram_data_out_a <= working_ram[o_ram_addr_a];
    end

    always @(posedge clk) begin
        if (o_ram_wr_en_b) working_ram[o_ram_addr_b] <= o_ram_data_in_b;
        i_ram_data_out_b <= working_ram[o_ram_addr_b];
    end

    reg [TWIDDLE_WIDTH*2-1:0] twiddle_rom [0:FFT_POINTS-1];
    integer j;
    initial begin
        for (j = 0; j < FFT_POINTS; j = j + 1) twiddle_rom[j] = {j[TWIDDLE_WIDTH-1:0], j[TWIDDLE_WIDTH-1:0]};
    end

    always @(posedge clk) begin
        i_twiddle_factor <= twiddle_rom[o_twiddle_addr];
    end

    always @(o_buffer_read_addr) begin
        i_buffer_data_in = o_buffer_read_addr + 1;
    end

    reg [BFLY_LATENCY-1:0] bfly_cnt;
    reg [DATA_WIDTH*2-1:0] b_tmp_a, b_tmp_b;
    always @(posedge clk) begin
        if (reset) begin
            i_butterfly_valid <= 0;
            bfly_cnt <= 0;
        end else begin
            if (i_butterfly_valid) i_butterfly_valid <= 0;
            if (o_butterfly_start) begin
                b_tmp_a <= i_ram_data_out_a;
                b_tmp_b <= i_ram_data_out_b;
                bfly_cnt <= BFLY_LATENCY - 1;
            end else if (|bfly_cnt) begin
                bfly_cnt <= bfly_cnt - 1;
                if (bfly_cnt == 1) begin
                    i_butterfly_a_out <= b_tmp_a + b_tmp_b;
                    i_butterfly_b_out <= b_tmp_a - b_tmp_b;
                    i_butterfly_valid <= 1;
                end
            end
        end
    end

    reg [MAG_LATENCY-1:0] mag_cnt;
    reg [DATA_WIDTH*2-1:0] m_tmp;
    always @(posedge clk) begin
        if (reset) begin
            i_magnitude_valid <= 0;
            mag_cnt <= 0;
        end else begin
            if (i_magnitude_valid) i_magnitude_valid <= 0;
            if (o_magnitude_start) begin
                m_tmp <= i_ram_data_out_a;
                mag_cnt <= MAG_LATENCY - 1;
            end else if (|mag_cnt) begin
                mag_cnt <= mag_cnt - 1;
                if (mag_cnt == 1) begin
                    i_magnitude_in <= m_tmp[DATA_WIDTH*2-1:DATA_WIDTH] + m_tmp[DATA_WIDTH-1:0];
                    i_magnitude_valid <= 1;
                end
            end
        end
    end

    initial begin
        // 1
        reset = 1;
        i_data_ready = 0;
        i_butterfly_valid = 0;
        i_magnitude_valid = 0;
        #100;
        reset = 0;
        #40;

        // 2
        i_data_ready = 1;
        #20;
        i_data_ready = 0;

        // 3
        wait(o_fft_done);
        #100;
        $stop;
    end

endmodule