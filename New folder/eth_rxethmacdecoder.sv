
module eth_rxethmacdecoder (
    // Input ports
    input  wire        MRxClk,        // Clock for receiving Ethernet data
    input  wire        Reset,         // Reset signal for initialization
    input  wire        MRxDV,         // Data valid signal for Ethernet data
    input  wire [7:0]  MRxD,          // 8-bit data input for each clock cycle
    input  wire [47:0] MAC,           // MAC address for filtering or processing
    input  wire [15:0] MaxFL,         // Maximum frame length
    input  wire        r_IFG,         // Inter-frame gap
    input  wire        HugEn,         // Jumbo frame enable
    input  wire        DlyCrcEn,      // CRC delay enable
    input  wire        RxStartFrm,    // Start-of-frame signal
    input  wire        RxEndFrm,      // End-of-frame signal
    input  wire        CrcError,      // CRC error indicator
    input  wire        AddressMiss,   // Address mismatch indicator

    // Output ports
    output reg  [47:0] dst_mac_reg,   // Destination MAC address register
    output reg  [47:0] src_mac_reg,   // Source MAC address register
    output reg  [15:0] length_reg,    // Length/EtherType field register
    output reg         RxValid,       // Data valid signal
    output reg  [31:0] first_32bits,  // First 32 bits of data
    output reg  [23:0] address,       // 24-bit address (filled with 0s at MSB)
    output reg  [3:0]  opcode,        // Extracted opcode (bits 3 downto 0)
    output reg  [15:0] ByteCnt,       // Byte counter for received data

    // RXFIFO signals (added as requested)
    output reg        rxfifo_wr_en,     // FIFO write enable
    output reg [31:0] rxfifo_data,       // FIFO data
    // HEADERFIFO signals (added as requested)
    output reg        hfifo_wr_en,     // FIFO write enable
    output reg        hfifo_wren,     // FIFO write enable
    output reg [43:0] hfifo_data       // FIFO data
);

    // State definitions for the FSM
    
       parameter STATE_IDLE     = 2'b00;
       parameter STATE_SFD      = 2'b01;
       parameter STATE_HEADER_DATA   = 2'b10;
      // parameter STATE_DATA     = 2'b11;
    
reg sfd;
    // Registers for FSM state tracking
    reg [2:0] current_state, next_state;
    reg        [7:0]  tMRxD;
	reg tMRxDV,flag,rxfifo_wren;
    // Internal counters and flags
    reg [11:0] header_byte_cnt; // Counter for header bytes
    reg [2:0]  data_byte_cnt;   // Counter for first 32 bits (4 bytes)
    reg [1:0] byte_cnt,rbyte_cnt,hbyte_cnt;
    // --- Input Processing Block ---
    always @(posedge MRxClk or posedge Reset) begin
        if (Reset) begin
            current_state   <= STATE_IDLE;
            dst_mac_reg     <= 48'b0;
            src_mac_reg     <= 48'b0;
            length_reg      <= 16'b0;
            RxValid         <= 1'b0;
            first_32bits    <= 32'b0;
            address         <= 24'b0; // Reset to 24 bits with MSBs filled with 0
            opcode          <= 4'b0;
            ByteCnt         <= 16'b0;
            header_byte_cnt <= 6'b0;
            data_byte_cnt   <= 3'b0;
            rxfifo_wr_en      <= 1'b0;
            rxfifo_data       <= 32'b0;
            //hfifo_wr_en      <= 1'b0;
            hfifo_data       <= 32'b0;
        end else begin
            current_state <= next_state;
			tMRxD<=MRxD;
			tMRxDV<=MRxDV;
        end
    end

