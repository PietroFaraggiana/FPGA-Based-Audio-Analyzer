`timescale 1ns / 1ps

module tb_fft_butterfly;

    // -------------------------------------------------------------------------
    // Parametri del Testbench
    // -------------------------------------------------------------------------
    parameter DATA_WIDTH    = 24;
    parameter TWIDDLE_WIDTH = 24;
    parameter CLK_PERIOD    = 10; // Periodo del clock in ns (100 MHz)

    // -------------------------------------------------------------------------
    // Segnali per l'interfaccia del DUT
    // -------------------------------------------------------------------------
    reg                                  clk;
    reg                                  reset;
    reg                                  i_start;
    reg signed [DATA_WIDTH*2-1:0]        i_data_a;
    reg signed [DATA_WIDTH*2-1:0]        i_data_b;
    reg signed [TWIDDLE_WIDTH*2-1:0]     i_twiddle;

    wire signed [DATA_WIDTH*2-1:0]       o_data_a_out;
    wire signed [DATA_WIDTH*2-1:0]       o_data_b_out;
    wire                                 o_valid;
    
    // Variabili interne per la verifica
    integer test_count = 0;
    integer errors = 0;
    
    // -------------------------------------------------------------------------
    // Istanza del DUT (Device Under Test)
    // -------------------------------------------------------------------------
    fft_butterfly #(
        .DATA_WIDTH(DATA_WIDTH),
        .TWIDDLE_WIDTH(TWIDDLE_WIDTH)
    ) uut (
        .clk(clk),
        .reset(reset),
        .i_start(i_start),
        .i_data_a(i_data_a),
        .i_data_b(i_data_b),
        .i_twiddle(i_twiddle),
        .o_data_a_out(o_data_a_out),
        .o_data_b_out(o_data_b_out),
        .o_valid(o_valid)
    );

    // -------------------------------------------------------------------------
    // Generatore di Clock
    // -------------------------------------------------------------------------
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // -------------------------------------------------------------------------
    // Blocco Principale di Stimolo e Verifica
    // -------------------------------------------------------------------------
    initial begin
        // Inizializzazione e Reset
        $display("--- Inizio Simulazione Testbench per fft_butterfly ---");
        reset = 1'b1;
        i_start = 1'b0;
        i_data_a = 0;
        i_data_b = 0;
        i_twiddle = 0;

        repeat (2) @(posedge clk);
        reset = 1'b0;
        $display("[%0t] Reset rilasciato.", $time);
        @(posedge clk);

        // --- INIZIO DEI TEST ---

        // Test 1: Caso semplice con W = 1 + j0
        // A = 10 + j20, B = 5 + j8
        // BW_scaled = B = 5 + j8
        // A' = (A + B)/2 = (15+j28)/2 -> 7 + j14 (divisione intera)
        // B' = (A - B)/2 = (5+j12)/2  -> 2 + j6  (divisione intera)
        apply_and_check(
            10,  20,  // A_re, A_im
            5,    8,  // B_re, B_im
            (1 << (TWIDDLE_WIDTH-1)) - 1, 0, // W_re=1.0, W_im=0 (in formato Q1.(TW-1))
            7,   14,  // Expected A'_re, A'_im
            2,    6   // Expected B'_re, B'_im
        );
        
        // Test 2: Caso con W = 0 - j1
        // A = 100 + j50, B = 20 - j30
        // BW_scaled = B*(-j) = (-30) - j(20)
        // A' = (A + BW)/2 = ( (100+j50) + (-30-j20) )/2 = (70+j30)/2 -> 35 + j15
        // B' = (A - BW)/2 = ( (100+j50) - (-30-j20) )/2 = (130+j70)/2 -> 65 + j35
        apply_and_check(
            100,  50,  // A_re, A_im
            20,  -30,  // B_re, B_im
            0, -(1 << (TWIDDLE_WIDTH-1)), // W_re=0, W_im=-1.0 (in formato Q1.(TW-1))
            35,   15,  // Expected A'_re, A'_im
            65,   35   // Expected B'_re, B'_im
        );

        // Test 3: Caso generico con W ~ 0.707 - j0.707 (rotazione di -45 gradi)
        // A = -100 - j50, B = 80 + j60
        // W_re = 5932525 (0.707... in Q1.23), W_im = -5932525
        // BW_scaled = round( (80+j60)*(0.707-j0.707) ) = round(98.99-j14.14) -> 99 - j14
        // A' = (A + BW)/2 = ( (-100-j50) + (99-j14) )/2 = (-1-j64)/2 -> -1 - j32
        // B' = (A - BW)/2 = ( (-100-j50) - (99-j14) )/2 = (-199-j36)/2 -> -100 - j18
        apply_and_check(
            -100, -50, // A_re, A_im
            80,   60,  // B_re, B_im
            5932525, -5932525, // W_re, W_im per -45 deg in Q1.23
            -1,  -32,  // Expected A'_re, A'_im
            -100, -18   // Expected B'_re, B'_im
        );

        // --- FINE DEI TEST ---
        
        @(posedge clk);
        
        if (errors == 0) begin
            $display("--- SIMULAZIONE COMPLETATA: Tutti i test sono stati SUPERATI! ---");
        end else begin
            $display("--- SIMULAZIONE COMPLETATA: %0d errori trovati. ---", errors);
        end
        
        $finish;
    end
    
    // -------------------------------------------------------------------------
    // Task per applicare stimolo e verificare l'uscita
    // -------------------------------------------------------------------------
    task apply_and_check;
        input signed [DATA_WIDTH-1:0]    a_re_in, a_im_in;
        input signed [DATA_WIDTH-1:0]    b_re_in, b_im_in;
        input signed [TWIDDLE_WIDTH-1:0] w_re_in, w_im_in;
        input signed [DATA_WIDTH-1:0]    exp_a_re, exp_a_im;
        input signed [DATA_WIDTH-1:0]    exp_b_re, exp_b_im;
        
        // Variabili locali al task per i risultati
        reg signed [DATA_WIDTH-1:0] res_a_re, res_a_im;
        reg signed [DATA_WIDTH-1:0] res_b_re, res_b_im;
        
    begin
        test_count = test_count + 1;
        $display("----------------------------------------------------------");
        $display("[%0t] Inizio Test %0d", $time, test_count);
        
        // 1. Applica gli ingressi e il segnale di start
        i_data_a  = {a_re_in, a_im_in};
        i_data_b  = {b_re_in, b_im_in};
        i_twiddle = {w_re_in, w_im_in};
        i_start   = 1'b1;
        
        @(posedge clk);
        i_start = 1'b0; // i_start è un impulso di un ciclo di clock
        
        // 2. Attendi la latenza del DUT (3 cicli di clock)
        repeat (2) @(posedge clk);
        
        // 3. Verifica o_valid e le uscite
        if (o_valid !== 1'b1) begin
            $display("[%0t] ERRORE Test %0d: o_valid non è alto! Trovato: %b, Atteso: 1", 
                     $time, test_count, o_valid);
            errors = errors + 1;
        end else begin
            // Estrai parte reale e immaginaria dalle uscite
            res_a_re = o_data_a_out[DATA_WIDTH*2-1 -: DATA_WIDTH];
            res_a_im = o_data_a_out[DATA_WIDTH-1   -: DATA_WIDTH];
            res_b_re = o_data_b_out[DATA_WIDTH*2-1 -: DATA_WIDTH];
            res_b_im = o_data_b_out[DATA_WIDTH-1   -: DATA_WIDTH];
            
            // Confronta A'
            if (res_a_re !== exp_a_re || res_a_im !== exp_a_im) begin
                $display("[%0t] ERRORE Test %0d: o_data_a_out non corrisponde.", $time, test_count);
                $display("    Trovato: (%d, %d)", res_a_re, res_a_im);
                $display("    Atteso:  (%d, %d)", exp_a_re, exp_a_im);
                errors = errors + 1;
            end
            
            // Confronta B'
            if (res_b_re !== exp_b_re || res_b_im !== exp_b_im) begin
                $display("[%0t] ERRORE Test %0d: o_data_b_out non corrisponde.", $time, test_count);
                $display("    Trovato: (%d, %d)", res_b_re, res_b_im);
                $display("    Atteso:  (%d, %d)", exp_b_re, exp_b_im);
                errors = errors + 1;
            end
        end
        
        if ( (o_valid === 1'b1) && 
             (res_a_re === exp_a_re) && (res_a_im === exp_a_im) &&
             (res_b_re === exp_b_re) && (res_b_im === exp_b_im) ) begin
             $display("[%0t] Test %0d SUPERATO.", $time, test_count);
        end
        
        // Attendi un ciclo per separare i test
        @(posedge clk);
    end
    endtask

endmodule