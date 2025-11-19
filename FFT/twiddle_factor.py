import numpy as np

def float_to_q(value, bits):
    """
    Converte un valore in virgola mobile in formato Q1.(bits-1) a virgola fissa.
    Gestisce correttamente il complemento a due.
    """
    # Scala il valore. 1.0 corrisponde al massimo valore positivo.
    # Usiamo 2**(bits - 1) come fattore di scala.
    # Il -1 è per evitare che 1.0 venga mappato sul numero più negativo (overflow in complemento a due)
    limit = 2**(bits - 1)
    q_val = int(round(value * (limit -1) ))
    
    # Converte in complemento a due se il valore è negativo
    if q_val < 0:
        q_val = 2**bits + q_val
    return q_val

def generate_twiddle_factors(N, bits):
    """Genera i twiddle factor per una FFT a N punti e li formatta in esadecimale."""
    # Per una FFT a 512 punti, calcoliamo i primi N/2 = 256 twiddle factor
    twiddle_factors = []
    for k in range(N // 2):
        # Calcola il twiddle factor W_N^k = exp(-2j * pi * k / N)
        angle = -2 * np.pi * k / N
        real_part = np.cos(angle)
        imag_part = np.sin(angle)

        # Converte le parti reale e immaginaria in formato Q1.23
        real_q = float_to_q(real_part, bits)
        imag_q = float_to_q(imag_part, bits)

        # Formatta i valori come stringhe esadecimali di 'bits/4' caratteri (es. 6 per 24 bit)
        hex_chars = bits // 4
        real_hex = format(real_q, f'0{hex_chars}x')
        imag_hex = format(imag_q, f'0{hex_chars}x')

        # Combina la parte reale e immaginaria in un'unica stringa a 48 bit
        combined_hex = f"{real_hex}{imag_hex}"
        twiddle_factors.append(combined_hex)
        
    return twiddle_factors

if __name__ == "__main__":
    N = 512      # Numero di punti della FFT
    BITS = 24    # Numero di bit per la parte reale e immaginaria
    FILENAME = "twiddle_factors.hex" # Nome del file di output

    print(f"Generazione dei twiddle factor per FFT a {N} punti...")
    factors = generate_twiddle_factors(N, BITS)

    # Invece di stampare codice Verilog, scriviamo i valori esadecimali
    # direttamente in un file, uno per riga.
    try:
        with open(FILENAME, 'w') as f:
            # Aggiungiamo un'intestazione al file per documentazione
            f.write(f"// File: {FILENAME}\n")
            f.write(f"// Twiddle factors per FFT a {N} punti\n")
            f.write(f"// Formato: {BITS*2}-bit hex (Q1.{BITS-1} real, Q1.{BITS-1} imag)\n\n")
            
            # Scrive ogni valore su una nuova riga
            for hex_value in factors:
                f.write(f"{hex_value}\n")
        
        print(f"File '{FILENAME}' generato con successo con {len(factors)} valori.")
    except IOError as e:
        print(f"Errore durante la scrittura del file: {e}")