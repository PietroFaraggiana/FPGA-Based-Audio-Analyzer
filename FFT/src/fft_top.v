/*******************************************************************************
 * Modulo: fft_top
 * 
 * Descrizione:
 *   Modulo top-level per l'implementazione di una FFT a 512 punti su FPGA.
 *   Questo modulo istanzia e collega tutti i sottosistemi necessari:
 *   1. i2s_double_buffer:   Cattura e bufferizza i campioni audio in ingresso.
 *   2. fft_controller:     Orchestra l'intero processo della FFT.
 *   3. fft_working_ram:    Memoria a doppia porta per i calcoli "in-place".
 *   4. twiddle_factor_rom: Fornisce i coefficienti (twiddle factor) necessari.
 *   5. fft_butterfly:      Esegue il calcolo fondamentale radix-2.
 *   6. magnitude_approximator: Calcola la magnitudo dei risultati complessi.
 *
 * Flusso dei Dati:
 *   - I campioni audio entrano nel `i2s_double_buffer`.
 *   - Quando un buffer è pieno, `fft_controller` viene notificato.
 *   - Il controller legge i campioni, li riordina (bit-reversal) e li scrive
 *     nella `fft_working_ram`.
 *   - Il controller esegue i 9 stadi della FFT, leggendo operandi dalla RAM,
 *     ottenendo i twiddle factor dalla ROM, passando tutto alla `fft_butterfly`
 *     e scrivendo i risultati di nuovo nella RAM.
 *   - Alla fine, il controller legge i risultati complessi dalla RAM, li passa
 *     al `magnitude_approximator` e rende disponibile il risultato finale in uscita.
 *
 *******************************************************************************/
