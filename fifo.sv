module fifo (
    input logic clk, rst, audio_valid,
    input logic [15:0] audio_sample,
    output [31:0] parallel_samples [31:0],
    output logic samples_ready
);

logic [4:0] write_index = 0;
logic [31:0] buffer [31:0];

always_ff @(posedge clk, posedge rst) begin
    if (rst) begin
        // No need to reset to 0 because write index will be reset thus ignoring data
        write_index <= '0;
        samples_ready <= '0;
    end
    else begin
        samples_ready <= 0; 
        if (audio_valid) begin
            if (write_index == 31) begin
                // Write_index will loop back to 0 from accumulator so don't reset buffer
                samples_ready <= 1;
            end
            // Write audio to buffer and increment pointer per clock cycle
            buffer[write_index] <= {audio_sample, 16'd0};
            write_index <= write_index + 1; 
        end    
    end
end

// No conditionals (if) needed because its only read when flag is high
assign parallel_samples = buffer;

endmodule