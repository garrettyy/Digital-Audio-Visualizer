`timescale 1ns/1ps 

module tb_fft;
    logic clk, rst, samples_ready;
    logic [31:0] parallel_samples [31:0];
    logic [31:0] fft_out [16:0];
    logic fft_valid;

    FFT dut(.clk(clk),
        .rst(rst),
        .samples_ready(samples_ready),
        .parallel_samples(parallel_samples),
        .fft_out(fft_out),
        .fft_valid(fft_valid)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    task automatic run_dut();
        @(negedge clk);
        samples_ready = 1; // Drive ready flag before posedge of clk
        @(negedge clk);
        samples_ready = 0;
        wait(fft_valid);
        #1; // Wait 1ns for fft_out to stabilize within the clock cycle
    endtask

    task automatic reset_dut();
        rst = 1;
        samples_ready = 0;
        @(posedge clk); // Wait until values are assuredly reset
        @(posedge clk);
        rst = 0;
        @(posedge clk);
        @(posedge clk);
    endtask

    initial begin
        for (int i = 0; i < 32; i++)
            parallel_samples[i] = '0;

        // Tests signed negative impulse
        reset_dut();
        parallel_samples[0] = 32'hf000_0000;
        run_dut();
        for (int i = 0; i <= 16; i++) begin
            assert(fft_out[i] == 32'hff80_0000) else $fatal(1, "Impulse test mismatch on bin %0d; value was %h", i, fft_out[i]);
        end

        // Tests Impulse
        reset_dut();
        parallel_samples[0] = 32'h7000_0000;
        run_dut();
        for (int i = 0; i <= 16; i++) begin
            assert(fft_out[i] == 32'h0380_0000) else $fatal(1, "Impulse test mismatch on bin %0d; value was %h", i, fft_out[i]);
        end

        // Test DC input
        reset_dut();
        for (int i = 0; i < 32; i++) begin
            parallel_samples[i]= 32'h7f000000;
        end
        run_dut();
        assert(fft_out[0] > 32'h7e000000) else $fatal(1, "DC test mistmatch on bin %0d; value was %h", 0, fft_out[0]);
        for (int i = 1; i <= 16; i++) begin 
            assert(fft_out[i] == 0) else $fatal(1, "DC test mistmatch on bin %0d; value was %h", i, fft_out[i]);
        end

        $display("PASSED!");
        $finish;
    end

endmodule