module fft_top (
    // Interfaccia di Clock e Reset Globale
    input wire                      clk,
    input wire                      reset, // Reset sincrono, attivo alto

    // Interfaccia di Ingresso Audio (dal ricevitore I2S/Codec)
    input wire                      i_new_sample_valid,
    input wire signed [23:0]        i_sample_data,

    // Interfaccia di Uscita (per visualizzazione o ulteriore elaborazione)
    output wire [8:0]               o_fft_magnitude_addr, // Indirizzo del bin di frequenza (0-511)
    output wire [23:0]              o_fft_magnitude_out,  // Magnitudo del bin corrispondente
    output wire                     o_fft_done_pulse,     // Impulso alto per 1 ciclo quando un nuovo set di magnitudini è pronto
    output wire                     o_fft_busy            // Segnale alto mentre la FFT è in corso
);

    // --- Parametri Globali del Progetto ---
    localparam DATA_WIDTH     = 24;
    localparam TWIDDLE_WIDTH  = 24;
    localparam FFT_POINTS     = 512;
    localparam ADDR_WIDTH     = $clog2(FFT_POINTS); // Sarà 9

    // --- Segnali di Interconnessione (Fili) ---

    // Double Buffer <-> Controller
    wire                       fft_data_ready;
    wire [ADDR_WIDTH-1:0]      buffer_read_addr;
    wire [DATA_WIDTH-1:0]      buffer_data_out;

    // Controller -> Working RAM
    wire [ADDR_WIDTH-1:0]      ram_addr_a;
    wire [DATA_WIDTH*2-1:0]    ram_data_in_a;
    wire                       ram_wr_en_a;
    wire [ADDR_WIDTH-1:0]      ram_addr_b;
    wire [DATA_WIDTH*2-1:0]    ram_data_in_b;
    wire                       ram_wr_en_b;
    
    // Working RAM -> Butterfly / Magnitude / Controller
    wire [DATA_WIDTH*2-1:0]    ram_data_out_a;
    wire [DATA_WIDTH*2-1:0]    ram_data_out_b;

    // Controller -> Twiddle ROM
    wire [ADDR_WIDTH-1:0]      twiddle_addr;
    wire [TWIDDLE_WIDTH*2-1:0] twiddle_factor_q;

    // Controller -> Butterfly
    wire                       butterfly_start;
    
    // Butterfly -> Controller
    wire                       butterfly_valid;
    wire [DATA_WIDTH*2-1:0]    butterfly_a_out;
    wire [DATA_WIDTH*2-1:0]    butterfly_b_out;

    // Controller -> Magnitude Approximator
    wire                       magnitude_start;
    
    // Magnitude Approximator -> Controller
    wire                       magnitude_valid;
    wire [DATA_WIDTH-1:0]      magnitude_result;
    
    // Il controller espone il risultato della magnitudo
    wire [DATA_WIDTH-1:0]      controller_magnitude_out;

    // Gestione reset asincrono per la ROM
    wire rst_n = ~reset;


    // --- 1. Buffer di Ingresso Audio ---
    i2s_double_buffer #(
        .DATA_WIDTH   (DATA_WIDTH),
        .BUFFER_DEPTH (FFT_POINTS)
    ) u_double_buffer (
        .clk                (clk),
        .reset              (reset),
        .i_new_sample_valid (i_new_sample_valid),
        .i_sample_data      (i_sample_data),
        .i_fft_read_addr    (buffer_read_addr),
        .o_fft_data_out     (buffer_data_out),
        .o_fft_data_ready   (fft_data_ready)
    );

    // --- 2. Memoria di Lavoro per la FFT ---
    fft_working_ram #(
        .DATA_WIDTH   (DATA_WIDTH * 2), // Memorizza numeri complessi
        .BUFFER_DEPTH (FFT_POINTS)
    ) u_working_ram (
        .clk         (clk),
        .reset       (reset),
        .i_addr_a    (ram_addr_a),
        .i_data_a    (ram_data_in_a),
        .i_wr_en_a   (ram_wr_en_a),
        .o_data_a    (ram_data_out_a),
        .i_addr_b    (ram_addr_b),
        .i_data_b    (ram_data_in_b),
        .i_wr_en_b   (ram_wr_en_b),
        .o_data_b    (ram_data_out_b)
    );

    // --- 3. ROM dei Twiddle Factor ---
    twiddle_factor_rom #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (TWIDDLE_WIDTH * 2) // Dati complessi
    ) u_twiddle_rom (
        .clk              (clk),
        .rst_n            (rst_n),
        .addr             (twiddle_addr),
        .twiddle_factor_q (twiddle_factor_q)
    );

    // --- 4. Unità di Calcolo Butterfly ---
    fft_butterfly #(
        .DATA_WIDTH    (DATA_WIDTH),
        .TWIDDLE_WIDTH (TWIDDLE_WIDTH)
    ) u_butterfly (
        .clk            (clk),
        .reset          (reset),
        .i_start        (butterfly_start),
        .i_data_a       (ram_data_out_a),   // Input A dalla porta A della RAM
        .i_data_b       (ram_data_out_b),   // Input B dalla porta B della RAM
        .i_twiddle      (twiddle_factor_q), // Twiddle factor dalla ROM
        .o_data_a_out   (butterfly_a_out),
        .o_data_b_out   (butterfly_b_out),
        .o_valid        (butterfly_valid)
    );

    // --- 5. Calcolatore di Magnitudo ---
    magnitude_approximator #(
        .DATA_WIDTH (DATA_WIDTH)
    ) u_magnitude (
        .clk             (clk),
        .reset           (reset),
        .i_start         (magnitude_start),
        .i_fft_complex   (ram_data_out_a), // Legge i risultati finali dalla porta A della RAM
        .o_magnitude     (magnitude_result),
        .o_valid         (magnitude_valid)
    );

    // --- 6. Controllore Centrale (FSM) ---
    // Questo modulo è il cervello che connette e dirige tutti gli altri.
    fft_controller #(
        .FFT_POINTS    (FFT_POINTS),
        .DATA_WIDTH    (DATA_WIDTH),
        .TWIDDLE_WIDTH (TWIDDLE_WIDTH)
    ) u_controller (
        .clk                   (clk),
        .reset                 (reset),
        // Connessione al Double Buffer
        .i_data_ready          (fft_data_ready),
        .o_buffer_read_addr    (buffer_read_addr),
        .i_buffer_data_in      (buffer_data_out),
        // Connessione alla Working RAM
        .o_ram_addr_a          (ram_addr_a),
        .o_ram_data_in_a       (ram_data_in_a),
        .o_ram_wr_en_a         (ram_wr_en_a),
        .i_ram_data_out_a      (ram_data_out_a),
        .o_ram_addr_b          (ram_addr_b),
        .o_ram_data_in_b       (ram_data_in_b),
        .o_ram_wr_en_b         (ram_wr_en_b),
        .i_ram_data_out_b      (ram_data_out_b),
        // Connessione alla Twiddle ROM
        .o_twiddle_addr        (twiddle_addr),
        .i_twiddle_factor      (twiddle_factor_q),
        // Connessione alla Butterfly
        .o_butterfly_start     (butterfly_start),
        .i_butterfly_valid     (butterfly_valid),
        .i_butterfly_a_out     (butterfly_a_out),
        .i_butterfly_b_out     (butterfly_b_out),
        // Connessione al Magnitude Approximator
        .o_magnitude_start     (magnitude_start),
        .i_magnitude_valid     (magnitude_valid),
        .i_magnitude_in        (magnitude_result),
        .o_magnitude_out       (controller_magnitude_out),
        // Uscite di stato globali
        .o_fft_busy            (o_fft_busy),
        .o_fft_done            (o_fft_done_pulse)
    );

    // --- Assegnazione delle Uscite Finali ---
    // Durante la fase di calcolo della magnitudo, il controller usa 'o_ram_addr_a'
    // per leggere i dati dalla RAM. Possiamo riutilizzare questo segnale
    // come indirizzo di uscita per il bin di frequenza.
    assign o_fft_magnitude_addr = ram_addr_a;

    // L'uscita di magnitudo dal controller è il risultato finale da esporre.
    assign o_fft_magnitude_out = controller_magnitude_out;

endmodule