`timescale 1ns / 1ps

module magnitude_calc #(parameter WIDTH = 32) (
    input  logic clk,
    input  logic rst,
    input logic R2,
    input  logic fft_valid,
    input  logic [3:0] bin_index,
    input  logic signed [WIDTH-1:0] fft_complex,
    output logic buffer_write_en,
    output logic [3:0] buffer_address,
    output logic [9:0] magnitude_height
);

    logic signed [15:0] real_part, imag_part;
    logic signed [16:0] real_ext, imag_ext;
    logic [16:0] abs_real, abs_imag;
    logic [17:0] sum_mag;

    logic [9:0] scaled_mag;
    logic [9:0] held_mag [0:15];
    logic [9:0] next_mag;

    logic [2:0] frame_counter;
    logic decay_tick;

    localparam logic [9:0] MAX_HEIGHT  = 10'd480;
    localparam logic [9:0] DECAY_STEP   = 10'd1;
    localparam logic [9:0] NOISE_FLOOR  = 10'd2;
    localparam logic [2:0] DECAY_DIV    = 3'd7; 

    assign real_part = fft_complex[31:16];
    assign imag_part  = fft_complex[15:0];

    assign real_ext = {real_part[15], real_part};
    assign imag_ext = {imag_part[15], imag_part};

    assign abs_real = real_ext[16] ? -real_ext : real_ext;
    assign abs_imag = imag_ext[16] ? -imag_ext : imag_ext;
    assign sum_mag  = abs_real + abs_imag;

    assign scaled_mag = (sum_mag >> 7);

    assign decay_tick = (frame_counter == DECAY_DIV);

    always_comb begin
        next_mag = held_mag[bin_index];

        if (scaled_mag > held_mag[bin_index]) begin
            next_mag = (scaled_mag > MAX_HEIGHT) ? MAX_HEIGHT : scaled_mag;
        end else if (decay_tick) begin
            if (held_mag[bin_index] > DECAY_STEP)
                next_mag = held_mag[bin_index] - DECAY_STEP;
            else
                next_mag = 10'd0;
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            buffer_write_en  <= 1'b0;
            buffer_address   <= 4'd0;
            magnitude_height <= 10'd0;
            frame_counter    <= 6'd0;

            for (int i = 0; i < 16; i++) begin
                held_mag[i] <= 10'd0;
            end
        end else begin
            buffer_write_en <= fft_valid;
            buffer_address  <= bin_index;

            if (fft_valid) begin
                
                if (bin_index == 0 && R2) begin
                    magnitude_height <= 0;
                    held_mag[bin_index] <= 0;
                end
                else begin
                    magnitude_height <= next_mag;
                    held_mag[bin_index] <= next_mag;
                end
                
                if (bin_index == 4'd15)
                    frame_counter <= frame_counter + 1'b1;
            end
        end
    end

endmodule