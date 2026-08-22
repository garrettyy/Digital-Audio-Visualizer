`timescale 1ns / 1ps

module audio_input(
    input  logic clk,
    input  logic rst,
    input  logic vauxp6, // Physical pin from the mic
    input  logic vauxn6, // Physical ground from the mic
    output logic signed [15:0] audio_data,
    output logic sample_valid
);
    logic [15:0] adc_raw_data;
    logic adc_data_ready;
    logic adc_eoc;

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

always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
        audio_data   <= 16'sd0;
        sample_valid <= 1'b0;
    end else if (adc_data_ready) begin
        // Securely cast the left-aligned unsigned XADC data to a signed format around midscale
        audio_data   <= $signed(adc_raw_data) - 16'sh8000;
        sample_valid <= 1'b1;
    end else begin
        sample_valid <= 1'b0;
    end
end
endmodule