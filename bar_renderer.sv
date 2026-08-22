`timescale 1ns / 1ps

module bar_renderer (
    input  logic [9:0] hc, // Horizontal counter (0-639)
    input  logic [9:0] vc, // Vertical counter (0-479)
    input  logic video_on,
    output logic [3:0] read_addr, // Asks Ping-Pong buffer for specific bin
    input  logic [9:0] bin_height,// Answers with the height of that bin
    output logic [3:0] vga_r, vga_g, vga_b
);

    // Invert the vertical counter since Y=0 is the TOP of the screen
    logic [9:0] inverted_y;
    assign inverted_y = 479 - vc;

    // Internal wires for our 512-pixel active window
    logic [9:0] hc_active;
    logic [4:0] pixel_in_bin; // The modulo replacement

    always_comb begin
        // Default outputs
        vga_r = 4'h0; vga_g = 4'h0; vga_b = 4'h0;
        read_addr = 4'd0;
        hc_active = 10'd0;
        pixel_in_bin = 5'd0;

        if (video_on) begin
            
            if (hc >= 64 && hc < 576) begin
                hc_active = hc - 64; // Normalize X coordinate to start at 0
                
                // HARDWARE FLEX: No division or modulo required!
                // hc_active[8:5] drops the bottom 5 bits (Divides by 32)
                read_addr = hc_active[8:5]; 
                
                // hc_active[4:0] keeps only the bottom 5 bits (Modulo 32)
                pixel_in_bin = hc_active[4:0]; 
    
                if (inverted_y < bin_height) begin
                    
                    // Dynamic Color Gradient
                    if (inverted_y > 350) begin
                        // Top: RED (Clipping/Loud)
                        vga_r = 4'hF; vga_g = 4'h0; vga_b = 4'h0;
                    end else if (inverted_y > 200) begin
                        // Middle: YELLOW
                        vga_r = 4'hF; vga_g = 4'hF; vga_b = 4'h0;
                    end else begin
                        // Bottom: GREEN (Quiet)
                        vga_r = 4'h0; vga_g = 4'hF; vga_b = 4'h0;
                    end
                    
                    // Add a 2-pixel black gap using our cheap modulo replacement
                    if (pixel_in_bin < 2) begin
                        vga_r = 4'h0; vga_g = 4'h0; vga_b = 4'h0;
                    end
                end
            end
        end
    end
endmodule