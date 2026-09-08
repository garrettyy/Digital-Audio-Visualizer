`timescale 1ns / 1ps


module graphics (
    input logic clk, rst, vsync, 
    input logic video_on,
    input logic [9:0] hc, vc,
    input logic [9:0] next_mags [16:0], 
    output logic [3:0] r, g, b
);

    logic [9:0] draw_mags [16:0];
    
    logic vsync_past, vsync_edge;
    assign vsync_edge = ~vsync_past & vsync;

    // Sequential logic block to store decaying bar heights
    always_ff @(posedge clk) begin
        if (rst) begin
            vsync_past <= 0;
            for (int i=0; i<17; i++) 
                draw_mags[i] <= 0;
        end else begin
            vsync_past <= vsync;
            
            // Update the display once per frame
            if (vsync_edge) begin
                for (int i=1; i<17; i++) begin // Start at 1 to ignore bin 0
                    if (next_mags[i] > draw_mags[i])
                        draw_mags[i] <= (next_mags[i] > 480) ? 10'd480 : next_mags[i]; // Update to new height with a cap
                    else if (draw_mags[i] > 15)
                        draw_mags[i] <= draw_mags[i] - 15; // Slowly lower bar heights for visual effect when next_mags is lower
                    else
                        draw_mags[i] <= 0; // Don't allow negative heights
                        
                end
            end
        end
    end

    logic [8:0] hc_active;
    logic [4:0] bar_index;
    logic [4:0] read_index;
    logic [3:0] pixel_in_bar; 
    logic [9:0] current_mag;

    assign hc_active = hc - 64; 
    assign bar_index = hc_active[8:4]; // Split active region into 32 sections (5 bit index)
    assign pixel_in_bar = hc_active[3:0]; // This array slicing does mod 16 (% 16)

    assign read_index = (bar_index > 16) ? (32 - bar_index) : bar_index; // Mirrors bins after bin 16 and reads current bar index
    
    assign current_mag = draw_mags[read_index]; // Grab correct magnitude based on which bin we are in

    always_comb begin
        r = 0; g = 0; b = 0; 
        
        if (video_on) begin
            if (hc >= 64 && hc < 576) begin 
                if (vc > (480 - current_mag)) begin // Draw bar when vc is lower than height because vc counts from top to bottom
                    r = 4'h0; g = 4'hF; b = 4'h0; // Green bar
                    
                    if (pixel_in_bar < 2) begin 
                        r = 4'h0; g = 4'h0; b = 4'h0; // Black gap
                    end
                end
            end
        end
    end
endmodule