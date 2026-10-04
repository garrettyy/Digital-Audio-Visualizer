`timescale 1ns / 1ps

module audio_input (
    input logic clk,
    input logic rst,
    input logic vauxn6,
    input logic vauxp6,
    
    output logic signed [15:0] m_axis_tdata,
    output logic m_axis_tvalid,
    input  logic m_axis_tready
);
    logic [15:0] adc_raw_data;
    logic adc_eoc;
    logic adc_data_ready;

    // Instantiate ADC which produces audio samples at 39kHz
    xadc_wiz_0 XADC_INST (
        .daddr_in(7'h16),     
        .dclk_in(clk),         
        .reset_in(rst),
        .den_in(adc_eoc),      
        .di_in(16'h0),
        .dwe_in(1'b0),
        .vauxp6(vauxp6),
        .vauxn6(vauxn6),
        .busy_out(),
        .channel_out(),
        .do_out(adc_raw_data), 
        .drdy_out(adc_data_ready), 
        .eoc_out(adc_eoc),         
        .eos_out(), 
        .alarm_out(),
        .vp_in(1'b0),
        .vn_in(1'b0)
    );  

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            m_axis_tdata <= 0;
            m_axis_tvalid <= 0;
        end
        else begin
            // Drop valid flag when sample is transmitted
            if (m_axis_tready && m_axis_tvalid) begin
                m_axis_tvalid <= 0;
            end
            
            // Only sample audio when ADC says data is ready
            if (adc_data_ready) begin
                // Strip DC offset 
                m_axis_tdata <= $signed(adc_raw_data) - 16'sh8000; 
                m_axis_tvalid <= 1;
            end
        end
    end

endmodule