`timescale 1ns / 1ps

module top_module (
    input logic clk,
    input logic rst,
    input logic sw_filter_en,
    input logic sw_highpass_en,
    input logic vauxp6,
    input logic vauxn6,
    output logic hsync, vsync,
    output logic [3:0] r, g, b
);

    logic signed [15:0] raw_audio, filtered_audio;
    logic raw_valid, filtered_valid;

    logic [31:0] parallel_samples [31:0];
    logic samples_ready;

    logic [31:0] fft_out [16:0];
    logic fft_valid;

    logic [9:0] scaled_mags [16:0];

    logic [9:0] held_mags [16:0];



    logic [9:0] hc, vc;
    logic video_on;


    audio_input u_audio (
        .clk(clk),
        .rst(rst),
        .vauxp6(vauxp6),
        .vauxn6(vauxn6),
        .audio_sample(raw_audio),
        .audio_valid(raw_valid)
    );

    time_filter u_fir (
        .clk(clk),
        .rst(rst),
        .sample_valid(raw_valid),
        .sw_filter_enable(sw_filter_en),
        .highpass_enable(sw_highpass_en),
        .audio_in(raw_audio),
        .audio_out(filtered_audio),
        .output_valid(filtered_valid)
    );

    FIFO u_fifo(
        .clk(clk),
        .rst(rst),
        .audio_valid(filtered_valid),
        .audio_sample(filtered_audio),
        .parallel_samples(parallel_samples),
        .samples_ready(samples_ready)
    );

    FFT u_fft (
        .clk(clk),
        .rst(rst),
        .samples_ready(samples_ready),
        .parallel_samples(parallel_samples),
        .fft_out(fft_out),
        .fft_valid(fft_valid)
    );

    mag_calc u_mag (
        .fft_samples(fft_out),
        .scaled_mags(scaled_mags)
    );

    ping_pong_buffer u_pp_buffer (
        .clk(clk),
        .rst(rst),
        .fft_valid(fft_valid),
        .vsync(vsync), 
        .scaled_mags(scaled_mags),
        .held_mags(held_mags)
    );
    

    graphics u_graphics (
        .clk(clk), 
        .rst(rst),
        .hc(hc),
        .vc(vc),
        .vsync(vsync),
        .video_on(video_on),
        .next_mags(held_mags),
        .r(r), .g(g), .b(b)
    );
    vga_timing u_vga (
        .clk(clk),
        .rst(rst),
        .hc(hc),
        .vc(vc),
        .hsync(hsync),
        .vsync(vsync),
        .video_on(video_on)
    );

endmodule
