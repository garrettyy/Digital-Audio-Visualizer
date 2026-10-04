`timescale 1ns / 1ps

module time_filter (
    input  logic clk, rst,
    input  logic sw_filter_enable,
    input  logic highpass_enable,
    
    input  logic s_axis_tvalid,
    input  logic signed [15:0] s_axis_tdata,
    output logic s_axis_tready,
    
    output logic m_axis_tvalid,
    output logic m_axis_tlast,
    output logic signed [15:0] m_axis_tdata,
    input  logic m_axis_tready
);

    logic signed [15:0] tap0, tap1, tap2, tap3, tap4;

    logic signed [19:0] lp_sum;
    logic signed [15:0] lp_scaled;
    logic signed [16:0] hp;

    assign lp_scaled = lp_sum[19:4];
    assign hp = tap0 - lp_scaled;
    assign tap0 = s_axis_tdata;

    assign m_axis_tlast = 0; // tlast will be for future use
    assign m_axis_tvalid = s_axis_tvalid; // Only stream audio out when audio in is valid
    assign s_axis_tready = m_axis_tready; // Pause sampling if upstream is busy
 
    always_comb begin
        // Calculate Gaussian moving average and use parantheses for balanced tree adder
        lp_sum = ((tap0) + (tap1 << 2)) +
                 (tap2 << 2) + (tap2 << 1) +
                 ((tap3 << 2) + (tap4));

        // Based on on board switches let certain audio pass
        if (!sw_filter_enable)
            m_axis_tdata = tap0;  
        else if (highpass_enable)
            m_axis_tdata = hp[16:1];     
        else
            m_axis_tdata = lp_scaled;   
    end
    
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            tap1 <= 0; tap2 <= 0; tap3 <= 0; tap4 <= 0;
        end else begin
            // Only stream when both sides handshake
            if (s_axis_tvalid && s_axis_tready) begin
                if (m_axis_tready && m_axis_tvalid) begin // Applies back pressure because we will drop audio samples when not ready
                    // 5 tap shift register
                    tap1 <= tap0;
                    tap2 <= tap1;
                    tap3 <= tap2;
                    tap4 <= tap3;
                    
                end
            end
        end
    end
endmodule
