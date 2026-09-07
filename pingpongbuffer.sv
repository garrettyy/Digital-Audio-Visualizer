`timescale 1ns / 1ps

module ping_pong_buffer (
    input logic clk, rst,
    input logic fft_valid, vsync,
    input logic [9:0] scaled_mags [16:0],
    output logic [9:0] held_mags [16:0]
);

logic [9:0] bufferA [16:0];
logic [9:0] bufferB [16:0];
logic buffer_toggle;
logic vsync_past, vsync_edge;

// Detect vsync rising edge
assign vsync_edge = ~vsync_past & vsync;

always_ff @(posedge clk, posedge rst) begin
    if (rst) begin
        vsync_past <= 0;
        buffer_toggle <= 0;
        for (int i =0; i<17; i++) begin
            bufferA[i] <= 0;
            bufferB[i] <= 0;
        end
    end
    else begin
        if (vsync_edge)
            buffer_toggle <= ~buffer_toggle;
        if (fft_valid) begin // Latch magnitudes when fft is full
            if (buffer_toggle) // Switch where we write to off vsync
                bufferB <= scaled_mags;
            else
                bufferA <= scaled_mags;
        end
        vsync_past <= vsync;
    end
end

// Buffer toggle decides where vga reads from
always_comb begin
    if (buffer_toggle)
        held_mags = bufferA;
    else
        held_mags = bufferB;
end

endmodule