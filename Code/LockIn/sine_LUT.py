import numpy as np

def float_to_q(value, bits):
    limit = 2**(bits - 1)
    q_val = int(round(value * (limit - 1)))
    
    if q_val < 0:
        q_val = 2**bits + q_val
    return q_val

def generate_sine_lut(N, bits):
    sine_values = []
    hex_chars = (bits + 3) // 4 
    
    for i in range(N):
        angle = 2 * np.pi * i / N
        sin_val = np.sin(angle)
        
        sin_q = float_to_q(sin_val, bits)
        sin_hex = format(sin_q, f'0{hex_chars}x')
        
        sine_values.append(sin_hex)
        
    return sine_values

if __name__ == "__main__":
    N, BITS, FILENAME = 1024, 18, "ddfs_sin_lut.hex"

    values = generate_sine_lut(N, BITS)

    with open(FILENAME, 'w') as f:
        for hex_value in values:
            f.write(f"{hex_value}\n")        
    print(f"File '{FILENAME}' generated, {len(values)} elements.")
