// Image Reader: Streams data from BRAM to AXI-Stream interface
// Reads your COE file data and sends it to the AES encryptor

module image_reader #(
    parameter IMAGE_DEPTH = 768,   // Number of 128-bit words (adjust for your image)
    parameter ADDR_WIDTH = 10      // log2(IMAGE_DEPTH) rounded up
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  start,         // Pulse to begin streaming
    output reg                   done,          // Asserted when complete
    
    // BRAM interface (Simple ROM interface)
    output reg  [ADDR_WIDTH-1:0] bram_addr,
    input  wire [127:0]          bram_dout,     // 128-bit read data from BRAM
    output reg                   bram_en,       // BRAM enable
    
    // AXI-Stream Master output
    output reg  [127:0]          m_axis_tdata,
    output reg  [15:0]           m_axis_tkeep,  // Byte enables (16 bytes)
    output reg                   m_axis_tlast,  // Last block indicator
    output reg                   m_axis_tvalid,
    input  wire                  m_axis_tready
);

    reg [ADDR_WIDTH-1:0] word_count;
    reg [2:0] state;
    
    localparam IDLE      = 3'd0;
    localparam START_RD  = 3'd1;
    localparam WAIT_RD1  = 3'd2; // guard cycle for BRAM latency
    localparam WAIT_RD2  = 3'd3; // capture data after BRAM updates
    localparam SEND      = 3'd4;
    localparam DONE_ST   = 3'd5;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            bram_addr <= 0;
            bram_en <= 1'b0;
            word_count <= 0;
            m_axis_tvalid <= 1'b0;
            m_axis_tlast <= 1'b0;
            m_axis_tkeep <= 16'hFFFF;
            m_axis_tdata <= 128'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        bram_addr <= 0;
                        word_count <= 0;
                        state <= START_RD;
                    end
                end
                
                START_RD: begin
                    bram_en <= 1'b1;
                    state <= WAIT_RD1;
                end
                
                WAIT_RD1: begin
                    // Allow one cycle for BRAM output to update
                    bram_en <= 1'b0;
                    state <= WAIT_RD2;
                end
                
                WAIT_RD2: begin
                    // Now capture stable BRAM data
                    m_axis_tdata <= bram_dout;
                    m_axis_tvalid <= 1'b1;
                    m_axis_tkeep <= 16'hFFFF;  // All 16 bytes valid
                    m_axis_tlast <= (word_count == IMAGE_DEPTH - 1);
                    state <= SEND;
                end
                
                SEND: begin
                    if (m_axis_tready) begin
                        m_axis_tvalid <= 1'b0;
                        
                        if (m_axis_tlast) begin
                            state <= DONE_ST;
                        end else begin
                            // Move to next block
                            word_count <= word_count + 1;
                            bram_addr <= bram_addr + 1;
                            state <= START_RD;
                        end
                    end
                    // else: wait for downstream (AES) to be ready
                end
                
                DONE_ST: begin
                    done <= 1'b1;
                    m_axis_tlast <= 1'b0;
                    if (!start) state <= IDLE;
                end
            endcase
        end
    end

endmodule
