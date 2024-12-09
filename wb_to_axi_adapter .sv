module wb_to_axi_adapter #(
    parameter integer ADDR_WIDTH = 32,
    parameter integer DATA_WIDTH = 32,
    parameter integer SEL_WIDTH  = 4
)(
    // Wishbone Interface
    input wire                        wb_clk_i,
    input wire                        wb_rst_i,
    input wire [ADDR_WIDTH-1:0]       wb_adr_i,
    input wire [DATA_WIDTH-1:0]       wb_dat_i,
    output reg [DATA_WIDTH-1:0]       wb_dat_o,
    input wire                        wb_we_i,
    input wire                        wb_stb_i,
    input wire                        wb_cyc_i,
    input wire [SEL_WIDTH-1:0]        wb_sel_i,
			 
    output reg                        wb_ack_o,
    output reg                        wb_err_o,

    // AXI Master Interface
    output reg                        axi_awvalid_o,
    input wire                        axi_awready_i,
    output reg [ADDR_WIDTH-1:0]       axi_awaddr_o,
    output reg [7:0]                  axi_awlen_o,
    output reg                        axi_wvalid_o,
    input wire                        axi_wready_i,
    output reg [DATA_WIDTH-1:0]       axi_wdata_o,
    output reg [SEL_WIDTH-1:0]        axi_wstrb_o,
    output reg                        axi_wlast_o,
    input wire                        axi_bvalid_i,
    output reg                        axi_bready_o,
    output reg                        axi_arvalid_o,
    input wire                        axi_arready_i,
    output reg [ADDR_WIDTH-1:0]       axi_araddr_o,
    output reg [7:0]                  axi_arlen_o,
    input wire                        axi_rvalid_i,
    output reg                        axi_rready_o,
    input wire [DATA_WIDTH-1:0]       axi_rdata_i,
    input wire [1:0]                  axi_rresp_i,
    input wire [1:0]                  axi_bresp_i
);

    // FSM State Definitions
    typedef enum logic [2:0] {
        STATE_IDLE        = 3'b000,
        STATE_WRITE_ADDR  = 3'b001,
        STATE_WRITE_DATA  = 3'b010,
        STATE_WRITE_RESP  = 3'b011,
        STATE_READ_ADDR   = 3'b100,
        STATE_READ_DATA   = 3'b101,
        STATE_ERROR       = 3'b110
    } fsm_state_t;

    fsm_state_t current_state, next_state;

    // Burst Counters and Length
    reg [7:0] burst_count;
    reg [7:0] calculated_burst_len;

    // Sequential State Transition
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i) begin
            current_state <= STATE_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // FSM Combinational Logic
    always @(*) begin
        // Default Outputs
        next_state         = current_state;
        wb_ack_o           = 1'b0;
        wb_err_o           = 1'b0;
        axi_awvalid_o      = 1'b0;
        axi_wvalid_o       = 1'b0;
        axi_wlast_o        = 1'b0;
        axi_bready_o       = 1'b0;
        axi_arvalid_o      = 1'b0;
        axi_rready_o       = 1'b0;

        case (current_state)
            STATE_IDLE: begin
                if (wb_stb_i && wb_cyc_i) begin
                    if (wb_we_i) begin
                        next_state = STATE_WRITE_ADDR;
                    end else begin
                        next_state = STATE_READ_ADDR;
                    end
                end
            end

            STATE_WRITE_ADDR: begin
                axi_awvalid_o = 1'b1;
                axi_awaddr_o  = wb_adr_i;
                axi_awlen_o   = calculated_burst_len - 1;
                if (axi_awready_i) begin
                    next_state = STATE_WRITE_DATA;
                end
            end

            STATE_WRITE_DATA: begin
                axi_wvalid_o = 1'b1;
                axi_wdata_o  = wb_dat_i;
                axi_wstrb_o  = wb_sel_i;
                if (burst_count == calculated_burst_len - 1) begin
                    axi_wlast_o = 1'b1;
                end
                if (axi_wready_i) begin
                    burst_count = burst_count + 1;
                    wb_ack_o = 1'b1; // Acknowledge Wishbone write
                    if (burst_count == calculated_burst_len) begin
                        next_state = STATE_WRITE_RESP;
                    end
                end
            end

            STATE_WRITE_RESP: begin
                axi_bready_o = 1'b1;
                if (axi_bvalid_i) begin
                    if (axi_bresp_i == 2'b00) begin
                        wb_ack_o = 1'b1; // Final Wishbone acknowledge
                    end else begin
                        wb_err_o = 1'b1;
                    end
                    next_state = STATE_IDLE;
                end
            end

            STATE_READ_ADDR: begin
                axi_arvalid_o = 1'b1;
                axi_araddr_o  = wb_adr_i;
                axi_arlen_o   = calculated_burst_len - 1;
                if (axi_arready_i) begin
                    next_state = STATE_READ_DATA;
                end
            end

            STATE_READ_DATA: begin
                axi_rready_o = 1'b1;
                if (axi_rvalid_i) begin
                    wb_dat_o    = axi_rdata_i;
                    burst_count = burst_count + 1;
                    wb_ack_o    = 1'b1; // Acknowledge Wishbone read
                    if (burst_count == calculated_burst_len) begin
                        next_state = STATE_IDLE;
                    end
                end
                if (axi_rresp_i != 2'b00) begin
                    wb_err_o = 1'b1;
                    next_state = STATE_ERROR;
                end
            end

            STATE_ERROR: begin
                wb_err_o = 1'b1;
                next_state = STATE_IDLE;
            end
        endcase
    end

    // Burst Counter
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i) begin
            burst_count <= 8'd0;
        end else if (current_state == STATE_WRITE_DATA || current_state == STATE_READ_DATA) begin
            burst_count <= burst_count + 1;
        end else begin
            burst_count <= 8'd0;
        end
    end

    // Burst Length Calculation
    always @(*) begin
        calculated_burst_len = 1;
					  

																	 
																							  
        if (wb_sel_i[0]) calculated_burst_len = calculated_burst_len + 1;
        if (wb_sel_i[1]) calculated_burst_len = calculated_burst_len + 1;
        if (wb_sel_i[2]) calculated_burst_len = calculated_burst_len + 1;
        if (wb_sel_i[3]) calculated_burst_len = calculated_burst_len + 1;

																			 
        if (calculated_burst_len > 8) calculated_burst_len = 8;
    end

endmodule
