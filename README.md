# Real-Time Audio Visualizer on FPGA

A real-time digital audio visualizer implemented entirely in SystemVerilog on a **Basys 3 (Xilinx Artix-7)** FPGA. Audio is sampled from a microphone via the on-board XADC, transformed into the frequency domain by a custom 32-point Radix-2 DIT FFT engine with 16 parallel butterfly units, and rendered as a symmetric mirrored bar graph on a VGA monitor at 640×480 @ 60 Hz.

## Demo

https://github.com/user-attachments/assets/9ac232ad-91ea-4fb0-a2b0-37edfbde09d6

## Block Diagram

<!-- To add a block diagram:
     1. Export/save your diagram as a PNG or SVG (e.g., block_diagram.png)
     2. Place it in this directory
     3. Uncomment the line below:
-->
<!-- ![Block Diagram](block_diagram.png) -->

```
Mic ─→ audio_input ─→ time_filter ─→ frame_buffer ─→ FFT ─→ mag_calc ─→ ping_pong_buf ─→ graphics ─→ VGA
          (XADC)       (LPF/HPF)      (32-deep)    (32-pt)  (|Re|+|Im|)  (double buf)   (decay+render)
                           ↑
                       Switches
```

## Architecture

| Module | File | Description |
|--------|------|-------------|
| **audio_input** | `audio_input.sv` | Wraps the Xilinx XADC IP to sample the mic at ~39 kHz. Converts to signed 16-bit audio and drives an AXI4-Stream Master interface. |
| **time_filter** | `time_filter.sv` | Switchable 5-tap Gaussian LPF and HPF. Acts as a continuous AXI4-Stream passthrough, automatically stalling upstream when backpressure is applied. |
| **frame_buffer** | `frame_buffer.sv` | Sinks the continuous serial AXI-Stream audio and converts it into parallel arrays of 32 samples. Exerts hardware backpressure (`tready = 0`) while holding a complete frame for the FFT. |
| **FFT** | `FFT.sv` | Custom 32-point Radix-2 Decimation-in-Time FFT. Uses 16 parallel `bfly` units recursively over 5 stages. Drives a massive parallel AXI-Stream bus out to the Ping-Pong buffer. |
| **bfly** | `bfly.sv` | Radix-2 butterfly unit. Computes A + B×W and A − B×W using Q15 fixed-point twiddle factors. |
| **mag_calc** | `mag_calc.sv` | Combinational magnitude approximation using `\|Re\| + \|Im\|`. |
| **ping_pong_buffer** | `pingpongbuffer.sv` | The architectural boundary bridging the AXI-Stream DSP datapath to the Video Memory-Mapped domain. Latches FFT magnitudes into one buffer while the VGA reads the other, preventing screen tearing. |
| **graphics** | `graphics.sv` | Bar graph renderer with peak-hold gravity animation. Renders 32 mirrored bars. |
| **vga_timing** | `vga_timing.sv` | Generates standard 640×480 @ 60 Hz VGA timing signals. |

## Key Design Decisions

- **AXI4-Stream Protocol & Hardware Backpressure:** The entire DSP datapath (ADC -> FIR -> Buffer -> FFT -> Memory) was architected using the industry-standard AMBA AXI4-Stream protocol (`tdata`, `tvalid`, `tready`). This establishes robust hardware backpressure: if the FFT is actively computing and cannot accept new data, it pulls `tready` low, safely stalling the upstream frame buffer and FIR filter until computation finishes.
- **Task-Level Pipelining:** The system operates as a Macro-Pipeline. While the VGA controller is displaying Frame $N-1$ from the Ping-Pong buffer, the FFT is simultaneously computing Frame $N$, and the Frame Buffer is gathering audio samples for Frame $N+1$. This concurrent streaming architecture ensures maximum throughput.
- **Iterative FFT State Machine:** To save massive amounts of FPGA silicon, the FFT is not fully unrolled. Instead, it re-uses 16 physical butterfly units across 5 sequential stages. Because it is an iterative accelerator, it takes ~15 clock cycles to compute a frame, during which it utilizes AXI backpressure to pause upstream data ingestion.
- **Q15 Fixed-Point Arithmetic:** Twiddle factors are pre-scaled by 2^15, allowing efficient integer-only complex multiplication without floating-point hardware.
- **Clock Domain / Architecture Boundaries:** AXI-Stream is utilized strictly for the sequential, high-speed point-to-point DSP datapath. Once frequency bins are calculated, they cross the architectural boundary into the Ping-Pong buffer, which acts as a static Memory-Mapped array that the VGA Graphics engine can randomly access based on `x/y` pixel coordinates.
- **Magnitude Approximation:** Uses `\|Re\| + \|Im\|` instead of `sqrt(Re² + Im²)` to avoid multipliers and square root hardware while maintaining adequate visual accuracy.
