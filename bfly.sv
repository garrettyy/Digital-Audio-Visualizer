`timescale 1ns / 1ps

module bfly (
    input logic [31:0] A,
    input logic [31:0] B,
    input logic [31:0] W,
    output logic [31:0] out0,
    output logic [31:0] out1
);

logic signed [15:0] A_real, A_imag, B_real, B_imag, W_real, W_imag;
logic signed [16:0] out0_real, out0_imag, out1_real, out1_imag;
logic signed [32:0] BxW_real, BxW_imag;

// Break into real and imaginary
assign {A_real, A_imag}  = {A[31:16],A[15:0]};
assign {B_real, B_imag}  = {B[31:16],B[15:0]};
assign {W_real, W_imag}  = {W[31:16],W[15:0]};

// Compute BxW full complex multiplication 
assign BxW_real = $signed(B_real * W_real) - $signed(B_imag * W_imag);
assign BxW_imag = $signed(B_imag * W_real) + $signed(B_real * W_imag);

// Scale down BxW and do arithmetic (may cause overflow so widen)
assign out0_real = (A_real + $signed(BxW_real[30:15]));
assign out0_imag = (A_imag + $signed(BxW_imag[30:15]));
assign out1_real = (A_real - $signed(BxW_real[30:15]));
assign out1_imag = (A_imag - $signed(BxW_imag[30:15]));

// Scale down the widened values and assemble outputs
assign out0 = {out0_real[16:1], out0_imag[16:1]};
assign out1 = {out1_real[16:1], out1_imag[16:1]};

endmodule 