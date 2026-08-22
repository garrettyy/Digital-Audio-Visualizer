`timescale 1ns / 1ps

module fft_engine (
    input  logic clk,
    input  logic rst,
    input  logic start,                 
    input  logic signed [15:0] audio_sample,
    output logic signed [31:0] fft_out, 
    output logic [3:0] bin_index,       
    output logic fft_valid              
);

    logic signed [31:0] sample_buf [0:15]; 
    logic [3:0] sample_count; 
    
    logic fft2_start;
    logic fft2_complete;
    logic pending_start;
    
    logic signed [31:0] y_out_wire [0:15]; 
    
    logic [3:0] output_count; 
    logic streaming_out;
    
    logic fft_busy;

    FFT2 my_fft2 (
        .clk(clk), 
        .rst(rst), 
        .start(fft2_start),
        .x_in(sample_buf),    
        .y_out(y_out_wire),   
        .complete(fft2_complete)
    );

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            sample_count <= 0;
            fft2_start <= 0;
            streaming_out <= 0;
            output_count <= 0;
            fft_valid <= 0;
            fft_out <= 0;
            bin_index <= 0;
            pending_start <= 0;
            fft_busy <= 0; // Initialize lock
        end else begin
            fft2_start <= 0;
            fft_valid <= 0;
            
            if (pending_start) begin
                fft2_start <= pending_start;
                pending_start <= 0; 
            end
            // Manage the Unlock
            if (streaming_out && output_count == 15) fft_busy <= 1'b0;

            // Phase 1: Gather 16 serial audio samples
            if (start && !fft_busy && !streaming_out) begin
               
                sample_buf[sample_count] <= {audio_sample, 16'h0000}; 
                
                if (sample_count == 15) begin
                    sample_count <= 0;
                    pending_start <= 1;
                    fft_busy <= 1'b1; // FIX: Lock instantly on the exact same cycle!
                end else begin
                    sample_count <= sample_count + 1;
                end
                
            end     

            // Phase 2: Wait for FFT2 to finish
            if (fft2_complete) begin
                streaming_out <= 1;
                output_count <= 0;
            end

            // Phase 3: Stream to screen
            if (streaming_out) begin
                fft_valid <= 1;
                bin_index <= output_count;
                fft_out <= y_out_wire[output_count]; 
                
                if (output_count == 15) begin
                    streaming_out <= 0; 
                end else begin
                    output_count <= output_count + 1;
                end
            end
        end
    end
endmodule