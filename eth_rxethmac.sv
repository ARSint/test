module eth_rxethmac (
    input wire MRxClk, // Clock for receiving Ethernet data
    input wire MRxDV, // Data valid signal for Ethernet data
    input wire [3:0] MRxD, // 4-bit data input for each clock cycle
    input wire Reset, // Reset signal for initialization
    input wire [47:0] MAC, // MAC address for filtering or processing
    input wire [15:0] MaxFL, // Maximum frame length
    input wire r_IFG, // Inter-frame gap
    input wire HugEn, // Jumbo frame enable
    input wire DlyCrcEn, // CRC delay enable
    output reg [47:0] dst_mac_reg, // Register to store the destination MAC address
    output reg [47:0] src_mac_reg, // Register to store the source MAC address
    output reg [15:0] length_reg, // Register to store the EtherType/Length field
    output reg RxValid, // Signal to indicate data is valid
    output reg [15:0] ByteCnt // Byte counter for received data
);

    // State definitions for the FSM
    localparam STATE_IDLE = 2'b00;
    localparam STATE_SFD = 2'b01;
    localparam STATE_HEADER = 2'b10;
    localparam STATE_PAYLOAD = 2'b11;

    // Register to hold the current state and next state
    reg [1:0] state, next_state;

    // Internal counters for header and payload processing
    reg [5:0] header_cnt; // Counter to track the number of header bytes received
    reg [7:0] byte_cnt; // Counter for tracking received payload bytes
    reg capture_header; // Flag to indicate when to capture header
    reg capture_payload; // Flag to indicate when to capture payload

    // Parameters for frame header size
    localparam MAC_ADDR_SIZE = 48;
    localparam ETH_TYPE_LEN_SIZE = 16;

    // Reset or initialize logic
    always @ (posedge MRxClk or posedge Reset) begin
        if (Reset) begin
            state <= STATE_IDLE;
            dst_mac_reg <= 48'b0;
            src_mac_reg <= 48'b0;
            length_reg <= 16'b0;
            RxValid <= 0;
            byte_cnt <= 8'b0;
            header_cnt <= 6'b0;
            capture_header <= 0;
            capture_payload <= 0;
            ByteCnt <= 16'b0;
        end else begin
            state <= next_state; // Transition to the next state
        end
    end

    // FSM State Logic
    always @ (state or MRxDV or MRxD or header_cnt or byte_cnt) begin
        case(state)
            STATE_IDLE: begin
                if (MRxDV) begin
                    next_state = STATE_SFD; // Start capturing when SFD is detected
                end else begin
                    next_state = STATE_IDLE;
                end
            end

            STATE_SFD: begin
                if (MRxDV) begin
                    next_state = STATE_HEADER; // After detecting SFD, move to header capture
                end else begin
                    next_state = STATE_IDLE;
                end
            end

            STATE_HEADER: begin
                if (header_cnt < 14) begin
                    next_state = STATE_HEADER; // Stay in header until it's fully captured
                end else begin
                    next_state = STATE_PAYLOAD; // After capturing header, move to payload
                end
            end

            STATE_PAYLOAD: begin
                if (byte_cnt < MaxFL) begin
                    next_state = STATE_PAYLOAD; // Continue capturing payload if within max length
                end else begin
                    next_state = STATE_IDLE; // Done with the frame, move back to idle
                end
            end

            default: next_state = STATE_IDLE; // Default state transition
        endcase
    end

    // Header capture and payload processing
    always @ (posedge MRxClk) begin
        case(state)
            STATE_SFD: begin
                // Wait for start of frame (SFD) to transition into header capture
                capture_header <= 1'b1;
            end

            STATE_HEADER: begin
                if (capture_header) begin
                    if (header_cnt < 6) begin
                        // Capture destination MAC address (6 bytes)
                        dst_mac_reg <= {dst_mac_reg[39:0], MRxD};
                    end else if (header_cnt < 12) begin
                        // Capture source MAC address (6 bytes)
                        src_mac_reg <= {src_mac_reg[39:0], MRxD};
                    end else if (header_cnt < 14) begin
                        // Capture EtherType/Length field (2 bytes)
                        length_reg <= {length_reg[7:0], MRxD};
                    end
                    header_cnt <= header_cnt + 1;
                end
            end

            STATE_PAYLOAD: begin
                // Capture payload once header is captured
                if (byte_cnt < MaxFL) begin
                    // Process payload (if needed) - increment byte counter
                    byte_cnt <= byte_cnt + 1;
                    ByteCnt <= ByteCnt + 1; // Increment the global byte counter
                end
            end

            default: begin
                // Reset flags and counters when transitioning out of any state
                capture_header <= 0;
                capture_payload <= 0;
            end
        endcase
    end

    // Set RxValid signal when frame is fully captured
    always @ (posedge MRxClk) begin
        if (state == STATE_PAYLOAD && byte_cnt >= MaxFL) begin
            RxValid <= 1; // Set RxValid when the entire frame is captured
        end else begin
            RxValid <= 0;
        end
    end
endmodule