//WRIET ENABLE FOR HEADER FIFO
always @(posedge MRxClk or posedge Reset) begin
    if (Reset) begin
        rxfifo_data  <= 32'b0;
        hbyte_cnt     <= 2'b0;
        rxfifo_wren <= 1'b0;
    end else if (current_state == STATE_HEADER_DATA && MRxDV) begin
        // Shift and append incoming byte
		if(header_byte_cnt >= 14) begin
            hbyte_cnt <= hbyte_cnt + 1;
		end
        if (hbyte_cnt == 2'b11) begin
            rxfifo_wren <= 1'b1;  // Generate write pulse
            hbyte_cnt <= 2'b00;     // Reset counter
        end else begin
            rxfifo_wren <= 1'b0;  // De-assert write enable
        end
    end else begin
        rxfifo_wren <= 1'b0;  // Default: no write
        hbyte_cnt <= 2'b00;     // Reset counter in other states
    end
end
assign hfifo_wr_en=hfifo_wren & rxfifo_wren;
//READ ENABLE FOR RX FIFO
always @(posedge MRxClk or posedge Reset) begin
    if (Reset) begin
        rxfifo_data  <= 32'b0;
        rbyte_cnt     <= 2'b0;
        rxfifo_wr_en <= 1'b0;
    end else if (current_state == STATE_HEADER_DATA && MRxDV) begin
        // Shift and append incoming byte
		if(header_byte_cnt >= 18) begin
            rbyte_cnt <= rbyte_cnt + 1;
		end
        if (rbyte_cnt == 2'b11) begin
            rxfifo_wr_en <= 1'b1;  // Generate write pulse
            rbyte_cnt <= 2'b00;     // Reset counter
        end else begin
            rxfifo_wr_en <= 1'b0;  // De-assert write enable
        end
    end else begin
        rxfifo_wr_en <= 1'b0;  // Default: no write
        rbyte_cnt <= 2'b00;     // Reset counter in other states
    end
end

    // --- Data Processing Block ---
    always @(posedge MRxClk) begin
        if (Reset) begin 
            dst_mac_reg     <= 48'b0;
            src_mac_reg     <= 48'b0;
            length_reg      <= 16'b0;
            first_32bits    <= 32'b0;
            address         <= 24'b0; // Reset to 24 bits with MSBs filled with 0
            opcode          <= 4'b0;
            RxValid         <= 1'b0;
            ByteCnt         <= 16'b0;
            header_byte_cnt <= 6'b0;
            data_byte_cnt   <= 3'b0;
            rxfifo_data       <= 32'b0;
            hfifo_wren      <= 1'b0;
            hfifo_data       <= 32'b0;
        end else begin
				if (MRxDV && RxStartFrm) begin
					header_byte_cnt <= header_byte_cnt + 1;
					if(header_byte_cnt==length_reg+18)begin
					header_byte_cnt <= 6'b0;
					end
					if(header_byte_cnt==1)begin
						sfd<=1'b1;
                    end else if (header_byte_cnt>=2 && header_byte_cnt <= 7) begin
                        dst_mac_reg <= {dst_mac_reg[39:0], MRxD};
                    end else if (header_byte_cnt>=8 && header_byte_cnt <= 13) begin
                        src_mac_reg <= {src_mac_reg[39:0], MRxD};
                    end else if (header_byte_cnt>=14 && header_byte_cnt <= 15) begin
                        length_reg <= {length_reg[7:0], MRxD};
					end else if(header_byte_cnt>=16 && header_byte_cnt<=19)begin
						first_32bits <= {first_32bits[23:0], MRxD};
						hfifo_data <= {length_reg,first_32bits[31:8],first_32bits[3:0]};
						hfifo_wren<=1'b1;
                    end else if(header_byte_cnt >= 20) begin
					    hfifo_wren <= 1'b0;
                        rxfifo_data <= {rxfifo_data[23:0], MRxD};  // Write the incoming data to FIFO
					end else begin
						//rxfifo_wr_en <= 1'b0;
						hfifo_wren <= 1'b0;	
					end
				end

            // Set RxValid when data capture is complete
            if (current_state == STATE_HEADER_DATA && data_byte_cnt == length_reg) begin
                RxValid <= 1'b1;
            end else begin
                RxValid <= 1'b0;
            end
        end 
    end

endmodule
