/*******************************************************************************
* TESTBENCH DESCRIPTION
*
* This testbench verifies the i2s_double_buffer module.
*
* The initial test sequence performs the following steps:
* 1. Applies a synchronous reset to initialize the DUT.
* 2. Simulates an I2S source by sending `BUFFER_DEPTH` samples to fill
*    the first buffer (buffer_0).
* 3. Verifies that the `o_fft_data_ready` signal pulses high for one
*    clock cycle after the buffer becomes full.
*
* The test then proceeds to verify the simultaneous read/write operation.
*******************************************************************************/
`timescale 1ns / 1ps

module tb_i2s_double_buffer;

    // Parametri
    parameter DATA_WIDTH   = 24;
    parameter BUFFER_DEPTH = 512;
    parameter CLK_PERIOD   = 10;

    // Segnali
    reg                      clk;
    reg                      reset;
    reg                      i_new_sample_valid;
    reg [DATA_WIDTH-1:0]     i_sample_data;
    reg [$clog2(BUFFER_DEPTH)-1:0] i_fft_read_addr;

    wire [DATA_WIDTH-1:0]    o_fft_data_out;
    wire                     o_fft_data_ready;
    
    // Variabile 'i' per il primo ciclo
    integer i;
    // NOTA: 'j' non e' piu' dichiarato qui!

    // Istanza del DUT
    i2s_double_buffer #(
        .DATA_WIDTH(DATA_WIDTH),
        .BUFFER_DEPTH(BUFFER_DEPTH)
    ) dut (
        .clk(clk),
        .reset(reset),
        .i_new_sample_valid(i_new_sample_valid),
        .i_sample_data(i_sample_data),
        .i_fft_read_addr(i_fft_read_addr),
        .o_fft_data_out(o_fft_data_out),
        .o_fft_data_ready(o_fft_data_ready)
    );

    // Clock
    always begin
        #(CLK_PERIOD / 2) clk = ~clk;
    end

    // Processo di stimolo
    initial begin
        // ... (la parte di inizializzazione e FASE 1 rimane identica)
        $display("-------------------------------------------------");
        $display("[%t] Inizio Simulazione del i2s_double_buffer...", $time);
        $display("-------------------------------------------------");
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_i2s_double_buffer);
        clk = 0;
        reset = 1;
        i_new_sample_valid = 0;
        i_sample_data = 0;
        i_fft_read_addr = 0;
        #(CLK_PERIOD * 2);
        reset = 0;
        $display("[%t] Reset rilasciato. Inizio operativita'.", $time);
        #(CLK_PERIOD);

        // --- FASE 1: Riempimento del primo buffer (buffer_0) ---
        $display("[%t] ==> FASE 1: Riempimento del primo buffer (0 -> %d)...", $time, BUFFER_DEPTH-1);
        for (i = 0; i < BUFFER_DEPTH; i = i + 1) begin
            @(posedge clk);
            i_new_sample_valid <= 1;
            i_sample_data      <= i + 1;
            @(posedge clk);
            i_new_sample_valid <= 0;
        end
        
        @(posedge clk);
        $display("[%t] Primo buffer riempito. Controllo o_fft_data_ready...", $time);
        if (o_fft_data_ready === 1'b1) begin
            $display("[%t] SUCCESSO: o_fft_data_ready e' alto come atteso.", $time);
        end else begin
            $display("[%t] ERRORE: o_fft_data_ready e' basso, ma doveva essere alto.", $time);
        end
        
        @(posedge clk);
        if (o_fft_data_ready === 1'b0) begin
            $display("[%t] SUCCESSO: o_fft_data_ready e' tornato basso.", $time);
        end else begin
            $display("[%t] ERRORE: o_fft_data_ready non e' tornato basso dopo un ciclo.", $time);
        end
        
        // --- TEST 2: Lettura del buffer 0 e riempimento simultaneo del buffer 1 ---
        $display("[%t] ==> FASE 2: Lettura del buffer 0 e riempimento del buffer 1...", $time);

        fork
            // Processo A: Simula il core FFT che legge il buffer pronto
            begin : FFT_READ_PROCESS
                integer j; // <-- 'j' e' LOCALE a questo blocco
                $display("[%t]    Processo di lettura (FFT) avviato.", $time);
                for (j = 0; j < BUFFER_DEPTH; j = j + 1) begin
                    @(posedge clk);
                    i_fft_read_addr <= j;
                    #1; 
                    if (o_fft_data_out !== (j + 1)) begin
                        $display("[%t]    ERRORE DI LETTURA! addr=%d, letto=%d, atteso=%d", 
                                 $time, j, o_fft_data_out, j + 1);
                    end
                end
                $display("[%t]    Processo di lettura (FFT) completato.", $time);
            end

            // Processo B: Simula il ricevitore I2S che riempie l'altro buffer
            begin : I2S_WRITE_PROCESS
                integer j; // <-- Questo e' un ALTRO 'j', locale e indipendente
                $display("[%t]    Processo di scrittura (I2S) avviato.", $time);
                for (j = 0; j < BUFFER_DEPTH; j = j + 1) begin
                    @(posedge clk);
                    i_new_sample_valid <= 1;
                    i_sample_data      <= j + 10000;
                    
                    @(posedge clk);
                    i_new_sample_valid <= 0;
                end
                $display("[%t]    Processo di scrittura (I2S) completato.", $time);
            end
        join

        // ... (la parte finale rimane identica)
        @(posedge clk);
        $display("[%t] Secondo buffer riempito. Controllo o_fft_data_ready...", $time);
         if (o_fft_data_ready === 1'b1) begin
            $display("[%t] SUCCESSO: o_fft_data_ready e' alto di nuovo per il secondo buffer.", $time);
        end else begin
            $display("[%t] ERRORE: o_fft_data_ready non si e' attivato per il secondo buffer.", $time);
        end

        #(CLK_PERIOD * 5);
        $display("-------------------------------------------------");
        $display("[%t] Simulazione completata.", $time);
        $display("-------------------------------------------------");
        $finish;
    end

endmodule