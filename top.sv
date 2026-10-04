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

    // Audio Input -> Time Filter
    logic signed [15:0] raw_audio;
    logic raw_valid, raw_ready;

    // Time Filter -> Frame Buffer
    logic signed [15:0] filtered_audio;
    logic filtered_valid, filtered_last, filtered_ready;

    // Frame Buffer -> FFT
    logic [31:0] parallel_samples [31:0];
    logic samples_valid, samples_ready;

    // FFT -> Ping Pong Buffer
    logic [31:0] fft_out [16:0];
    logic fft_valid, ping_pong_ready;

    logic [9:0] scaled_mags [16:0];
    logic [9:0] held_mags [16:0];

    logic [9:0] hc, vc;
    logic video_on;


    audio_input u_audio (
        .clk(clk),
        .rst(rst),
        .vauxp6(vauxp6),
        .vauxn6(vauxn6),
        .m_axis_tdata(raw_audio),
        .m_axis_tvalid(raw_valid),
        .m_axis_tready(raw_ready)
    );

    time_filter u_fir (
        .clk(clk),
        .rst(rst),
        .sw_filter_enable(sw_filter_en),
        .highpass_enable(sw_highpass_en),
        
        .s_axis_tvalid(raw_valid),
        .s_axis_tdata(raw_audio),
        .s_axis_tready(raw_ready),
        
        .m_axis_tvalid(filtered_valid),
        .m_axis_tlast(filtered_last),
        .m_axis_tdata(filtered_audio),
        .m_axis_tready(filtered_ready)
    );

    frame_buffer u_frame_buffer(
        .clk(clk),
        .rst(rst),
        
        .s_axis_tvalid(filtered_valid),
        .s_axis_tlast(filtered_last),
        .s_axis_tdata(filtered_audio),
        .s_axis_tready(filtered_ready),
        
        .m_axis_tvalid(samples_valid),
        .m_axis_tdata(parallel_samples),
        .m_axis_tready(samples_ready)
    );

    FFT u_fft (
        .clk(clk),
        .rst(rst),
        .s_axis_tvalid(samples_valid),
        .s_axis_tready(samples_ready),
        .parallel_samples(parallel_samples),
        
        .m_axis_tdata(fft_out),
        .m_axis_tvalid(fft_valid),
        .m_axis_tready(ping_pong_ready)
    );

    mag_calc u_mag (
        .fft_samples(fft_out),
        .scaled_mags(scaled_mags)
    );

    ping_pong_buffer u_pp_buffer (
        .clk(clk),
        .rst(rst),
        .s_axis_tvalid(fft_valid),
        .s_axis_tready(ping_pong_ready),
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
