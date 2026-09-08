# Real-Time Audio Visualizer on FPGA

A real-time digital audio visualizer implemented entirely in SystemVerilog on a **Basys 3 (Xilinx Artix-7)** FPGA. Audio is sampled from a microphone via the on-board XADC, transformed into the frequency domain by a custom 32-point Radix-2 DIT FFT engine with 16 parallel butterfly units, and rendered as a symmetric mirrored bar graph on a VGA monitor at 640×480 @ 60 Hz.

## Demo

## Block Diagram

<!-- To add a block diagram:
     1. Export/save your diagram as a PNG or SVG (e.g., block_diagram.png)
     2. Place it in this directory
     3. Uncomment the line below:
-->
<!-- ![Block Diagram](block_diagram.png) -->

```
Mic ─→ audio_input ─→ time_filter ─→ FIFO ─→ FFT ─→ mag_calc ─→ ping_pong_buf ─→ graphics ─→ VGA
          (XADC)       (LPF/HPF)    (32-deep)  (32-pt)  (|Re|+|Im|)  (double buf)   (decay+render)
                           ↑
                       Switches
```

## Architecture

| Module | File | Description |
|--------|------|-------------|
| **audio_input** | `audio_input.sv` | Wraps the Xilinx XADC IP to sample the mic at ~39 kHz. Subtracts `0x8000` to convert the unipolar ADC output to a signed 16-bit audio stream. |
| **time_filter** | `time_filter.sv` | Switchable 5-tap Gaussian Low-Pass and High-Pass filter. Two on-board switches select bypass, LPF, or HPF mode. |
| **FIFO** | `FIFO.sv` | Collects 32 consecutive audio samples into a parallel register array and pulses `samples_ready` when full. |
| **FFT** | `FFT.sv` | Custom 32-point Radix-2 Decimation-in-Time FFT. Bit-reverses input, then processes 5 butterfly stages using 16 parallel `bfly` units. Outputs 17 complex frequency bins (DC through Nyquist). |
| **bfly** | `bfly.sv` | Radix-2 butterfly unit. Computes A + B×W and A − B×W using Q15 fixed-point twiddle factors with a 1-cycle pipeline register between MAC and ADD. |
| **mag_calc** | `mag_calc.sv` | Combinational magnitude approximation using `|Re| + |Im|`. Scales the result down to 10 bits for display. |
| **ping_pong_buffer** | `pingpongbuffer.sv` | Double buffer synchronized to VGA vsync. Latches FFT magnitudes into one buffer while the graphics engine reads from the other, preventing visual tearing between the FFT and VGA clock domains. |
| **graphics** | `graphics.sv` | Bar graph renderer with peak-hold gravity animation. Snaps bars up instantly on loud transients and decays them at 15 pixels/frame. Renders 32 mirrored bars (16 bins × 2) with 2-pixel black gaps across a 512-pixel-wide region. |
| **vga_timing** | `vga_timing.sv` | Generates standard 640×480 @ 60 Hz VGA timing signals (hsync, vsync, video_on, hc, vc). |

## Key Design Decisions

- **Pipelined FFT State Machine:** Each butterfly stage is broken into three sub-states: Routing (R), Multiply-Accumulate (MAC), and Add/Unscramble (ADD). The R stage loads operands and twiddle factors into the 16 parallel butterfly units. The MAC state is a pipeline wait cycle that allows the `bfly` internal pipeline register to settle between the complex multiplication and the addition. The ADD stage captures butterfly outputs and unscrambles them back into the dual-array (`buffer0`, `buffer1`) layout for the next stage.
- **Q15 Fixed-Point Arithmetic:** Twiddle factors are pre-scaled by 2^15, allowing efficient integer-only complex multiplication without floating-point hardware. The butterfly unit de-scales by slicing `[30:15]` after multiplication, which is valid because bits 31 and 32 are redundant sign extension from Q15 math.
- **No Data Path Resets:** Pipeline registers in the butterfly units and FFT buffers are intentionally left without reset logic to minimize routing congestion and improve timing closure. Only control signals (state machines, valid flags) are reset. Graphics `draw_mags` is an exception — it is reset because it is directly read by the VGA render logic on every pixel clock.
- **Ping-Pong Magnitude Latching:** The double buffer latches scaled FFT magnitudes (not full VGA frames) on `fft_valid`, and swaps read/write sides on vsync edges. This ensures the graphics engine always reads a complete, coherent set of 17 magnitude values while the FFT asynchronously writes new results.
- **Valid Flag Handshaking:** The entire pipeline is driven by single-cycle valid pulses rather than a global enable. The XADC asserts `audio_valid` at ~39 kHz, which is orders of magnitude slower than the 100 MHz system clock. Each downstream module waits idle until its upstream valid fires: `audio_valid` triggers the time filter, `filtered_valid` feeds the FIFO, `samples_ready` kicks off the FFT state machine, and `fft_valid` latches magnitudes into the ping-pong buffer. This lets each module run at its own pace — the FFT can take dozens of clock cycles to compute all 5 butterfly stages while the XADC continues sampling, and the VGA engine renders at 60 Hz completely independent of both. No module ever stalls or wastes cycles polling.
- **Magnitude Approximation:** Uses `|Re| + |Im|` instead of `sqrt(Re² + Im²)` to avoid multipliers and square root hardware while maintaining adequate visual accuracy.
- **Mirrored Display:** The FFT of a real signal is conjugate-symmetric, so only bins 0–16 are computed. The graphics module mirrors them to fill the full 512-pixel display width.