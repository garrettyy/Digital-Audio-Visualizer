# Real-Time Audio Visualizer on FPGA

A real-time digital audio visualizer implemented entirely in SystemVerilog on a **Basys 3 (Xilinx Artix-7)** FPGA. Audio is sampled from an electret microphone via the on-board XADC, transformed into the frequency domain by a custom 32-point Radix-2 DIT FFT engine with 16 parallel butterfly units, and rendered as a symmetric mirrored bar graph on a VGA monitor at 640×480 @ 60 Hz.

## Demo

<!-- To add a demo video:
     1. Place your .mp4 or .gif file in this directory (e.g., demo.mp4)
     2. For a GIF:    ![Demo](demo.gif)
     3. For an MP4 on GitHub, use an HTML video tag:
        <video src="demo.mp4" width="600" controls></video>
     4. Or upload the video to YouTube and embed a link:
        [![Demo Video](https://img.youtube.com/vi/YOUR_VIDEO_ID/0.jpg)](https://www.youtube.com/watch?v=YOUR_VIDEO_ID)
-->

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
| **audio_input** | `audio_input.sv` | Wraps the Xilinx XADC IP to sample the electret mic at ~39 kHz. Subtracts `0x8000` to convert the unipolar ADC output to a signed 16-bit audio stream. |
| **time_filter** | `time_filter.sv` | Switchable 5-tap Gaussian Low-Pass and High-Pass filter. Two on-board switches select bypass, LPF, or HPF mode. |
| **FIFO** | `FIFO.sv` | Collects 32 consecutive audio samples into a parallel register array and pulses `samples_ready` when full. |
| **FFT** | `FFT.sv` | Custom 32-point Radix-2 Decimation-in-Time FFT. Bit-reverses input, then processes 5 butterfly stages using 16 parallel `bfly` units. Outputs 17 complex frequency bins (DC through Nyquist). |
| **bfly** | `bfly.sv` | Radix-2 butterfly unit. Computes A + B×W and A − B×W using Q15 fixed-point twiddle factors with a 1-cycle pipeline register between MAC and ADD. |
| **mag_calc** | `mag_calc.sv` | Combinational magnitude approximation using `|Re| + |Im|`. Scales the result down to 10 bits for display. |
| **ping_pong_buffer** | `pingpongbuffer.sv` | Double buffer synchronized to VGA vsync. The FFT writes to one buffer while the graphics engine reads from the other, preventing visual tearing. |
| **graphics** | `graphics.sv` | Bar graph renderer with peak-hold gravity animation. Snaps bars up instantly on loud transients and decays them at 15 pixels/frame. Renders 32 mirrored bars (16 bins × 2) with 2-pixel black gaps across a 512-pixel-wide region. |
| **vga_timing** | `vga_timing.sv` | Generates standard 640×480 @ 60 Hz VGA timing signals (hsync, vsync, video_on, hc, vc). |

## Hardware Requirements

- **FPGA Board:** Digilent Basys 3 (Xilinx Artix-7 XC7A35T)
- **Microphone:** Electret condenser mic with a resistor voltage divider biased to ~0.5V on JXADC header (vauxp6 / vauxn6)
- **Display:** Any VGA monitor (640×480 @ 60 Hz)
- **Switches:** SW0 = Filter Enable, SW1 = High-Pass Enable
- **Button:** BTNU = Reset

## Building

1. Open Vivado and create a new project targeting the `xc7a35tcpg236-1` device
2. Add all `.sv` source files and the `xadc_wiz_0.xci` IP core
3. Add `constraints.xdc` as the constraints file
4. Run Synthesis → Implementation → Generate Bitstream
5. Program the Basys 3 via USB

## Key Design Decisions

- **Q15 Fixed-Point Arithmetic:** Twiddle factors are pre-scaled by 2^15, allowing efficient integer-only complex multiplication without floating-point hardware.
- **No Data Path Resets:** Pipeline registers in the butterfly units and FFT buffers are intentionally left without reset logic to minimize routing congestion and improve timing closure. Only control signals (state machines, valid flags) are reset.
- **Magnitude Approximation:** Uses `|Re| + |Im|` instead of `sqrt(Re² + Im²)` to avoid multipliers and square root hardware while maintaining adequate visual accuracy.
- **Mirrored Display:** The FFT of a real signal is conjugate-symmetric, so only bins 0–16 are computed. The graphics module mirrors them to fill the full 512-pixel display width.