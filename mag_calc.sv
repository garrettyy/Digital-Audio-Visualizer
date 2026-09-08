`timescale 1ns / 1ps

module mag_calc (
    input logic [31:0] fft_samples [16:0],
    output logic [9:0] scaled_mags [16:0]
);

logic [15:0] real_mag [16:0];
logic [15:0] imag_mag [16:0];
logic [17:0] mags [16:0];

// Combinationally calculate magnitudes and then latch in next module when fft_valid is HIGH
always_comb begin
    for (int i=0; i<17; i++) begin
        real_mag[i] = fft_samples[i][31] ? ~fft_samples[i][31:16] + 1 : fft_samples[i][31:16];
        imag_mag[i] = fft_samples[i][15] ? ~fft_samples[i][15:0] + 1 : fft_samples[i][15:0];
        mags[i] = real_mag[i] + imag_mag[i];
        
        
        scaled_mags[i] = mags[i][12:3]; // Scale down for sensitivity
    end
end

endmodule