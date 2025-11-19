/*******************************************************************************
*
* Module: fft_butterfly
*
* Description:
*   Modulo computazionale per una butterfly Radix-2 di una FFT.
*   Esegue i calcoli A' = A + B*W e B' = A - B*W su dati complessi.
*   Implementa una pipeline a 3 stadi per migliorare la Fmax.
*   Gestisce la crescita dei bit e previene l'overflow tramite scaling
*   (divisione per 2) ad ogni stadio.
*   Utilizza un reset SINCRONO.
*
* Parametri:
*   DATA_WIDTH = 24: Larghezza in bit della parte reale/immaginaria dei dati.
*   TWIDDLE_WIDTH = 24: Larghezza in bit della parte reale/immaginaria dei twiddle.
*
* Latenza:
*   Il risultato in uscita è valido 3 cicli di clock dopo che 'i_start' è asserito.
*
*******************************************************************************/
module fft_butterfly #(
    parameter DATA_WIDTH = 24,
    parameter TWIDDLE_WIDTH = 24
) (
    // Interfaccia di Clock e Reset
    input wire clk,
    input wire reset, // Ora agisce in modo sincrono

    // Interfaccia di Controllo
    input wire i_start, // Segnale di avvio per il calcolo della butterfly

    // Ingressi Dati (valori complessi)
    input wire signed [DATA_WIDTH*2-1:0] i_data_a, // Ingresso A (A_re, A_im)
    input wire signed [DATA_WIDTH*2-1:0] i_data_b, // Ingresso B (B_re, B_im)
    input wire signed [TWIDDLE_WIDTH*2-1:0] i_twiddle, // Twiddle Factor W (W_re, W_im)

    // Uscite Dati (valori complessi)
    output wire signed [DATA_WIDTH*2-1:0] o_data_a_out, // Uscita A'
    output wire signed [DATA_WIDTH*2-1:0] o_data_b_out, // Uscita B'
    output wire o_valid // Segnale di validità delle uscite
);

    // Larghezza del prodotto della moltiplicazione
    localparam PRODUCT_WIDTH = DATA_WIDTH + TWIDDLE_WIDTH;

    // --- Scomposizione degli ingressi in parte reale e immaginaria ---
    wire signed [DATA_WIDTH-1:0]      a_re = i_data_a[DATA_WIDTH*2-1 -: DATA_WIDTH];
    wire signed [DATA_WIDTH-1:0]      a_im = i_data_a[DATA_WIDTH-1   -: DATA_WIDTH];

    wire signed [DATA_WIDTH-1:0]      b_re = i_data_b[DATA_WIDTH*2-1 -: DATA_WIDTH];
    wire signed [DATA_WIDTH-1:0]      b_im = i_data_b[DATA_WIDTH-1   -: DATA_WIDTH];

    wire signed [TWIDDLE_WIDTH-1:0]   w_re = i_twiddle[TWIDDLE_WIDTH*2-1 -: TWIDDLE_WIDTH];
    wire signed [TWIDDLE_WIDTH-1:0]   w_im = i_twiddle[TWIDDLE_WIDTH-1   -: TWIDDLE_WIDTH];

    // --- Registri di Pipeline ---
    // Stadio 1: Registra gli ingressi
    reg signed [DATA_WIDTH-1:0]      p1_a_re, p1_a_im;
    reg signed [DATA_WIDTH-1:0]      p1_b_re, p1_b_im;
    reg signed [TWIDDLE_WIDTH-1:0]   p1_w_re, p1_w_im;
    reg                              p1_valid;

    // Stadio 2: Registra i risultati della moltiplicazione complessa (B*W)
    reg signed [DATA_WIDTH-1:0]      p2_prod_re, p2_prod_im; // Risultato già scalato
    reg signed [DATA_WIDTH-1:0]      p2_a_re, p2_a_im;
    reg                              p2_valid;
    
    // Stadio 3: Registra i risultati finali
    reg signed [DATA_WIDTH*2-1:0]    p3_a_out, p3_b_out;
    reg                              p3_valid;


    // --- Logica di Calcolo (Pipelined) ---

    // ** STADIO 1: Registra gli ingressi **
    always @(posedge clk) begin
        if (reset) begin
            p1_valid <= 1'b0;
            p1_a_re  <= 0;
            p1_a_im  <= 0;
            p1_b_re  <= 0;
            p1_b_im  <= 0;
            p1_w_re  <= 0;
            p1_w_im  <= 0;
        end else begin
            p1_valid <= i_start;
            if (i_start) begin
                p1_a_re <= a_re;
                p1_a_im <= a_im;
                p1_b_re <= b_re;
                p1_b_im <= b_im;
                p1_w_re <= w_re;
                p1_w_im <= w_im;
            end
        end
    end

    // ** STADIO 2: Moltiplicazione Complessa B * W **
    wire signed [PRODUCT_WIDTH-1:0] term1 = p1_b_re * p1_w_re;
    wire signed [PRODUCT_WIDTH-1:0] term2 = p1_b_im * p1_w_im;
    wire signed [PRODUCT_WIDTH-1:0] term3 = p1_b_re * p1_w_im;
    wire signed [PRODUCT_WIDTH-1:0] term4 = p1_b_im * p1_w_re;

    wire signed [PRODUCT_WIDTH-1:0] prod_re_full = term1 - term2;
    wire signed [PRODUCT_WIDTH-1:0] prod_im_full = term3 + term4;

    wire signed [DATA_WIDTH-1:0] prod_re_scaled = prod_re_full >>> (TWIDDLE_WIDTH-1);
    wire signed [DATA_WIDTH-1:0] prod_im_scaled = prod_im_full >>> (TWIDDLE_WIDTH-1);

    always @(posedge clk) begin
        if (reset) begin
            p2_valid   <= 1'b0;
            p2_a_re    <= 0;
            p2_a_im    <= 0;
            p2_prod_re <= 0;
            p2_prod_im <= 0;
        end else begin
            p2_valid <= p1_valid;
            if (p1_valid) begin
                p2_a_re <= p1_a_re;
                p2_a_im <= p1_a_im;
                p2_prod_re <= prod_re_scaled;
                p2_prod_im <= prod_im_scaled;
            end
        end
    end

    // ** STADIO 3: Addizione/Sottrazione Finale con SCALING per prevenire OVERFLOW **
    wire signed [DATA_WIDTH:0] sum_re = {p2_a_re[DATA_WIDTH-1], p2_a_re} + {p2_prod_re[DATA_WIDTH-1], p2_prod_re};
    wire signed [DATA_WIDTH:0] sum_im = {p2_a_im[DATA_WIDTH-1], p2_a_im} + {p2_prod_im[DATA_WIDTH-1], p2_prod_im};
    
    wire signed [DATA_WIDTH:0] diff_re = {p2_a_re[DATA_WIDTH-1], p2_a_re} - {p2_prod_re[DATA_WIDTH-1], p2_prod_re};
    wire signed [DATA_WIDTH:0] diff_im = {p2_a_im[DATA_WIDTH-1], p2_a_im} - {p2_prod_im[DATA_WIDTH-1], p2_prod_im};

    always @(posedge clk) begin
        if (reset) begin
            p3_valid <= 1'b0;
            p3_a_out <= 0;
            p3_b_out <= 0;
        end else begin
            p3_valid <= p2_valid;
            if (p2_valid) begin
                p3_a_out <= {sum_re[DATA_WIDTH:1], sum_im[DATA_WIDTH:1]};
                p3_b_out <= {diff_re[DATA_WIDTH:1], diff_im[DATA_WIDTH:1]};
            end
        end
    end
    
    // --- Assegnazione delle uscite ---
    assign o_data_a_out = p3_a_out;
    assign o_data_b_out = p3_b_out;
    assign o_valid = p3_valid;

endmodule