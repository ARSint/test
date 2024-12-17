module axilite_master_fifos (
    input  wire         clk,
    input  wire         reset_n,

    // AXI-Lite Master Interface
    output reg  [31:0]  AWADDR,
    output reg          AWVALID,
    input  wire         AWREADY,
    output reg  [31:0]  WDATA,
    output reg          WVALID,
    input  wire         WREADY,
    input  wire         BVALID,
    output reg          BREADY,
    output reg  [31:0]  ARADDR,
    output reg          ARVALID,
    input  wire         ARREADY,
    input  wire [31:0]  RDATA,
    input  wire         RVALID,
    output reg          RREADY,

    // TX FIFO (Write to AXI-Lite Slave)
    input  wire [31:0]  tx_fifo_data,
    input  wire         tx_fifo_empty,
    output reg          tx_fifo_rd_en,

    // RX FIFO (Read from AXI-Lite Slave)
    output reg [31:0]   rx_fifo_data,
    input  wire         rx_fifo_full,
    output reg          rx_fifo_wr_en,

    // Error indicators
    output reg          write_error,
    output reg          read_error
);

    // State encoding
    typedef enum logic [3:0] {
        IDLE,
        WRITE_ADDR,
        WRITE_DATA,
        WRITE_RESP,
        READ_ADDR,
        READ_DATA,
        ERROR
    } state_t;

    state_t state, next_state;

    // Timeout counter for error handling
    reg [7:0] timeout_counter;
    localparam TIMEOUT_THRESHOLD = 8'd255;

    // Sequential State Machine
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
            timeout_counter <= 8'd0;
        end else begin
            state <= next_state;

            // Increment timeout counter when in active states
            if (state != IDLE && state != ERROR)
                timeout_counter <= timeout_counter + 1;
            else
                timeout_counter <= 8'd0;
        end
    end

    // Output and Next State Logic
    always @(*) begin
        // Default signal assignments
        AWVALID = 1'b0;
        WVALID  = 1'b0;
        BREADY  = 1'b0;
        ARVALID = 1'b0;
        RREADY  = 1'b0;
        tx_fifo_rd_en = 1'b0;
        rx_fifo_wr_en = 1'b0;
        write_error   = 1'b0;
        read_error    = 1'b0;
        next_state    = state;

        case (state)
            // IDLE: Check if TX FIFO has data or RX FIFO has space
            IDLE: begin
                if (!tx_fifo_empty)
                    next_state = WRITE_ADDR;
                else if (!rx_fifo_full)
                    next_state = READ_ADDR;
            end

            // WRITE Operation: Address Phase
            WRITE_ADDR: begin
                AWVALID = 1'b1;
                AWADDR  = 32'h0000_0000;  // Example address
                if (AWREADY)
                    next_state = WRITE_DATA;
                else if (timeout_counter >= TIMEOUT_THRESHOLD)
                    next_state = ERROR;
            end

            // WRITE Operation: Data Phase
            WRITE_DATA: begin
                WVALID = 1'b1;
                WDATA  = tx_fifo_data;
                if (WREADY) begin
                    tx_fifo_rd_en = 1'b1;  // Read from TX FIFO
                    next_state = WRITE_RESP;
                end else if (timeout_counter >= TIMEOUT_THRESHOLD)
                    next_state = ERROR;
            end

            // WRITE Operation: Response Phase
            WRITE_RESP: begin
                BREADY = 1'b1;
                if (BVALID)
                    next_state = IDLE;  // Return to IDLE
                else if (timeout_counter >= TIMEOUT_THRESHOLD)
                    next_state = ERROR;
            end

            // READ Operation: Address Phase
            READ_ADDR: begin
                ARVALID = 1'b1;
                ARADDR  = 32'h0000_0004;  // Example address
                if (ARREADY)
                    next_state = READ_DATA;
                else if (timeout_counter >= TIMEOUT_THRESHOLD)
                    next_state = ERROR;
            end

            // READ Operation: Data Phase
            READ_DATA: begin
                RREADY = 1'b1;
                if (RVALID) begin
                    rx_fifo_wr_en = 1'b1;
                    rx_fifo_data  = RDATA;  // Write to RX FIFO
                    next_state = IDLE;      // Return to IDLE
                end else if (timeout_counter >= TIMEOUT_THRESHOLD)
                    next_state = ERROR;
            end

            // ERROR State
            ERROR: begin
                write_error = (state == WRITE_ADDR || state == WRITE_DATA || state == WRITE_RESP);
                read_error  = (state == READ_ADDR || state == READ_DATA);
                next_state  = IDLE;  // Reset to IDLE
            end

            default: next_state = IDLE;
        endcase
    end

endmodule
