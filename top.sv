`timescale 1ns / 1ps

module top_module (
    input  logic clk,
    input  logic rst,
    input  logic sw_filter_en,
    input  logic sw_highpass_en,
    input  logic vauxp6,
    input  logic vauxn6,
    input  logic R2,
    
    output logic hsync, vsync,
    output logic [3:0] vga_r, vga_g, vga_b
);

    logic signed [15:0] raw_audio, filtered_audio;
    logic raw_valid, filtered_valid;

    logic signed [31:0] fft_out;
    logic [3:0] fft_bin_idx;
    logic fft_valid;

    logic [9:0] mag_height;
    logic mag_write_en;
    logic [3:0] mag_write_addr;

    logic [9:0] hc, vc;
    logic video_on;
    logic [3:0] render_read_addr;
    logic [9:0] render_bin_height;

    audio_input u_audio (
        .clk(clk),
        .rst(rst),
        .vauxp6(vauxp6),
        .vauxn6(vauxn6),
        .audio_data(raw_audio),
        .sample_valid(raw_valid)
    );

    time_filter u_fir (
        .clk(clk),
        .rst(rst),
        .sample_valid_in(raw_valid),
        .sw_filter_enable(sw_filter_en),
        .sw_highpass_enable(sw_highpass_en),
        .audio_in(raw_audio),
        .audio_out(filtered_audio),
        .sample_valid_out(filtered_valid)
    );

    fft_engine u_fft (
        .clk(clk),
        .rst(rst),
        .start(filtered_valid),
        .audio_sample(filtered_audio),
        .fft_out(fft_out),
        .bin_index(fft_bin_idx),
        .fft_valid(fft_valid)
    );

    magnitude_calc u_mag (
        .clk(clk),
        .rst(rst),
        .R2(R2),
        .fft_valid(fft_valid),
        .bin_index(fft_bin_idx),
        .fft_complex(fft_out),
        .buffer_write_en(mag_write_en),
        .buffer_address(mag_write_addr),
        .magnitude_height(mag_height)
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

    ping_pong_buffer u_ram (
        .clk(clk),
        .rst(rst),
        .vsync(vsync),
        .write_en(mag_write_en),
        .write_addr(mag_write_addr),
        .write_data(mag_height),
        .read_addr(render_read_addr),
        .read_data(render_bin_height)
    );

    bar_renderer u_render (
        .hc(hc),
        .vc(vc),
        .video_on(video_on),
        .read_addr(render_read_addr),
        .bin_height(render_bin_height),
        .vga_r(vga_r),
        .vga_g(vga_g),
        .vga_b(vga_b)
    );

endmodule
