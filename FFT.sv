`timescale 1ns / 1ps

module FFT (
    input logic clk, rst, samples_ready,
    input logic [31:0] parallel_samples [31:0],
    output logic [31:0] fft_sample [31:0],
    output logic fft_valid
);

logic [31:0] buffer0 [15:0];
logic [31:0] buffer1 [15:0];
logic [31:0] W_wire [15:0];
logic [31:0] A_wire [15:0];
logic [31:0] B_wire [15:0];
logic [31:0] out0 [15:0];
logic [31:0] out1 [15:0];

typedef enum {
    IDLE, 
    STAGE1,
    STAGE2,
    STAGE3,
    STAGE4,
    STAGE5,
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
        bfly bfly_unit (.A(A_wire[i]), .B(B_wire[i]), .W(W_wire[i]), .out0(out0[i]), .out1(out1[i]));
    end
endgenerate

// Each stage unscrambles outputs from bfly units to sequentially put into buffer
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
                    c_state <= STAGE1;
                    for (int j=0; j < 32; j+=2) begin
                        int x = j+1;
                        // Must do bit reverse indexing when inputing into fft
                        buffer0[j/2] <= parallel_samples[{j[0],j[1],j[2],j[3],j[4]}];
                        buffer1[j/2] <= parallel_samples[{x[0],x[1],x[2],x[3],x[4]}];
                    end
                end
            end
            STAGE1: begin
                for (int j=0; j < 16; j++) begin 
                    buffer0[j] <= out0[j];
                    buffer1[j] <= out1[j];
                end
                c_state <= STAGE2;
            end
            STAGE2: begin
                for (int j = 0; j < 16; j+=2) begin
                    buffer0[j] <= out0[j];      
                    buffer1[j] <= out0[j+1];
                    buffer0[j+1] <= out1[j];
                    buffer1[j+1] <= out1[j+1];
                end
                c_state <= STAGE3;
            end
            STAGE3: begin
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
                c_state <= STAGE4;
            end
            STAGE4: begin
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
                c_state <= STAGE5;
            end
            STAGE5: begin
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
                for (int j = 0; j < 32; j+=2) begin
                    fft_sample[j] <= buffer0[j/2];
                    fft_sample[j+1] <= buffer1[j/2];
                end
                fft_valid <= 1;
                c_state <= IDLE;
            end
        endcase
    end
end

// Each stage routes from buffers to bfly units
always_comb begin
    A_wire = '{default:'0};
    B_wire = '{default:'0};
    W_wire = '{default:'0};
    case(c_state)
            IDLE: begin
            end
            STAGE1: begin
                // Route buffer to bfly units
                for (int j = 0; j < 16; j++) begin
                    A_wire[j] = buffer0[j];
                    B_wire[j] = buffer1[j];
                    W_wire[j] = twiddle_factor(0);
                end

            end
            STAGE2: begin
                for (int j = 0; j < 16; j+=2) begin
                    A_wire[j] = buffer0[j];
                    A_wire[j+1] = buffer1[j];
                    B_wire[j] = buffer0[j+1];
                    B_wire[j+1] = buffer1[j+1];
                    W_wire[j] = twiddle_factor(0);
                    W_wire[j+1] = twiddle_factor(8);
                end
            end
            STAGE3: begin
                 for (int j = 0; j < 16; j+=4) begin
                    A_wire[j] = buffer0[j];
                    A_wire[j+1] = buffer1[j];
                    A_wire[j+2] = buffer0[j+1];
                    A_wire[j+3] = buffer1[j+1];
                    B_wire[j] = buffer0[j+2];
                    B_wire[j+1] = buffer1[j+2];
                    B_wire[j+2] = buffer0[j+3];
                    B_wire[j+3] = buffer1[j+3];
                    W_wire[j] = twiddle_factor(0);
                    W_wire[j+1] = twiddle_factor(4);
                    W_wire[j+2] = twiddle_factor(8);
                    W_wire[j+3] = twiddle_factor(12);
                end
            end
            STAGE4: begin
                for (int j = 0; j < 16; j+=8) begin
                    A_wire[j]   = buffer0[j];
                    A_wire[j+1] = buffer1[j];
                    A_wire[j+2] = buffer0[j+1];
                    A_wire[j+3] = buffer1[j+1];
                    A_wire[j+4] = buffer0[j+2];
                    A_wire[j+5] = buffer1[j+2];
                    A_wire[j+6] = buffer0[j+3];
                    A_wire[j+7] = buffer1[j+3];

                    B_wire[j]   = buffer0[j+4];
                    B_wire[j+1] = buffer1[j+4];
                    B_wire[j+2] = buffer0[j+5];
                    B_wire[j+3] = buffer1[j+5];
                    B_wire[j+4] = buffer0[j+6];
                    B_wire[j+5] = buffer1[j+6];
                    B_wire[j+6] = buffer0[j+7];
                    B_wire[j+7] = buffer1[j+7];

                    W_wire[j]   = twiddle_factor(0);
                    W_wire[j+1] = twiddle_factor(2);
                    W_wire[j+2] = twiddle_factor(4);
                    W_wire[j+3] = twiddle_factor(6);
                    W_wire[j+4] = twiddle_factor(8);
                    W_wire[j+5] = twiddle_factor(10);
                    W_wire[j+6] = twiddle_factor(12);
                    W_wire[j+7] = twiddle_factor(14);
                end
            end
            STAGE5: begin
                for (int j = 0; j < 16; j+=16) begin
                    A_wire[j]    = buffer0[j];
                    A_wire[j+1]  = buffer1[j];
                    A_wire[j+2]  = buffer0[j+1];
                    A_wire[j+3]  = buffer1[j+1];
                    A_wire[j+4]  = buffer0[j+2];
                    A_wire[j+5]  = buffer1[j+2];
                    A_wire[j+6]  = buffer0[j+3];
                    A_wire[j+7]  = buffer1[j+3];
                    A_wire[j+8]  = buffer0[j+4];
                    A_wire[j+9]  = buffer1[j+4];
                    A_wire[j+10] = buffer0[j+5];
                    A_wire[j+11] = buffer1[j+5];
                    A_wire[j+12] = buffer0[j+6];
                    A_wire[j+13] = buffer1[j+6];
                    A_wire[j+14] = buffer0[j+7];
                    A_wire[j+15] = buffer1[j+7];

                    B_wire[j]    = buffer0[j+8];
                    B_wire[j+1]  = buffer1[j+8];
                    B_wire[j+2]  = buffer0[j+9];
                    B_wire[j+3]  = buffer1[j+9];
                    B_wire[j+4]  = buffer0[j+10];
                    B_wire[j+5]  = buffer1[j+10];
                    B_wire[j+6]  = buffer0[j+11];
                    B_wire[j+7]  = buffer1[j+11];
                    B_wire[j+8]  = buffer0[j+12];
                    B_wire[j+9]  = buffer1[j+12];
                    B_wire[j+10] = buffer0[j+13];
                    B_wire[j+11] = buffer1[j+13];
                    B_wire[j+12] = buffer0[j+14];
                    B_wire[j+13] = buffer1[j+14];
                    B_wire[j+14] = buffer0[j+15];
                    B_wire[j+15] = buffer1[j+15];

                    W_wire[j]    = twiddle_factor(0);
                    W_wire[j+1]  = twiddle_factor(1);
                    W_wire[j+2]  = twiddle_factor(2);
                    W_wire[j+3]  = twiddle_factor(3);
                    W_wire[j+4]  = twiddle_factor(4);
                    W_wire[j+5]  = twiddle_factor(5);
                    W_wire[j+6]  = twiddle_factor(6);
                    W_wire[j+7]  = twiddle_factor(7);
                    W_wire[j+8]  = twiddle_factor(8);
                    W_wire[j+9]  = twiddle_factor(9);
                    W_wire[j+10] = twiddle_factor(10);
                    W_wire[j+11] = twiddle_factor(11);
                    W_wire[j+12] = twiddle_factor(12);
                    W_wire[j+13] = twiddle_factor(13);
                    W_wire[j+14] = twiddle_factor(14);
                    W_wire[j+15] = twiddle_factor(15);
                end
            end
            UNLOAD: begin
            end
    endcase
end

endmodule

// module FFT #(parameter WIDTH = 32) (
//     input  logic clk, rst, start,
//     input  logic signed [WIDTH-1:0] x_in [0:15],  
//     output logic signed [WIDTH-1:0] y_out [0:15],
//     output logic complete
// );

//     // ==========================================
//     // Twiddle Factors (Q15 Fixed-Point)
//     // ==========================================
//     localparam signed [31:0] W16_0 = { 16'sd32767,   16'sd0};
//     localparam signed [31:0] W16_1 = { 16'sd30273, -16'sd12539};
//     localparam signed [31:0] W16_2 = { 16'sd23170, -16'sd23170};
//     localparam signed [31:0] W16_3 = { 16'sd12539, -16'sd30273};
//     localparam signed [31:0] W16_4 = { 16'sd0,     -16'sd32768};
//     localparam signed [31:0] W16_5 = {-16'sd12539, -16'sd30273};
//     localparam signed [31:0] W16_6 = {-16'sd23170, -16'sd23170};
//     localparam signed [31:0] W16_7 = {-16'sd30273, -16'sd12539};

//     // ==========================================
//     // FSM States (18-State 4-Cycle Pipeline)
//     // ==========================================
//     typedef enum logic [4:0] { // Expanded to 5 bits to hold 18 states
//         IDLE     = 5'd0,
//         S1_ROUTE = 5'd1,  S1_MULT1 = 5'd2,  S1_MULT2 = 5'd3,  S1_ADD = 5'd4,
//         S2_ROUTE = 5'd5,  S2_MULT1 = 5'd6,  S2_MULT2 = 5'd7,  S2_ADD = 5'd8,
//         S3_ROUTE = 5'd9,  S3_MULT1 = 5'd10, S3_MULT2 = 5'd11, S3_ADD = 5'd12,
//         S4_ROUTE = 5'd13, S4_MULT1 = 5'd14, S4_MULT2 = 5'd15, S4_ADD = 5'd16,
//         DONE     = 5'd17
//     } state_t;
    
//     state_t c_state, n_state;
    
//     // ==========================================
//     // BUTTERFLY UNIT INSTANTIATION
//     // ==========================================
//     logic signed [WIDTH-1:0] A_in [0:7], B_in [0:7], W_in [0:7];
//     logic signed [WIDTH-1:0] out0 [0:7], out1 [0:7];

//     genvar i;
//     generate
//         for (i = 0; i < 8; i++) begin : bfly_array
//             bfly #(.WIDTH(WIDTH)) bfly_unit (
//                 .clk(clk), .rst(rst), 
//                 .A(A_in[i]), .B(B_in[i]), .W(W_in[i]), 
//                 .out0(out0[i]), .out1(out1[i])
//             );
//         end
//     endgenerate

//     // ==========================================
//     // PIPELINE REGISTERS
//     // ==========================================
//     logic signed [WIDTH-1:0] x_reg [0:15]; // Internal Latch
//     logic signed [WIDTH-1:0] stg1_reg [0:15];
//     logic signed [WIDTH-1:0] stg2_reg [0:15];
//     logic signed [WIDTH-1:0] stg3_reg [0:15];

//     // ==========================================
//     // BLOCK 1: Flip-Flops (State & Memory)
//     // ==========================================
//     always_ff @(posedge clk or posedge rst) begin
//         if (rst) begin
//             c_state <= IDLE;
//             for (int k = 0; k < 16; k++) y_out[k] <= 0;
//             for (int k = 0; k < 16; k++) x_reg[k] <= 0;
//         end else begin
//             c_state <= n_state;
            
//             // Instantly latch the entire input array when triggered
//             if (c_state == IDLE && start) begin
//                 for (int k = 0; k < 16; k++) begin
//                     x_reg[k] <= x_in[k];
//                 end
//             end
            
//             // Capture data ONLY on the ADD cycle
//             if (c_state == S1_ADD) begin
//                 for (int k = 0; k < 8; k++) begin
//                     stg1_reg[2*k]   <= out0[k];
//                     stg1_reg[2*k+1] <= out1[k];
//                 end
//             end
//             else if (c_state == S2_ADD) begin
//                 stg2_reg[0] <= out0[0]; stg2_reg[2] <= out1[0];
//                 stg2_reg[1] <= out0[1]; stg2_reg[3] <= out1[1];
//                 stg2_reg[4] <= out0[2]; stg2_reg[6] <= out1[2];
//                 stg2_reg[5] <= out0[3]; stg2_reg[7] <= out1[3];
//                 stg2_reg[8] <= out0[4]; stg2_reg[10] <= out1[4];
//                 stg2_reg[9] <= out0[5]; stg2_reg[11] <= out1[5];
//                 stg2_reg[12] <= out0[6]; stg2_reg[14] <= out1[6];
//                 stg2_reg[13] <= out0[7]; stg2_reg[15] <= out1[7];
//             end
//             else if (c_state == S3_ADD) begin
//                 stg3_reg[0] <= out0[0]; stg3_reg[4] <= out1[0];
//                 stg3_reg[1] <= out0[1]; stg3_reg[5] <= out1[1];
//                 stg3_reg[2] <= out0[2]; stg3_reg[6] <= out1[2];
//                 stg3_reg[3] <= out0[3]; stg3_reg[7] <= out1[3];
//                 stg3_reg[8] <= out0[4]; stg3_reg[12] <= out1[4];
//                 stg3_reg[9] <= out0[5]; stg3_reg[13] <= out1[5];
//                 stg3_reg[10] <= out0[6]; stg3_reg[14] <= out1[6];
//                 stg3_reg[11] <= out0[7]; stg3_reg[15] <= out1[7];
//             end
//             else if (c_state == S4_ADD) begin
//                 y_out[0] <= out0[0]; y_out[8] <= out1[0];
//                 y_out[1] <= out0[1]; y_out[9] <= out1[1];
//                 y_out[2] <= out0[2]; y_out[10] <= out1[2];
//                 y_out[3] <= out0[3]; y_out[11] <= out1[3];
//                 y_out[4] <= out0[4]; y_out[12] <= out1[4];
//                 y_out[5] <= out0[5]; y_out[13] <= out1[5];
//                 y_out[6] <= out0[6]; y_out[14] <= out1[6];
//                 y_out[7] <= out0[7]; y_out[15] <= out1[7];
//             end
//         end
//     end
    
//     // ==========================================
//     // BLOCK 2: Next State Logic
//     // ==========================================
//     always_comb begin
//         n_state = c_state;
//         case (c_state)
//             IDLE:     if (start) n_state = S1_ROUTE;
            
//             S1_ROUTE: n_state = S1_MULT1;
//             S1_MULT1: n_state = S1_MULT2;
//             S1_MULT2: n_state = S1_ADD;
//             S1_ADD:   n_state = S2_ROUTE;
            
//             S2_ROUTE: n_state = S2_MULT1;
//             S2_MULT1: n_state = S2_MULT2;
//             S2_MULT2: n_state = S2_ADD;
//             S2_ADD:   n_state = S3_ROUTE;
            
//             S3_ROUTE: n_state = S3_MULT1;
//             S3_MULT1: n_state = S3_MULT2;
//             S3_MULT2: n_state = S3_ADD;
//             S3_ADD:   n_state = S4_ROUTE;
            
//             S4_ROUTE: n_state = S4_MULT1;
//             S4_MULT1: n_state = S4_MULT2;
//             S4_MULT2: n_state = S4_ADD;
//             S4_ADD:   n_state = DONE;
            
//             DONE:     n_state = IDLE; 
//             default:  n_state = IDLE;
//         endcase
//     end
    
//     // ==========================================
//     // BLOCK 3: Datapath Routing 
//     // ==========================================
//     always_comb begin
//         for (int k = 0; k < 8; k++) begin
//             A_in[k] = 0; B_in[k] = 0; W_in[k] = 0;
//         end
//         complete = (c_state == DONE) ? 1'b1 : 1'b0;
        
//         // Hold the routing stable for ALL FOUR CYCLES of each stage
//         case (c_state)
//             S1_ROUTE, S1_MULT1, S1_MULT2, S1_ADD: begin
//                 A_in[0] = x_reg[0];  B_in[0] = x_reg[8];  W_in[0] = W16_0; 
//                 A_in[1] = x_reg[4];  B_in[1] = x_reg[12]; W_in[1] = W16_0; 
//                 A_in[2] = x_reg[2];  B_in[2] = x_reg[10]; W_in[2] = W16_0; 
//                 A_in[3] = x_reg[6];  B_in[3] = x_reg[14]; W_in[3] = W16_0; 
//                 A_in[4] = x_reg[1];  B_in[4] = x_reg[9];  W_in[4] = W16_0; 
//                 A_in[5] = x_reg[5];  B_in[5] = x_reg[13]; W_in[5] = W16_0; 
//                 A_in[6] = x_reg[3];  B_in[6] = x_reg[11]; W_in[6] = W16_0; 
//                 A_in[7] = x_reg[7];  B_in[7] = x_reg[15]; W_in[7] = W16_0; 
//             end
            
//             S2_ROUTE, S2_MULT1, S2_MULT2, S2_ADD: begin
//                 A_in[0] = stg1_reg[0];  B_in[0] = stg1_reg[2];  W_in[0] = W16_0; 
//                 A_in[1] = stg1_reg[1];  B_in[1] = stg1_reg[3];  W_in[1] = W16_4; 
//                 A_in[2] = stg1_reg[4];  B_in[2] = stg1_reg[6];  W_in[2] = W16_0; 
//                 A_in[3] = stg1_reg[5];  B_in[3] = stg1_reg[7];  W_in[3] = W16_4; 
//                 A_in[4] = stg1_reg[8];  B_in[4] = stg1_reg[10]; W_in[4] = W16_0; 
//                 A_in[5] = stg1_reg[9];  B_in[5] = stg1_reg[11]; W_in[5] = W16_4; 
//                 A_in[6] = stg1_reg[12]; B_in[6] = stg1_reg[14]; W_in[6] = W16_0; 
//                 A_in[7] = stg1_reg[13]; B_in[7] = stg1_reg[15]; W_in[7] = W16_4; 
//             end

//             S3_ROUTE, S3_MULT1, S3_MULT2, S3_ADD: begin
//                 A_in[0] = stg2_reg[0];  B_in[0] = stg2_reg[4];  W_in[0] = W16_0; 
//                 A_in[1] = stg2_reg[1];  B_in[1] = stg2_reg[5];  W_in[1] = W16_2; 
//                 A_in[2] = stg2_reg[2];  B_in[2] = stg2_reg[6];  W_in[2] = W16_4; 
//                 A_in[3] = stg2_reg[3];  B_in[3] = stg2_reg[7];  W_in[3] = W16_6; 
//                 A_in[4] = stg2_reg[8];  B_in[4] = stg2_reg[12]; W_in[4] = W16_0; 
//                 A_in[5] = stg2_reg[9];  B_in[5] = stg2_reg[13]; W_in[5] = W16_2; 
//                 A_in[6] = stg2_reg[10]; B_in[6] = stg2_reg[14]; W_in[6] = W16_4; 
//                 A_in[7] = stg2_reg[11]; B_in[7] = stg2_reg[15]; W_in[7] = W16_6; 
//             end

//             S4_ROUTE, S4_MULT1, S4_MULT2, S4_ADD: begin
//                 A_in[0] = stg3_reg[0];  B_in[0] = stg3_reg[8];  W_in[0] = W16_0; 
//                 A_in[1] = stg3_reg[1];  B_in[1] = stg3_reg[9];  W_in[1] = W16_1; 
//                 A_in[2] = stg3_reg[2];  B_in[2] = stg3_reg[10]; W_in[2] = W16_2; 
//                 A_in[3] = stg3_reg[3];  B_in[3] = stg3_reg[11]; W_in[3] = W16_3; 
//                 A_in[4] = stg3_reg[4];  B_in[4] = stg3_reg[12]; W_in[4] = W16_4; 
//                 A_in[5] = stg3_reg[5];  B_in[5] = stg3_reg[13]; W_in[5] = W16_5; 
//                 A_in[6] = stg3_reg[6];  B_in[6] = stg3_reg[14]; W_in[6] = W16_6; 
//                 A_in[7] = stg3_reg[7];  B_in[7] = stg3_reg[15]; W_in[7] = W16_7; 
//             end
            
//             default: begin end
//         endcase
//     end
// endmodule