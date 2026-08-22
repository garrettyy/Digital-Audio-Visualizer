`timescale 1ns / 1ps

module ping_pong_buffer (
    input  logic clk,
    input  logic rst,
    input  logic vsync,
    input  logic write_en,
    input  logic [3:0] write_addr,
    input  logic [9:0] write_data,
    input  logic [3:0] read_addr,
    output logic [9:0] read_data
);

    logic active_buffer;
    logic pending_swap;
    logic vsync_past;
    logic vsync_falling_edge;

    logic [9:0] ram0 [0:15];
    logic [9:0] ram1 [0:15];

    assign vsync_falling_edge = vsync_past && !vsync;

    initial begin
        active_buffer = 1'b0;
        pending_swap  = 1'b0;
        vsync_past    = 1'b0;

        for (int i = 0; i < 16; i++) begin
            ram0[i] = 10'd0;
            ram1[i] = 10'd0;
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            active_buffer <= 1'b0;
            pending_swap  <= 1'b0;
            vsync_past    <= 1'b0;
        end else begin
            vsync_past <= vsync;

            if (write_en && write_addr == 4'd15) begin
                pending_swap <= 1'b1;
            end

            if (vsync_falling_edge && pending_swap) begin
                active_buffer <= ~active_buffer;
                pending_swap  <= 1'b0;
            end
        end
    end

    // Freeze the completed back buffer while it waits for the next VSYNC swap.
    always_ff @(posedge clk) begin
        if (write_en && !pending_swap) begin
            if (active_buffer) begin
                ram0[write_addr] <= write_data;
            end else begin
                ram1[write_addr] <= write_data;
            end
        end
    end

    always_comb begin
        if (active_buffer) begin
            read_data = ram1[read_addr];
        end else begin
            read_data = ram0[read_addr];
        end
    end

endmodule
