`timescale 1ns / 1ps

module time_filter (
    input  logic clk, rst,
    input  logic sample_valid,
    input  logic sw_filter_enable,
    input  logic highpass_enable,
    input  logic signed [15:0] audio_in,
    output logic signed [15:0] audio_out,
    output logic output_valid
);

    logic signed [15:0] tap0, tap1, tap2, tap3, tap4;

    logic signed [19:0] lp_sum;
    logic signed [15:0] lp_scaled;
    logic signed [16:0] hp;

    assign lp_scaled = lp_sum[19:4];
    assign hp = audio_in - lp_scaled;

    always_comb begin
        // Calculate Gaussian moving average and use parantheses for balanced tree adder
        lp_sum = ((tap0) + (tap1 << 2)) +
                 (tap2 << 2) + (tap2 << 1) +
                 ((tap3 << 2) + (tap4));
    end
    
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            tap0 <= 0;
            tap1 <= 0;
            tap2 <= 0;
            tap3 <= 0;
            tap4 <= 0;
            audio_out <= 0;
            output_valid <= 0;
        end else begin
            output_valid <= 0;

            if (sample_valid) begin
                // 5 tap shift register
                tap0 <= audio_in;
                tap1 <= tap0;
                tap2 <= tap1;
                tap3 <= tap2;
                tap4 <= tap3;
                
                // Based on on board switches let certain audio pass
                if (!sw_filter_enable)
                    audio_out <= audio_in;
                else if (highpass_enable)
                    audio_out <= hp[16:1];
                else
                    audio_out <= lp_scaled;

                output_valid <= 1;
            end
        end
    end
endmodule
