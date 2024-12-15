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
    output reg  [15:0] ByteCnt        // Byte counter for received data
);

    // State definitions for the FSM
    typedef enum logic [1:0] {
        STATE_IDLE     = 2'b00,
        STATE_SFD      = 2'b01,
        STATE_HEADER   = 2'b10,
        STATE_DATA     = 2'b11
    } state_t;

    // Registers for FSM state tracking
    reg state_t current_state, next_state;
    
    // Internal counters and flags
    reg [5:0] header_byte_cnt; // Counter for header bytes
    reg [2:0] data_byte_cnt;   // Counter for first 32 bits (4 bytes)

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
        end else begin
            current_state <= next_state;
        end
    end

    // --- FSM for State Transitions ---
    always @(*) begin
        case (current_state)
            STATE_IDLE: begin
                if (MRxDV && RxStartFrm) begin
                    next_state = STATE_SFD;
                end else begin
                    next_state = STATE_IDLE;
                end
            end

            STATE_SFD: begin
                if (MRxDV) begin
                    next_state = STATE_HEADER;
                end else begin
                    next_state = STATE_IDLE;
                end
            end

            STATE_HEADER: begin
                if (header_byte_cnt < 14) begin
                    next_state = STATE_HEADER;
                end else begin
                    next_state = STATE_DATA;
                end
            end

            STATE_DATA: begin
                if (data_byte_cnt < 4) begin
                    next_state = STATE_DATA;
                end else if (RxEndFrm) begin
                    next_state = STATE_IDLE;
                end else begin
                    next_state = STATE_IDLE;
                end
            end

            default: next_state = STATE_IDLE;
        endcase
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
        end else begin
            case (current_state)
                STATE_SFD: begin
                    // Reset counters for header capture
                    header_byte_cnt <= 6'b0;
                end

                STATE_HEADER: begin
                    if (header_byte_cnt < 6) begin
                        dst_mac_reg <= {dst_mac_reg[39:0], MRxD};
                    end else if (header_byte_cnt < 12) begin
                        src_mac_reg <= {src_mac_reg[39:0], MRxD};
                    end else if (header_byte_cnt < 14) begin
                        length_reg <= {length_reg[7:0], MRxD};
                    end
                    header_byte_cnt <= header_byte_cnt + 1;
                end

                STATE_DATA: begin
                    if (data_byte_cnt == 0) begin
                        // Capture the address (bits 23 downto 0) in the first 32 bits
                        first_32bits[31:8] <= {first_32bits[23:0], MRxD};
                        address[23:0] <= {address[15:0], MRxD};  // Capture only 24 bits of address
                    end else if (data_byte_cnt == 1) begin
                        // Capture reserved (bits 7 downto 4) and opcode (bits 3 downto 0)
                        first_32bits[7:0] <= {first_32bits[3:0], MRxD[7:4]};  // reserved bits
                        first_32bits[3:0] <= MRxD[3:0]; // opcode bits
                        opcode <= MRxD[3:0];  // Capture the opcode
                    end
                    data_byte_cnt <= data_byte_cnt + 1;
                    ByteCnt <= ByteCnt + 1;
                end

                default: begin
                    // Default case to clear flags and counters
                    RxValid <= 1'b0;
                end
            endcase

            // Set RxValid when data capture is complete
            if (current_state == STATE_DATA && data_byte_cnt == 2) begin
                RxValid <= 1'b1;
            end else begin
                RxValid <= 1'b0;
            end
        end
    end

endmodule
