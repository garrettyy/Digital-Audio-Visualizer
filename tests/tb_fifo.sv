module tb_fifo;

logic clk, rst, audio_valid, samples_ready;
logic [15:0] audio_sample;
logic [31:0] parallel_samples [31:0];

FIFO dut (.clk(clk),
    .rst(rst),
    .audio_valid(audio_valid),
    .audio_sample(audio_sample),
    .parallel_samples(parallel_samples),
    .samples_ready(samples_ready)
);

initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

task automatic reset_dut();
    rst = 1;
    audio_valid = 0;
    @(posedge clk);
    @(posedge clk);
    rst = 0;
    @(posedge clk);
    @(posedge clk);
endtask

initial begin
    // RESET
    audio_sample = '0;
    reset_dut();
    // Test with all samples filled with 1's
    audio_sample = '1;
    audio_valid = 1;
    wait(samples_ready);
    #1;
    audio_valid =0;
    for (int i = 0; i < 32; i++) begin 
        assert(parallel_samples[i][31:16] == '1) else $fatal(1, "Mismatch! Bin: %0d Value: %h", i, parallel_samples[i]);
    end



    $display("Passed!");
    $finish;
end



endmodule