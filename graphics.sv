`timescale 1ns / 1ps


module graphics (
    input logic clk, rst, vsync, // We need clock and vsync for the decay animation!
    input logic video_on,
    input logic [9:0] hc, vc,
    input logic [9:0] held_mags [16:0], // Raw math bouncing data
    output logic [3:0] r, g, b
);

    // Internal memory array to hold the visual heights as they fall
    logic [9:0] draw_mags [16:0];
    
    logic vsync_past, vsync_edge;
    assign vsync_edge = ~vsync_past & vsync;

    // 1. The Visual Decay Animation Logic
    always_ff @(posedge clk) begin
        if (rst) begin
            vsync_past <= 0;
            for (int i=0; i<17; i++) draw_mags[i] <= 0;
        end else begin
            vsync_past <= vsync;
            
            // Update the animation once per frame
            if (vsync_edge) begin
                for (int i=0; i<17; i++) begin
                    
                    if (held_mags[i] > draw_mags[i])
                        // Snap up to the loud sound (and cap at 480 to prevent underflow!)
                        draw_mags[i] <= (held_mags[i] > 480) ? 10'd480 : held_mags[i];
                    else if (draw_mags[i] > 0)
                        // Slowly fall down by 1 pixel per frame
                        draw_mags[i] <= draw_mags[i] - 1;
                        
                end
            end
        end
    end

    // 2. The Render Logic (Pure Combinational)
    logic [9:0] hc_active;
    logic [4:0] bar_index;
    logic [4:0] read_index;
    logic [3:0] pixel_in_bar; 
    logic [9:0] current_mag;

    assign hc_active = hc - 64; 
    assign bar_index = hc_active[8:4]; 
    assign pixel_in_bar = hc_active[3:0]; 

    assign read_index = (bar_index > 16) ? (32 - bar_index) : bar_index;
    
    // Grab the smoothed, decaying height instead of the raw data!
    assign current_mag = draw_mags[read_index]; 

    always_comb begin
        r = 0; g = 0; b = 0; 
        
        if (video_on) begin
            if (hc >= 64 && hc < 576) begin 
                if (vc > (480 - current_mag)) begin
                    r = 4'h0; g = 4'hF; b = 4'h0; // GREEN
                    
                    if (pixel_in_bar < 2) begin
                        r = 4'h0; g = 4'h0; b = 4'h0; // Black gap
                    end
                end
            end
        end
    end
endmodule