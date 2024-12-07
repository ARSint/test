module apb_slave (
    input wire PCLK,
    input wire PRESETn,
    input wire PSEL,
    input wire PENABLE,
    input wire PWRITE,
    input wire [31:0] PADDR,
    input wire [31:0] PWDATA,
    input wire [3:0] PSTRB, // Optional byte-enable
    output reg [31:0] PRDATA,
    output reg PREADY,
    output reg PSLVERR,

    // External CSR Interface
    output reg csr_write,       // Signal to write data to CSR
    output reg csr_read,        // Signal to read data from CSR
    output reg [7:0] csr_addr,  // CSR address
    output reg [31:0] csr_wdata,// Data to write to CSR
    input wire [31:0] csr_rdata,// Data read from CSR
    input wire csr_ready,       // CSR ready signal
    input wire csr_error        // CSR error signal
);

    // State Definitions
    typedef enum logic [1:0] {
        IDLE   = 2'b00,
        SETUP  = 2'b01,
        ACCESS = 2'b10,
        ERROR  = 2'b11
    } state_t;

    state_t state, next_state;

    wire valid_address;

    // Address Validation
    assign valid_address = (PADDR < 255);

    // FSM State Transition
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (PSEL)
                    next_state = SETUP;
                else
                    next_state = IDLE;
            end

            SETUP: begin
                if (!valid_address)
                    next_state = ERROR;
                else if (PENABLE)
                    next_state = ACCESS;
                else
                    next_state = SETUP;
            end

            ACCESS: begin
                if (!PSEL)
                    next_state = IDLE;
                else
                    next_state = ACCESS;
            end

            ERROR: begin
                if (!PSEL)
                    next_state = IDLE;
                else
                    next_state = ERROR;
            end

            default: next_state = IDLE;
        endcase
    end

    // CSR Communication and Data Flow
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            csr_write <= 0;
            csr_read <= 0;
            csr_addr <= 0;
            csr_wdata <= 0;
            PRDATA <= 0;
            PREADY <= 0;
            PSLVERR <= 0;
        end else begin
            case (state)
                IDLE: begin
                    PREADY <= 0;
                    PSLVERR <= 0;
                    csr_write <= 0;
                    csr_read <= 0;
                end

                SETUP: begin
                    PREADY <= 0;
                    PSLVERR <= 0;
                end

                ACCESS: begin
                    PREADY <= csr_ready; // APB ready only when CSR is ready
                    PSLVERR <= csr_error; // Pass through CSR error signal

                    case (PADDR)
                        0: begin // Header Register
                            if (PWRITE) begin
                                csr_write <= 1;
                                csr_addr <= 8'h00; // Address for header CSR
                                csr_wdata <= PWDATA;
                            end else begin
                                csr_read <= 1;
                                csr_addr <= 8'h00; // Address for header CSR
                                PRDATA <= csr_rdata;
                            end
                        end
                        1: begin // Length Register
                            if (PWRITE) begin
                                csr_write <= 1;
                                csr_addr <= 8'h01; // Address for length CSR
                                csr_wdata <= PWDATA;
                            end else begin
                                csr_read <= 1;
                                csr_addr <= 8'h01; // Address for length CSR
                                PRDATA <= csr_rdata;
                            end
                        end
                        3: begin // RWData Register
                            if (PWRITE) begin
                                csr_write <= 1;
                                csr_addr <= 8'h03; // Address for rwdata CSR
                                csr_wdata <= PWDATA; // Push data
                            end else begin
                                csr_read <= 1;
                                csr_addr <= 8'h03; // Address for rwdata CSR
                                PRDATA <= csr_rdata; // Pop data
                            end
                        end
                        4: begin // Status Register
                            if (PWRITE) begin
                                csr_write <= 1;
                                csr_addr <= 8'h04; // Address for status CSR
                                csr_wdata <= PWDATA;
                            end else begin
                                csr_read <= 1;
                                csr_addr <= 8'h04; // Address for status CSR
                                PRDATA <= csr_rdata;
                            end
                        end
                        default: begin
                            PSLVERR <= 1; // Invalid address
                        end
                    endcase
                end

                ERROR: begin
                    PREADY <= 1;
                    PSLVERR <= 1;
                end
            endcase
        end
    end
endmodule
