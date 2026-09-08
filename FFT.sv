`timescale 1ns / 1ps

module FFT (
    input logic clk, rst, samples_ready,
    input logic [31:0] parallel_samples [31:0],
    output logic [31:0] fft_out [16:0],
    output logic fft_valid
);

logic [31:0] buffer0 [15:0];
logic [31:0] buffer1 [15:0];
logic [31:0] W_reg [15:0];
logic [31:0] A_reg [15:0];
logic [31:0] B_reg [15:0];
logic [31:0] out0 [15:0];
logic [31:0] out1 [15:0];

logic [31:0] fft_samples [17:0];
assign fft_out = fft_samples [16:0];

// R means routing stage 
typedef enum { // I added MAC stage in between logic in bfly units specifically to meet timing
    IDLE, 
    STAGE1_R, STAGE1_MAC, STAGE1_ADD, // ADD stage does A+BxW and unscrambles routing
    STAGE2_R, STAGE2_MAC, STAGE2_ADD,
    STAGE3_R, STAGE3_MAC, STAGE3_ADD,
    STAGE4_R, STAGE4_MAC, STAGE4_ADD,
    STAGE5_R, STAGE5_MAC, STAGE5_ADD,
    UNLOAD
} state;

state c_state;

function automatic logic [31:0] twiddle_factor(input logic [3:0] index);
    begin
        case (index)
            4'd0:  twiddle_factor = 32'h7FFF_0000; //  32767,       0
            4'd1:  twiddle_factor = 32'h7D89_E707; //  32137,   -6393
            4'd2:  twiddle_factor = 32'h7641_CF05; //  30273,  -12539
            4'd3:  twiddle_factor = 32'h6A6D_B8E4; //  27245,  -18204
            4'd4:  twiddle_factor = 32'h5A82_A57E; //  23170,  -23170
            4'd5:  twiddle_factor = 32'h471C_9593; //  18204,  -27245
            4'd6:  twiddle_factor = 32'h30FB_89BF; //  12539,  -30273
            4'd7:  twiddle_factor = 32'h18F9_8277; //   6393,  -32137
            4'd8:  twiddle_factor = 32'h0000_8001; //      0,  -32767
            4'd9:  twiddle_factor = 32'hE707_8277; //  -6393,  -32137
            4'd10: twiddle_factor = 32'hCF05_89BF; // -12539,  -30273
            4'd11: twiddle_factor = 32'hB8E4_9593; // -18204,  -27245
            4'd12: twiddle_factor = 32'hA57E_A57E; // -23170,  -23170
            4'd13: twiddle_factor = 32'h9593_B8E4; // -27245,  -18204
            4'd14: twiddle_factor = 32'h89BF_CF05; // -30273,  -12539
            4'd15: twiddle_factor = 32'h8277_E707; // -32137,   -6393
            default: twiddle_factor = 32'h7FFF_0000;
        endcase
    end
endfunction


// Instantiate 16 butterfly units
genvar i;
generate 
    for(i = 0; i < 16; i++) begin : bfly_array
        bfly bfly_unit (.clk(clk), .A(A_reg[i]), .B(B_reg[i]), .W(W_reg[i]), .out0(out0[i]), .out1(out1[i]));
    end
endgenerate

// Each stage does the following : Route registers into bflys, Compute Multiply and Accumulate, Finish ADD/SUB (A+BxW)
always_ff @(posedge clk, posedge rst) begin
    if(rst) begin
        c_state <= IDLE;
        fft_valid <= 0;
    end
    else begin
        fft_valid <= 0;
        case(c_state)
            IDLE: begin
                // Latch data when fifo is full
                if (samples_ready) begin
                    int x;
                    c_state <= STAGE1_R;
                    for (int j=0; j < 32; j+=2) begin
                        x = j+1;
                        // Must do bit reverse indexing when inputing into fft
                        buffer0[j/2] <= parallel_samples[{j[0],j[1],j[2],j[3],j[4]}];
                        buffer1[j/2] <= parallel_samples[{x[0],x[1],x[2],x[3],x[4]}];
                    end
                end
            end
            STAGE1_R: begin
                for (int j = 0; j < 16; j++) begin
                    A_reg[j] <= buffer0[j];
                    B_reg[j] <= buffer1[j];
                    W_reg[j] <= twiddle_factor(0);
                end
                c_state <= STAGE1_MAC;
            end
            STAGE1_MAC: begin
                c_state <= STAGE1_ADD; // Pipeline wait state for bfly math
            end
            STAGE1_ADD: begin
                for (int j=0; j < 16; j++) begin 
                    buffer0[j] <= out0[j];
                    buffer1[j] <= out1[j];
                end
                c_state <= STAGE2_R;
            end
            STAGE2_R: begin
                for (int j = 0; j < 16; j+=2) begin
                    A_reg[j] <= buffer0[j];
                    A_reg[j+1] <= buffer1[j];
                    B_reg[j] <= buffer0[j+1];
                    B_reg[j+1] <= buffer1[j+1];
                    W_reg[j] <= twiddle_factor(0);
                    W_reg[j+1] <= twiddle_factor(8);
                end
                c_state <= STAGE2_MAC;
            end
            STAGE2_MAC: begin
                c_state <= STAGE2_ADD; // Pipeline wait state for bfly math
            end
            STAGE2_ADD: begin
                for (int j = 0; j < 16; j+=2) begin
                    buffer0[j] <= out0[j];      
                    buffer1[j] <= out0[j+1];
                    buffer0[j+1] <= out1[j];
                    buffer1[j+1] <= out1[j+1];
                end
                c_state <= STAGE3_R;
            end
            STAGE3_R: begin
                 for (int j = 0; j < 16; j+=4) begin
                    A_reg[j] <= buffer0[j];
                    A_reg[j+1] <= buffer1[j];
                    A_reg[j+2] <= buffer0[j+1];
                    A_reg[j+3] <= buffer1[j+1];
                    B_reg[j] <= buffer0[j+2];
                    B_reg[j+1] <= buffer1[j+2];
                    B_reg[j+2] <= buffer0[j+3];
                    B_reg[j+3] <= buffer1[j+3];
                    W_reg[j] <= twiddle_factor(0);
                    W_reg[j+1] <= twiddle_factor(4);
                    W_reg[j+2] <= twiddle_factor(8);
                    W_reg[j+3] <= twiddle_factor(12);
                end
                c_state <= STAGE3_MAC;
            end
            STAGE3_MAC: begin
                c_state <= STAGE3_ADD; // Pipeline wait state for bfly math
            end
            STAGE3_ADD: begin
                for (int j=0; j < 16; j+=4) begin 
                    buffer0[j]   <= out0[j];  
                    buffer1[j]   <= out0[j+1];
                    buffer0[j+1] <= out0[j+2];
                    buffer1[j+1] <= out0[j+3];
                    buffer0[j+2] <= out1[j];  
                    buffer1[j+2] <= out1[j+1];
                    buffer0[j+3] <= out1[j+2];
                    buffer1[j+3] <= out1[j+3];
                end
                c_state <= STAGE4_R;
            end
            STAGE4_R: begin
                for (int j = 0; j < 16; j+=8) begin
                    A_reg[j] <= buffer0[j];
                    A_reg[j+1] <= buffer1[j];
                    A_reg[j+2] <= buffer0[j+1];
                    A_reg[j+3] <= buffer1[j+1];
                    A_reg[j+4] <= buffer0[j+2];
                    A_reg[j+5] <= buffer1[j+2];
                    A_reg[j+6] <= buffer0[j+3];
                    A_reg[j+7] <= buffer1[j+3];

                    B_reg[j] <= buffer0[j+4];
                    B_reg[j+1] <= buffer1[j+4];
                    B_reg[j+2] <= buffer0[j+5];
                    B_reg[j+3] <= buffer1[j+5];
                    B_reg[j+4] <= buffer0[j+6];
                    B_reg[j+5] <= buffer1[j+6];
                    B_reg[j+6] <= buffer0[j+7];
                    B_reg[j+7] <= buffer1[j+7];

                    W_reg[j] <= twiddle_factor(0);
                    W_reg[j+1] <= twiddle_factor(2);
                    W_reg[j+2] <= twiddle_factor(4);
                    W_reg[j+3] <= twiddle_factor(6);
                    W_reg[j+4] <= twiddle_factor(8);
                    W_reg[j+5] <= twiddle_factor(10);
                    W_reg[j+6] <= twiddle_factor(12);
                    W_reg[j+7] <= twiddle_factor(14);
                end
                c_state <= STAGE4_MAC;
            end
            STAGE4_MAC: begin
                c_state <= STAGE4_ADD; // Pipeline wait state for bfly math
            end
            STAGE4_ADD: begin
                for (int j=0; j < 16; j+=8) begin 
                    buffer0[j]   <= out0[j];
                    buffer1[j]   <= out0[j+1];
                    buffer0[j+1] <= out0[j+2];
                    buffer1[j+1] <= out0[j+3];
                    buffer0[j+2] <= out0[j+4];
                    buffer1[j+2] <= out0[j+5];
                    buffer0[j+3] <= out0[j+6];
                    buffer1[j+3] <= out0[j+7];
                    
                    buffer0[j+4] <= out1[j];
                    buffer1[j+4] <= out1[j+1];
                    buffer0[j+5] <= out1[j+2];
                    buffer1[j+5] <= out1[j+3];
                    buffer0[j+6] <= out1[j+4];
                    buffer1[j+6] <= out1[j+5];
                    buffer0[j+7] <= out1[j+6];
                    buffer1[j+7] <= out1[j+7];
                end
                c_state <= STAGE5_R;
            end
            STAGE5_R: begin
                for (int j = 0; j < 16; j+=16) begin
                    A_reg[j] <= buffer0[j];
                    A_reg[j+1] <= buffer1[j];
                    A_reg[j+2] <= buffer0[j+1];
                    A_reg[j+3] <= buffer1[j+1];
                    A_reg[j+4] <= buffer0[j+2];
                    A_reg[j+5] <= buffer1[j+2];
                    A_reg[j+6] <= buffer0[j+3];
                    A_reg[j+7] <= buffer1[j+3];
                    A_reg[j+8] <= buffer0[j+4];
                    A_reg[j+9] <= buffer1[j+4];
                    A_reg[j+10] <= buffer0[j+5];
                    A_reg[j+11] <= buffer1[j+5];
                    A_reg[j+12] <= buffer0[j+6];
                    A_reg[j+13] <= buffer1[j+6];
                    A_reg[j+14] <= buffer0[j+7];
                    A_reg[j+15] <= buffer1[j+7];

                    B_reg[j] <= buffer0[j+8];
                    B_reg[j+1] <= buffer1[j+8];
                    B_reg[j+2] <= buffer0[j+9];
                    B_reg[j+3] <= buffer1[j+9];
                    B_reg[j+4] <= buffer0[j+10];
                    B_reg[j+5] <= buffer1[j+10];
                    B_reg[j+6] <= buffer0[j+11];
                    B_reg[j+7] <= buffer1[j+11];
                    B_reg[j+8] <= buffer0[j+12];
                    B_reg[j+9] <= buffer1[j+12];
                    B_reg[j+10] <= buffer0[j+13];
                    B_reg[j+11] <= buffer1[j+13];
                    B_reg[j+12] <= buffer0[j+14];
                    B_reg[j+13] <= buffer1[j+14];
                    B_reg[j+14] <= buffer0[j+15];
                    B_reg[j+15] <= buffer1[j+15];

                    W_reg[j] <= twiddle_factor(0);
                    W_reg[j+1] <= twiddle_factor(1);
                    W_reg[j+2] <= twiddle_factor(2);
                    W_reg[j+3] <= twiddle_factor(3);
                    W_reg[j+4] <= twiddle_factor(4);
                    W_reg[j+5] <= twiddle_factor(5);
                    W_reg[j+6] <= twiddle_factor(6);
                    W_reg[j+7] <= twiddle_factor(7);
                    W_reg[j+8] <= twiddle_factor(8);
                    W_reg[j+9] <= twiddle_factor(9);
                    W_reg[j+10] <= twiddle_factor(10);
                    W_reg[j+11] <= twiddle_factor(11);
                    W_reg[j+12] <= twiddle_factor(12);
                    W_reg[j+13] <= twiddle_factor(13);
                    W_reg[j+14] <= twiddle_factor(14);
                    W_reg[j+15] <= twiddle_factor(15);
                end
                c_state <= STAGE5_MAC;
            end
            STAGE5_MAC: begin
                c_state <= STAGE5_ADD; // Pipeline wait state for bfly math
            end
            STAGE5_ADD: begin
                for (int j=0; j < 16; j+=16) begin 
                    buffer0[j]   <= out0[j];
                    buffer1[j]   <= out0[j+1];
                    buffer0[j+1] <= out0[j+2];
                    buffer1[j+1] <= out0[j+3];
                    buffer0[j+2] <= out0[j+4];
                    buffer1[j+2] <= out0[j+5];
                    buffer0[j+3] <= out0[j+6];
                    buffer1[j+3] <= out0[j+7];
                    buffer0[j+4] <= out0[j+8];
                    buffer1[j+4] <= out0[j+9];
                    buffer0[j+5] <= out0[j+10];
                    buffer1[j+5] <= out0[j+11];
                    buffer0[j+6] <= out0[j+12];
                    buffer1[j+6] <= out0[j+13];
                    buffer0[j+7] <= out0[j+14];
                    buffer1[j+7] <= out0[j+15];
                    
                    buffer0[j+8]  <= out1[j];
                    buffer1[j+8]  <= out1[j+1];
                    buffer0[j+9]  <= out1[j+2];
                    buffer1[j+9]  <= out1[j+3];
                    buffer0[j+10] <= out1[j+4];
                    buffer1[j+10] <= out1[j+5];
                    buffer0[j+11] <= out1[j+6];
                    buffer1[j+11] <= out1[j+7];
                    buffer0[j+12] <= out1[j+8];
                    buffer1[j+12] <= out1[j+9];
                    buffer0[j+13] <= out1[j+10];
                    buffer1[j+13] <= out1[j+11];
                    buffer0[j+14] <= out1[j+12];
                    buffer1[j+14] <= out1[j+13];
                    buffer0[j+15] <= out1[j+14];
                    buffer1[j+15] <= out1[j+15];
                end
                c_state <= UNLOAD;
            end
            UNLOAD: begin
                // Only stream bins 0 to 16 because second half is mirrored
                for (int j = 0; j < 18; j+=2) begin
                    fft_samples[j] <= buffer0[j/2];
                    fft_samples[j+1] <= buffer1[j/2];
                end
                fft_valid <= 1;
                c_state <= IDLE;
            end
    endcase
    end
end

endmodule 