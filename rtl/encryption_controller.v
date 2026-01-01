// Top-Level Controller FSM
// Orchestrates the encryption process:
// 1. Configure AES (Key/IV)
// 2. Stream image data
// 3. Wait for completion

module encryption_controller (
    input  wire  clk,
    input  wire  rst_n,
    input  wire  start_encryption,  // External trigger (button press)
    output reg   encryption_done,   // LED indicator
    output reg   busy,              // LED indicator
    
    // Control signals to submodules
    output reg   config_start,
    input  wire  config_done,
    output reg   reader_start,
    input  wire  reader_done,
    input  wire  writer_done
);

    reg [2:0] state;
    
    localparam IDLE       = 3'd0;
    localparam CONFIG     = 3'd1;
    localparam WAIT_CFG   = 3'd2;
    localparam STREAM     = 3'd3;
    localparam WAIT_DONE  = 3'd4;
    localparam COMPLETE   = 3'd5;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            config_start <= 1'b0;
            reader_start <= 1'b0;
            encryption_done <= 1'b0;
            busy <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    encryption_done <= 1'b0;
                    busy <= 1'b0;
                    if (start_encryption) begin
                        state <= CONFIG;
                        busy <= 1'b1;
                    end
                end
                
                CONFIG: begin
                    config_start <= 1'b1;
                    state <= WAIT_CFG;
                end
                
                WAIT_CFG: begin
                    if (config_done) begin
                        config_start <= 1'b0;
                        state <= STREAM;
                    end
                end
                
                STREAM: begin
                    reader_start <= 1'b1;
                    state <= WAIT_DONE;
                end
                
                WAIT_DONE: begin
                    if (reader_done && writer_done) begin
                        reader_start <= 1'b0;
                        state <= COMPLETE;
                    end
                end
                
                COMPLETE: begin
                    encryption_done <= 1'b1;
                    busy <= 1'b0;
                    if (!start_encryption) state <= IDLE;
                end
            endcase
        end
    end

endmodule
