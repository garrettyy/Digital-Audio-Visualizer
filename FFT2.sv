`timescale 1ns / 1ps

module FFT2 #(parameter WIDTH = 32) (
    input  logic clk, rst, start,
    input  logic signed [WIDTH-1:0] x_in [0:15],  
    output logic signed [WIDTH-1:0] y_out [0:15],
    output logic complete
);

    // ==========================================
    // Twiddle Factors (Q15 Fixed-Point)
    // ==========================================
    localparam signed [31:0] W16_0 = { 16'sd32767,   16'sd0};
    localparam signed [31:0] W16_1 = { 16'sd30273, -16'sd12539};
    localparam signed [31:0] W16_2 = { 16'sd23170, -16'sd23170};
    localparam signed [31:0] W16_3 = { 16'sd12539, -16'sd30273};
    localparam signed [31:0] W16_4 = { 16'sd0,     -16'sd32768};
    localparam signed [31:0] W16_5 = {-16'sd12539, -16'sd30273};
    localparam signed [31:0] W16_6 = {-16'sd23170, -16'sd23170};
    localparam signed [31:0] W16_7 = {-16'sd30273, -16'sd12539};

    // ==========================================
    // FSM States (18-State 4-Cycle Pipeline)
    // ==========================================
    typedef enum logic [4:0] { // Expanded to 5 bits to hold 18 states
        IDLE     = 5'd0,
        S1_ROUTE = 5'd1,  S1_MULT1 = 5'd2,  S1_MULT2 = 5'd3,  S1_ADD = 5'd4,
        S2_ROUTE = 5'd5,  S2_MULT1 = 5'd6,  S2_MULT2 = 5'd7,  S2_ADD = 5'd8,
        S3_ROUTE = 5'd9,  S3_MULT1 = 5'd10, S3_MULT2 = 5'd11, S3_ADD = 5'd12,
        S4_ROUTE = 5'd13, S4_MULT1 = 5'd14, S4_MULT2 = 5'd15, S4_ADD = 5'd16,
        DONE     = 5'd17
    } state_t;
    
    state_t c_state, n_state;
    
    // ==========================================
    // BUTTERFLY UNIT INSTANTIATION
    // ==========================================
    logic signed [WIDTH-1:0] A_in [0:7], B_in [0:7], W_in [0:7];
    logic signed [WIDTH-1:0] out0 [0:7], out1 [0:7];

    genvar i;
    generate
        for (i = 0; i < 8; i++) begin : bfly_array
            FFT #(.WIDTH(WIDTH)) bfly_unit (
                .clk(clk), .rst(rst), 
                .A(A_in[i]), .B(B_in[i]), .W(W_in[i]), 
                .out0(out0[i]), .out1(out1[i])
            );
        end
    endgenerate

    // ==========================================
    // PIPELINE REGISTERS
    // ==========================================
    logic signed [WIDTH-1:0] x_reg [0:15]; // Internal Latch
    logic signed [WIDTH-1:0] stg1_reg [0:15];
    logic signed [WIDTH-1:0] stg2_reg [0:15];
    logic signed [WIDTH-1:0] stg3_reg [0:15];

    // ==========================================
    // BLOCK 1: Flip-Flops (State & Memory)
    // ==========================================
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            c_state <= IDLE;
            for (int k = 0; k < 16; k++) y_out[k] <= 0;
            for (int k = 0; k < 16; k++) x_reg[k] <= 0;
        end else begin
            c_state <= n_state;
            
            // Instantly latch the entire input array when triggered
            if (c_state == IDLE && start) begin
                for (int k = 0; k < 16; k++) begin
                    x_reg[k] <= x_in[k];
                end
            end
            
            // Capture data ONLY on the ADD cycle
            if (c_state == S1_ADD) begin
                for (int k = 0; k < 8; k++) begin
                    stg1_reg[2*k]   <= out0[k];
                    stg1_reg[2*k+1] <= out1[k];
                end
            end
            else if (c_state == S2_ADD) begin
                stg2_reg[0] <= out0[0]; stg2_reg[2] <= out1[0];
                stg2_reg[1] <= out0[1]; stg2_reg[3] <= out1[1];
                stg2_reg[4] <= out0[2]; stg2_reg[6] <= out1[2];
                stg2_reg[5] <= out0[3]; stg2_reg[7] <= out1[3];
                stg2_reg[8] <= out0[4]; stg2_reg[10] <= out1[4];
                stg2_reg[9] <= out0[5]; stg2_reg[11] <= out1[5];
                stg2_reg[12] <= out0[6]; stg2_reg[14] <= out1[6];
                stg2_reg[13] <= out0[7]; stg2_reg[15] <= out1[7];
            end
            else if (c_state == S3_ADD) begin
                stg3_reg[0] <= out0[0]; stg3_reg[4] <= out1[0];
                stg3_reg[1] <= out0[1]; stg3_reg[5] <= out1[1];
                stg3_reg[2] <= out0[2]; stg3_reg[6] <= out1[2];
                stg3_reg[3] <= out0[3]; stg3_reg[7] <= out1[3];
                stg3_reg[8] <= out0[4]; stg3_reg[12] <= out1[4];
                stg3_reg[9] <= out0[5]; stg3_reg[13] <= out1[5];
                stg3_reg[10] <= out0[6]; stg3_reg[14] <= out1[6];
                stg3_reg[11] <= out0[7]; stg3_reg[15] <= out1[7];
            end
            else if (c_state == S4_ADD) begin
                y_out[0] <= out0[0]; y_out[8] <= out1[0];
                y_out[1] <= out0[1]; y_out[9] <= out1[1];
                y_out[2] <= out0[2]; y_out[10] <= out1[2];
                y_out[3] <= out0[3]; y_out[11] <= out1[3];
                y_out[4] <= out0[4]; y_out[12] <= out1[4];
                y_out[5] <= out0[5]; y_out[13] <= out1[5];
                y_out[6] <= out0[6]; y_out[14] <= out1[6];
                y_out[7] <= out0[7]; y_out[15] <= out1[7];
            end
        end
    end
    
    // ==========================================
    // BLOCK 2: Next State Logic
    // ==========================================
    always_comb begin
        n_state = c_state;
        case (c_state)
            IDLE:     if (start) n_state = S1_ROUTE;
            
            S1_ROUTE: n_state = S1_MULT1;
            S1_MULT1: n_state = S1_MULT2;
            S1_MULT2: n_state = S1_ADD;
            S1_ADD:   n_state = S2_ROUTE;
            
            S2_ROUTE: n_state = S2_MULT1;
            S2_MULT1: n_state = S2_MULT2;
            S2_MULT2: n_state = S2_ADD;
            S2_ADD:   n_state = S3_ROUTE;
            
            S3_ROUTE: n_state = S3_MULT1;
            S3_MULT1: n_state = S3_MULT2;
            S3_MULT2: n_state = S3_ADD;
            S3_ADD:   n_state = S4_ROUTE;
            
            S4_ROUTE: n_state = S4_MULT1;
            S4_MULT1: n_state = S4_MULT2;
            S4_MULT2: n_state = S4_ADD;
            S4_ADD:   n_state = DONE;
            
            DONE:     n_state = IDLE; 
            default:  n_state = IDLE;
        endcase
    end
    
    // ==========================================
    // BLOCK 3: Datapath Routing 
    // ==========================================
    always_comb begin
        for (int k = 0; k < 8; k++) begin
            A_in[k] = 0; B_in[k] = 0; W_in[k] = 0;
        end
        complete = (c_state == DONE) ? 1'b1 : 1'b0;
        
        // Hold the routing stable for ALL FOUR CYCLES of each stage
        case (c_state)
            S1_ROUTE, S1_MULT1, S1_MULT2, S1_ADD: begin
                A_in[0] = x_reg[0];  B_in[0] = x_reg[8];  W_in[0] = W16_0; 
                A_in[1] = x_reg[4];  B_in[1] = x_reg[12]; W_in[1] = W16_0; 
                A_in[2] = x_reg[2];  B_in[2] = x_reg[10]; W_in[2] = W16_0; 
                A_in[3] = x_reg[6];  B_in[3] = x_reg[14]; W_in[3] = W16_0; 
                A_in[4] = x_reg[1];  B_in[4] = x_reg[9];  W_in[4] = W16_0; 
                A_in[5] = x_reg[5];  B_in[5] = x_reg[13]; W_in[5] = W16_0; 
                A_in[6] = x_reg[3];  B_in[6] = x_reg[11]; W_in[6] = W16_0; 
                A_in[7] = x_reg[7];  B_in[7] = x_reg[15]; W_in[7] = W16_0; 
            end
            
            S2_ROUTE, S2_MULT1, S2_MULT2, S2_ADD: begin
                A_in[0] = stg1_reg[0];  B_in[0] = stg1_reg[2];  W_in[0] = W16_0; 
                A_in[1] = stg1_reg[1];  B_in[1] = stg1_reg[3];  W_in[1] = W16_4; 
                A_in[2] = stg1_reg[4];  B_in[2] = stg1_reg[6];  W_in[2] = W16_0; 
                A_in[3] = stg1_reg[5];  B_in[3] = stg1_reg[7];  W_in[3] = W16_4; 
                A_in[4] = stg1_reg[8];  B_in[4] = stg1_reg[10]; W_in[4] = W16_0; 
                A_in[5] = stg1_reg[9];  B_in[5] = stg1_reg[11]; W_in[5] = W16_4; 
                A_in[6] = stg1_reg[12]; B_in[6] = stg1_reg[14]; W_in[6] = W16_0; 
                A_in[7] = stg1_reg[13]; B_in[7] = stg1_reg[15]; W_in[7] = W16_4; 
            end

            S3_ROUTE, S3_MULT1, S3_MULT2, S3_ADD: begin
                A_in[0] = stg2_reg[0];  B_in[0] = stg2_reg[4];  W_in[0] = W16_0; 
                A_in[1] = stg2_reg[1];  B_in[1] = stg2_reg[5];  W_in[1] = W16_2; 
                A_in[2] = stg2_reg[2];  B_in[2] = stg2_reg[6];  W_in[2] = W16_4; 
                A_in[3] = stg2_reg[3];  B_in[3] = stg2_reg[7];  W_in[3] = W16_6; 
                A_in[4] = stg2_reg[8];  B_in[4] = stg2_reg[12]; W_in[4] = W16_0; 
                A_in[5] = stg2_reg[9];  B_in[5] = stg2_reg[13]; W_in[5] = W16_2; 
                A_in[6] = stg2_reg[10]; B_in[6] = stg2_reg[14]; W_in[6] = W16_4; 
                A_in[7] = stg2_reg[11]; B_in[7] = stg2_reg[15]; W_in[7] = W16_6; 
            end

            S4_ROUTE, S4_MULT1, S4_MULT2, S4_ADD: begin
                A_in[0] = stg3_reg[0];  B_in[0] = stg3_reg[8];  W_in[0] = W16_0; 
                A_in[1] = stg3_reg[1];  B_in[1] = stg3_reg[9];  W_in[1] = W16_1; 
                A_in[2] = stg3_reg[2];  B_in[2] = stg3_reg[10]; W_in[2] = W16_2; 
                A_in[3] = stg3_reg[3];  B_in[3] = stg3_reg[11]; W_in[3] = W16_3; 
                A_in[4] = stg3_reg[4];  B_in[4] = stg3_reg[12]; W_in[4] = W16_4; 
                A_in[5] = stg3_reg[5];  B_in[5] = stg3_reg[13]; W_in[5] = W16_5; 
                A_in[6] = stg3_reg[6];  B_in[6] = stg3_reg[14]; W_in[6] = W16_6; 
                A_in[7] = stg3_reg[7];  B_in[7] = stg3_reg[15]; W_in[7] = W16_7; 
            end
            
            default: begin end
        endcase
    end
endmodule