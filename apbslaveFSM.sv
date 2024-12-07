module apb_slave (
    input wire PCLK,
    input wire PRESETn,
    input wire PSEL,
    input wire PENABLE,
    input wire PWRITE,
    input wire [31:0] PADDR,
    input wire [31:0] PWDATA,
    input wire [3:0] PSTRB,       // Optional: Byte enable
    output reg [31:0] PRDATA,
    output reg PREADY,
    output reg PSLVERR
);

    // State Definitions
    typedef enum logic [1:0] {
        IDLE   = 2'b00,
        SETUP  = 2'b01,
        ACCESS = 2'b10,
        ERROR  = 2'b11
    } state_t;

    state_t state, next_state;

    // Internal Registers
    reg [31:0] memory [0:15]; // Example 16 registers
    reg [31:0] read_data;
    wire valid_address;

    // Address Range Check
    assign valid_address = (PADDR < 16); // Address within memory range

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

    // Output Logic
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            PREADY  <= 0;
            PSLVERR <= 0;
            PRDATA  <= 32'b0;
        end else begin
            case (state)
                IDLE: begin
                    PREADY  <= 0;
                    PSLVERR <= 0;
                end

                SETUP: begin
                    PREADY <= 0;
                    PSLVERR <= 0;
                end

                ACCESS: begin
                    PREADY <= 1; // Indicate operation is done
                    if (PWRITE) begin
                        // Write Operation
                        if (valid_address) begin
                            memory[PADDR] <= PWDATA;
                        end
                    end else begin
                        // Read Operation
                        if (valid_address) begin
                            PRDATA <= memory[PADDR];
                        end
                    end
                end

                ERROR: begin
                    PREADY  <= 1; // Indicate error completion
                    PSLVERR <= 1; // Indicate error condition
                end
            endcase
        end
    end
endmodule
