# FPGA Speech and Spectrum Analyzer (Altera DE2)

This repository hosts the Verilog HDL source code and supporting documentation for a DSP project implemented on the Altera DE2 development board using Verilog HDL. The system functions as a dual-mode spectrum and I/Q analyzer, processing real-time audio input and visualizing the results via a VGA interface.

---

## Project Overview and Objectives

The primary goal of this project is to integrate various hardware and software components to perform sophisticated signal analysis in a controlled laboratory environment.

* **Real-time Acquisition:** Interface with an external microphone for continuous audio sampling.
* **Signal Processing:** Execute a Fast Fourier Transform (FFT) on the acquired data.
* **Visual Output:** Drive a VGA display to render analysis results graphically.
* **Dual-Mode Operation:** Provide two distinct modes of analysis (Full Spectrum and Selective I/Q).

