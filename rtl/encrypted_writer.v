// Encrypted Data Writer: Receives encrypted data from AES and stores to BRAM
// This allows you to read back and verify the encrypted output

module encrypted_writer #(
    parameter IMAGE_DEPTH = 768,
    parameter ADDR_WIDTH = 10
)(
    input  wire                  clk,
    input  wire                  rst_n,
    output reg                   done,          // Asserted when all data written
    
    // BRAM interface (Write side)
    output reg  [ADDR_WIDTH-1:0] bram_addr,
    output reg  [127:0]          bram_din,
    output reg                   bram_we,       // Write enable
    output reg                   bram_en,
    
    // AXI-Stream Slave input (from AES output)
    input  wire [127:0]          s_axis_tdata,
    input  wire [15:0]           s_axis_tkeep,
    input  wire                  s_axis_tlast,
    input  wire                  s_axis_tvalid,
    output reg                   s_axis_tready
);

    reg [ADDR_WIDTH-1:0] word_count;
    reg                  receiving;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bram_addr <= 0;
            word_count <= 0;
            bram_we <= 1'b0;
            bram_en <= 1'b0;
            s_axis_tready <= 1'b1;
            done <= 1'b0;
            bram_din <= 128'd0;
            receiving <= 1'b0;
        end else begin
            // Default: disable write
            bram_we <= 1'b0;
            bram_en <= 1'b0;
            
            if (s_axis_tvalid && s_axis_tready && !done) begin
                // Write encrypted data to BRAM
                bram_addr <= word_count;
                bram_din <= s_axis_tdata;
                bram_we <= 1'b1;
                bram_en <= 1'b1;
                word_count <= word_count + 1;
                receiving <= 1'b1;
                
                if (s_axis_tlast) begin
                    done <= 1'b1;
                    s_axis_tready <= 1'b0;  // Stop accepting data
                end
            end
        end
    end

endmodule
