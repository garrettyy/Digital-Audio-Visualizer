`timescale 1ns / 1ps

module time_filter (
    input  logic clk, rst,
    input  logic sample_valid_in,
    input  logic sw_filter_enable,
    input  logic sw_highpass_enable,
    input  logic signed [15:0] audio_in,
    output logic signed [15:0] audio_out,
    output logic sample_valid_out
);

    logic signed [15:0] tap0, tap1, tap2, tap3, tap4;

    logic signed [19:0] audio_ext, tap0_ext, tap1_ext, tap2_ext, tap3_ext, tap4_ext;
    logic signed [19:0] lp_sum;
    logic signed [19:0] low_pass_ext, high_pass_ext;

    assign audio_ext = {{4{audio_in[15]}}, audio_in};
    assign tap0_ext  = {{4{tap0[15]}}, tap0};
    assign tap1_ext  = {{4{tap1[15]}}, tap1};
    assign tap2_ext  = {{4{tap2[15]}}, tap2};
    assign tap3_ext  = {{4{tap3[15]}}, tap3};
    assign tap4_ext  = {{4{tap4[15]}}, tap4};

    assign low_pass_ext = lp_sum >>> 4;
    assign high_pass_ext = (audio_ext - low_pass_ext);

    always_comb begin
        lp_sum = (tap0_ext) +
                 (tap1_ext <<< 2) +
                 (tap2_ext <<< 2) + (tap2_ext <<< 1)+
                 (tap3_ext <<< 2) +
                 (tap4_ext);
    end
    
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            tap0 <= 16'sd0;
            tap1 <= 16'sd0;
            tap2 <= 16'sd0;
            tap3 <= 0;
            tap4 <= 0;
            audio_out <= 16'sd0;
            sample_valid_out <= 1'b0;
        end else begin
            sample_valid_out <= 1'b0;

            if (sample_valid_in) begin
                tap0 <= audio_in;
                tap1 <= tap0;
                tap2 <= tap1;
                tap3 <= tap2;
                tap4 <= tap3;
                
                if (!sw_filter_enable)
                    audio_out <= audio_in;
                else if (sw_highpass_enable)
                    audio_out <= high_pass_ext[15:0];
                else
                    audio_out <= low_pass_ext[15:0];

                sample_valid_out <= 1'b1;
            end
        end
    end
endmodule
