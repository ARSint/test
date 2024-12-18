module axi_lite_fsm (
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
    // header reg
    input reg   [43:0] head_reg,//details from opcode {length_reg,first_32bits[31:8],first_32bits[3:0]};
    // TX FIFO
    input  wire [31:0]  tx_fifo_data,
    input  wire         tx_fifo_empty,
    output reg          tx_fifo_rd_en,

    // RX FIFO
    output reg [31:0]   rx_fifo_data,
    input  wire         rx_fifo_full,
    output reg          rx_fifo_wr_en,
    output reg          hfifo_rd_en,
    // Error indicators
    output reg          write_error,
    output reg          read_error
);

    // State encoding
       parameter logic IDLE = 4'b0000;
       parameter logic WRITE_ADDR = 4'b0001;
       parameter logic WRITE_DATA = 4'b0010;
       parameter logic WRITE_RESP = 4'b0011;
       parameter logic READ_ADDR = 4'b0100;
       parameter logic READ_DATA = 4'b0101;
       parameter logic ERROR = 4'b0110;
    

    logic [3:0] state, next_state;
    logic [15:0] byte_count;
    // Timeout counter for error handling
    reg [7:0] timeout_counter;
    localparam TIMEOUT_THRESHOLD = 8'd255;


    logic [31:0]address;
    logic [3:0]opcode;
    logic [15:0]framelen;
    logic rw;

    logic [15:0]wbustcount;
    logic [15:0]rbustcount;
	
    logic [31:0]waddressreg;
    logic [31:0]raddressreg;
	
    assign address = head_reg[27:4];
    assign opcode = head_reg[3:0];
    assign rw = head_reg[0];
    assign framelen = head_reg[43:28];

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
	/* always @(posedge clk or negedge reset_n) begin
					hfifo_rd_en<=!hfifo_empty && (AWREADY || ARADDR);
					if(wbustcount==framelen-1)begin
						hfifo_rd_en<=1'b1;
					end
	end */
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
		waddressreg = 32'b0;
		raddressreg = 32'b0;
        case (state)
            // IDLE: Check if TX FIFO has data or RX FIFO has space
            IDLE: begin
                if (!tx_fifo_empty & !rw)begin
                    next_state = WRITE_ADDR;
                    wbustcount=0;
               end else if (!rx_fifo_full & rw) begin
                    next_state = READ_ADDR;
                    rbustcount=0; end
            end

            // WRITE Operation: Address Phase
            WRITE_ADDR: begin
                AWVALID = 1'b1;
                if(wbustcount==0)begin
                    waddressreg  <= address;  //address axilite
                end else if(wbustcount!=0 && wbustcount<=framelen-1) begin
                    waddressreg  <= waddressreg+4;  //address axilite with burst
                    wbustcount <= wbustcount+1;
				
                end
                AWADDR  <= waddressreg; 
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
                if(rbustcount==0)begin
                    raddressreg  <= address;  //address axilite
                end else if(rbustcount!=0 && rbustcount<=framelen-1) begin
                    raddressreg  <= raddressreg+4;  //address axilite with burst
                    rbustcount <= rbustcount+4;
                end
                ARADDR  <= raddressreg;  // Example address
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