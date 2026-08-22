`timescale 1ns / 1ps

module vga_timing (
    input  logic clk,
    input  logic rst,
    output logic [9:0] hc,
    output logic [9:0] vc,
    output logic hsync,
    output logic vsync,
    output logic video_on
);

    // Generate 25MHz pixel clock tick from 100MHz system clock
    logic [1:0] clk_div;
    logic p_tick;
    always_ff @(posedge clk or posedge rst) begin
        if (rst) clk_div <= 0;
        else     clk_div <= clk_div + 1;
    end
    assign p_tick = (clk_div == 0);

    // VGA 640x480 Timing Parameters
    localparam H_DISPLAY = 640, H_FP = 16, H_SYNC = 96, H_BP = 48, H_MAX = 800;
    localparam V_DISPLAY = 480, V_FP = 10, V_SYNC = 2,  V_BP = 33, V_MAX = 525;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            hc <= 0;
            vc <= 0;
        end else if (p_tick) begin
            if (hc == H_MAX - 1) begin
                hc <= 0;
                if (vc == V_MAX - 1) vc <= 0;
                else                 vc <= vc + 1;
            end else begin
                hc <= hc + 1;
            end
        end
    end

    // Sync generation
    assign hsync = ~(hc >= (H_DISPLAY + H_FP) && hc < (H_DISPLAY + H_FP + H_SYNC));
    assign vsync = ~(vc >= (V_DISPLAY + V_FP) && vc < (V_DISPLAY + V_FP + V_SYNC));
    assign video_on = (hc < H_DISPLAY) && (vc < V_DISPLAY);

endmodule