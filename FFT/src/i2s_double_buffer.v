/*******************************************************************************
 * Modulo: i2s_double_buffer
 * 
 * Descrizione:
 * Implementa un meccanismo di double buffering per campioni audio.
 * Mentre un buffer viene riempito con nuovi dati (dall'I2S), l'altro 
 * è disponibile in sola lettura per un'unità di elaborazione (es. un core FFT).
 * Quando il buffer di scrittura è pieno, i ruoli dei due buffer vengono scambiati.
 *
 * Parametri:
 *   - DATA_WIDTH:   Larghezza in bit di ogni campione audio (es. 24 per WM8731).
 *   - BUFFER_DEPTH: Numero di campioni per buffer (es. 512 per la tua FFT).
 *
 * Utilizzo con un core FFT:
 * 1. Il core FFT attende che il segnale `o_fft_data_ready` diventi alto per un ciclo.
 * 2. Quando `o_fft_data_ready` è alto, significa che un nuovo buffer di 
 *    BUFFER_DEPTH campioni è pronto e stabile per la lettura.
 * 3. Il core FFT può iniziare a leggere i dati presentando indirizzi da 0 a 
 *    (BUFFER_DEPTH - 1) su `i_fft_read_addr`.
 * 4. Mentre l'FFT legge, il modulo sta già riempendo l'altro buffer con nuovi
 *    campioni, garantendo un'elaborazione continua senza perdita di dati.
 *
 *******************************************************************************/
module i2s_double_buffer #(
    parameter DATA_WIDTH   = 24,
    parameter BUFFER_DEPTH = 512
) (
    // Interfaccia di Clock e Reset
    input wire                      clk,
    input wire                      reset, // Reset sincrono attivo alto

    // Interfaccia di Scrittura (dal ricevitore I2S)
    input wire                      i_new_sample_valid, // Impulso alto per 1 ciclo quando un nuovo campione è valido
    input wire [DATA_WIDTH-1:0]     i_sample_data,      // Il dato del campione (formato signed)

    // Interfaccia di Lettura (per il core FFT)
    input wire [$clog2(BUFFER_DEPTH)-1:0] i_fft_read_addr,  // Indirizzo da cui l'FFT vuole leggere
    output wire [DATA_WIDTH-1:0]    o_fft_data_out,     // Dato letto dall'FFT

    // Segnale di controllo per l'FFT
    output wire                     o_fft_data_ready    // Impulso alto per 1 ciclo quando un buffer è pieno e pronto
);

    // Larghezza dell'indirizzo calcolata automaticamente
    localparam ADDR_WIDTH = $clog2(BUFFER_DEPTH);

    // Dichiarazione delle due memorie (i due buffer)
    reg [DATA_WIDTH-1:0] buffer_0 [0:BUFFER_DEPTH-1];
    reg [DATA_WIDTH-1:0] buffer_1 [0:BUFFER_DEPTH-1];

    // Registri per gestire puntatori e selettori
    reg [ADDR_WIDTH-1:0] write_addr;       // Indirizzo di scrittura corrente (0 to 511)
    reg                  write_buffer_sel; // 0 -> buffer_0, 1 -> buffer_1
    reg                  read_buffer_sel;  // Buffer attualmente disponibile per la lettura

    // Registro interno per il segnale di output 'ready'
    reg                  o_fft_data_ready_reg;

    // --- Logica di Scrittura e Swap (con Reset Sincrono) ---
    always @(posedge clk) begin
        if (reset) begin
            // Logica di reset: viene eseguita solo al fronte di salita del clock
            // se 'reset' è attivo.
            write_addr           <= 0;
            write_buffer_sel     <= 0;
            read_buffer_sel      <= 1; // Inizia leggendo dal buffer 1 (mentre si scrive su 0)
            o_fft_data_ready_reg <= 0;
        end else begin
            // Logica operativa normale, eseguita ad ogni ciclo di clock
            // se non c'è reset.
            
            // Resetta il flag 'ready' dopo un ciclo
            o_fft_data_ready_reg <= 0;

            if (i_new_sample_valid) begin
                // Scrivi il nuovo campione nel buffer attivo
                if (write_buffer_sel == 1'b0) begin
                    buffer_0[write_addr] <= i_sample_data;
                end else begin
                    buffer_1[write_addr] <= i_sample_data;
                end

                // Controlla se il buffer è pieno
                if (write_addr == BUFFER_DEPTH - 1) begin
                    // Il buffer è pieno, esegui lo SWAP
                    write_addr           <= 0;                  // Resetta l'indirizzo di scrittura
                    write_buffer_sel     <= ~write_buffer_sel;  // Inverti il buffer di scrittura
                    
                    // Il buffer appena riempito diventa quello di lettura
                    read_buffer_sel      <= write_buffer_sel;    
                    
                    // Segnala al core FFT che un nuovo set di dati è pronto
                    o_fft_data_ready_reg <= 1'b1;               
                end else begin
                    // Il buffer non è ancora pieno, incrementa l'indirizzo
                    write_addr <= write_addr + 1;
                end
            end
        end
    end

    // --- Logica di Lettura (Combinatoria) ---
    // Il core FFT può leggere in qualsiasi momento dal buffer designato
    // come 'read_buffer'. Questo MUX seleziona il buffer corretto.
    assign o_fft_data_out = (read_buffer_sel == 1'b0) ? 
                            buffer_0[i_fft_read_addr] : 
                            buffer_1[i_fft_read_addr];

    // Assegnazione finale dell'output
    assign o_fft_data_ready = o_fft_data_ready_reg;

endmodule