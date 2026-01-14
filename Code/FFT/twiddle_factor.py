import numpy as np

def float_to_q(value, bits):
    limit = 2**(bits - 1)
    q_val = int(round(value * (limit - 1)))
    if q_val < 0:
        q_val = 2**bits + q_val
    return q_val

def generate_twiddle_factors(N, bits):
    factors = []
    h = bits // 4 
    
    for k in range(N // 2):
        angle = -2 * np.pi * k / N
        rq = float_to_q(np.cos(angle), bits)
        iq = float_to_q(np.sin(angle), bits)
        
        factors.append(f"{rq:0{h}x}{iq:0{h}x}")
        
    return factors

if __name__ == "__main__":
    N, BITS, FILENAME = 512, 24, "twiddle_factors.hex"
    
    factors = generate_twiddle_factors(N, BITS)

    with open(FILENAME, 'w') as f:
        for val in factors:
            f.write(f"{val}\n")
    
    print(f"File '{FILENAME}' generated ({len(factors)} elements).")