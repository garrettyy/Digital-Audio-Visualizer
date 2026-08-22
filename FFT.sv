`timescale 1ns / 1ps

module FFT #(parameter WIDTH = 32) (
    input  logic clk, rst,
    input  logic signed [WIDTH-1:0] A, B, W,
    output logic signed [WIDTH-1:0] out0, out1
);

    localparam HALF = WIDTH / 2;

    logic signed [WIDTH-1:0] A_r, B_r, W_r;

    logic signed [31:0] p_rr, p_ii, p_ir, p_ri;
    logic signed [32:0] bw_real_full, bw_imag_full;

    logic signed [HALF-1:0] A1_pipe1, A2_pipe1;
    logic signed [HALF-1:0] A1_pipe2, A2_pipe2;
    logic signed [HALF-1:0] BWT1_pipe, BWT2_pipe;

    assign bw_real_full = {p_rr[31], p_rr} - {p_ii[31], p_ii};
    assign bw_imag_full = {p_ir[31], p_ir} + {p_ri[31], p_ri};

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            A_r <= '0;
            B_r <= '0;
            W_r <= '0;
            p_rr <= '0;
            p_ii <= '0;
            p_ir <= '0;
            p_ri <= '0;
            A1_pipe1 <= '0;
            A2_pipe1 <= '0;
            A1_pipe2 <= '0;
            A2_pipe2 <= '0;
            BWT1_pipe <= '0;
            BWT2_pipe <= '0;
        end else begin
            A_r <= A;
            B_r <= B;
            W_r <= W;

            p_rr <= $signed(W_r[WIDTH-1:HALF]) * $signed(B_r[WIDTH-1:HALF]);
            p_ii <= $signed(W_r[HALF-1:0])     * $signed(B_r[HALF-1:0]);
            p_ir <= $signed(W_r[HALF-1:0])     * $signed(B_r[WIDTH-1:HALF]);
            p_ri <= $signed(W_r[WIDTH-1:HALF]) * $signed(B_r[HALF-1:0]);

            A1_pipe1 <= A_r[WIDTH-1:HALF];
            A2_pipe1 <= A_r[HALF-1:0];

            BWT1_pipe <= bw_real_full >>> 15;
            BWT2_pipe <= bw_imag_full >>> 15;

            A1_pipe2 <= A1_pipe1;
            A2_pipe2 <= A2_pipe1;
        end
    end

    always_comb begin
        out0[WIDTH-1:HALF] = A1_pipe2 + BWT1_pipe;
        out0[HALF-1:0]     = A2_pipe2 + BWT2_pipe;
        out1[WIDTH-1:HALF] = A1_pipe2 - BWT1_pipe;
        out1[HALF-1:0]     = A2_pipe2 - BWT2_pipe;
    end

endmodule
