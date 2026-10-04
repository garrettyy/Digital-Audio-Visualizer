`timescale 1ns / 1ps

module frame_buffer (
    input logic clk, rst, 
    
    input  logic s_axis_tvalid, 
    input  logic s_axis_tlast,
    input  logic [15:0] s_axis_tdata,
    output logic s_axis_tready,
    
    output logic [31:0] m_axis_tdata [31:0],
    output logic m_axis_tvalid,
    input  logic m_axis_tready
);

logic [4:0] write_index;
logic [31:0] buffer [31:0];

assign s_axis_tready = !m_axis_tvalid; // Ready for data when buffer is not full
assign m_axis_tdata = buffer;

always_ff @(posedge clk, posedge rst) begin
    if (rst) begin
        write_index <= '0;
        m_axis_tvalid <= 0;
    end
    else begin
        // Drop valid flag when we transmit parallel data to FFT
        if (m_axis_tready && m_axis_tvalid) begin
            m_axis_tvalid <= 0; 
        end
        
        if (s_axis_tvalid && s_axis_tready) begin
            buffer[write_index] <= {s_axis_tdata, 16'd0};
            
            if (&write_index) begin // write_index == 31
                m_axis_tvalid <= 1;
            end
            
            write_index <= write_index + 1; 
        end    
    end
end

endmodule