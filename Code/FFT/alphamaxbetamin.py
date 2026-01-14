import numpy as np
import matplotlib.pyplot as plt

alpha = 1.0
beta = 0.375
theta = np.linspace(0, 2*np.pi, 2000)

x_true = np.cos(theta)
y_true = np.sin(theta)
r_true = 1.0

abs_x = np.abs(x_true)
abs_y = np.abs(y_true)
maximum = np.maximum(abs_x, abs_y)
minimum = np.minimum(abs_x, abs_y)

r_approx = alpha * maximum + beta * minimum

x_approx = r_approx * np.cos(theta)
y_approx = r_approx * np.sin(theta)

error = (r_approx - r_true) / r_true * 100
max_err = np.max(np.abs(error))
avg_err = np.mean(np.abs(error))

print(f"Errore Massimo: {max_err:.2f}%")
print(f"Errore Medio: {avg_err:.2f}%")

plt.figure(figsize=(8, 8))
plt.plot(x_true, y_true, 'k--', linewidth=1.5, label='Ideal Magnitude ($|Z|=1$)')
plt.plot(x_approx, y_approx, 'r-', linewidth=2, label=rf'Approx ($1 \cdot Max + 0.375 \cdot Min$)')
plt.title(f"Magnitude Approximation Accuracy\nMax Error: {max_err:.2f}%", fontsize=14)
plt.xlabel("Real Part (I)", fontsize=12)
plt.ylabel("Imaginary Part (Q)", fontsize=12)
plt.axhline(0, color='gray', linewidth=0.5)
plt.axvline(0, color='gray', linewidth=0.5)
plt.grid(True, linestyle=':', alpha=0.6)
plt.legend(loc='upper right', fontsize=12)
plt.axis('equal')
plt.xlim(-1.2, 1.2)
plt.ylim(-1.2, 1.2)
plt.savefig("magnitude_error.png", dpi=300)
plt.show()