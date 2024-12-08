module wb_to_axi_adapter #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter SEL_WIDTH  = 4
)(
    // Wishbone Signals
    input                   wb_clk_i,
    input                   wb_rst_i,
    input [ADDR_WIDTH-1:0]  wb_adr_i,
    input [DATA_WIDTH-1:0]  wb_dat_i,
    output reg [DATA_WIDTH-1:0] wb_dat_o,
    input                   wb_we_i,
    input                   wb_stb_i,
    input                   wb_cyc_i,
    input [SEL_WIDTH-1:0]   wb_sel_i,
										   
    output reg              wb_ack_o,
    output reg              wb_err_o,

    // AXI Signals
    output reg              m_axi_awvalid,
    input                   m_axi_awready,
    output reg [ADDR_WIDTH-1:0] m_axi_awaddr,
    output reg [7:0]        m_axi_awlen,
    output reg              m_axi_wvalid,
    input                   m_axi_wready,
    output reg [DATA_WIDTH-1:0] m_axi_wdata,
    output reg [SEL_WIDTH-1:0] m_axi_wstrb,
    output reg              m_axi_wlast,
    input                   m_axi_bvalid,
    output reg              m_axi_bready,
    output reg              m_axi_arvalid,
    input                   m_axi_arready,
    output reg [ADDR_WIDTH-1:0] m_axi_araddr,
    output reg [7:0]        m_axi_arlen,
    input                   m_axi_rvalid,
    output reg              m_axi_rready,
    input [DATA_WIDTH-1:0]  m_axi_rdata,
    input [1:0]             m_axi_rresp,
    input [1:0]             m_axi_bresp
);

    // FSM States
    typedef enum logic [2:0] {
        IDLE = 3'b000,
        WRITE_ADDR = 3'b001,
        WRITE_DATA = 3'b010,
        WRITE_RESP = 3'b011,
        READ_ADDR = 3'b100,
        READ_DATA = 3'b101,
        ERROR = 3'b110
    } state_t;

    state_t current_state, next_state;

    // Burst counter
    reg [7:0] burst_count;
    reg [7:0] burst_len;  // Calculated burst length

    // FSM State Transition Logic
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end

always @(*) begin
        // Default values
        next_state = current_state;
        wb_ack_o = 0;
        wb_err_o = 0;
        m_axi_awvalid = 0;
        m_axi_wvalid = 0;
        m_axi_wlast = 0;
        m_axi_bready = 0;
        m_axi_arvalid = 0;
        m_axi_rready = 0;

        case (current_state)
            IDLE: begin
                if (wb_stb_i && wb_cyc_i) begin
                    if (wb_we_i) begin
                        next_state = WRITE_ADDR;
                    end else begin
                        next_state = READ_ADDR;
                    end
                end
            end

            WRITE_ADDR: begin
                m_axi_awvalid = 1;
                m_axi_awaddr = wb_adr_i;
                m_axi_awlen = burst_len - 1;
                if (m_axi_awready) begin
                    next_state = WRITE_DATA;
                end
            end

            WRITE_DATA: begin
                m_axi_wvalid = 1;
                m_axi_wdata = wb_dat_i;
                m_axi_wstrb = wb_sel_i;
                if (burst_count == burst_len - 1) begin
                    m_axi_wlast = 1;
                end
                if (m_axi_wready) begin
                    burst_count = burst_count + 1;
                    wb_ack_o = 1; // Acknowledge when AXI slave is ready
                    if (burst_count == burst_len) begin
                        next_state = WRITE_RESP;
                    end
                end
            end

            WRITE_RESP: begin
                m_axi_bready = 1;
                if (m_axi_bvalid) begin
                    if (m_axi_bresp == 2'b00) begin
                        wb_ack_o = 1; // Final acknowledge for write
                    end else begin
                        wb_err_o = 1;
                    end
                    next_state = IDLE;
                end
            end

            READ_ADDR: begin
                m_axi_arvalid = 1;
                m_axi_araddr = wb_adr_i;
                m_axi_arlen = burst_len - 1;
                if (m_axi_arready) begin
                    next_state = READ_DATA;
                end
            end

            READ_DATA: begin
                m_axi_rready = 1;
                if (m_axi_rvalid) begin
                    wb_dat_o = m_axi_rdata;
                    burst_count = burst_count + 1;
                    wb_ack_o = 1; // Acknowledge when AXI slave provides valid data
                    if (burst_count == burst_len) begin
                        next_state = IDLE;
                    end
                end
                if (m_axi_rresp != 2'b00) begin
                    wb_err_o = 1;
                    next_state = ERROR;
                end
            end

            ERROR: begin
                wb_err_o = 1;
                next_state = IDLE;
            end
        endcase
    end

    // Burst Counter Logic
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i)
            burst_count <= 0;
        else if (current_state == WRITE_DATA || current_state == READ_DATA)
            burst_count <= burst_count + 1;
        else
            burst_count <= 0;
    end

    // Calculate burst length based on Wishbone select signals
    always @(*) begin
        // Default burst length is 1 if no data is selected
        burst_len = 1;

        // Calculate burst length based on wb_sel_i (Wishbone select)
        // For simplicity, if the select width is 4, each select bit represents 1 byte of data
        if (wb_sel_i[0]) burst_len = burst_len + 1;
        if (wb_sel_i[1]) burst_len = burst_len + 1;
        if (wb_sel_i[2]) burst_len = burst_len + 1;
        if (wb_sel_i[3]) burst_len = burst_len + 1;

        // Ensure burst length doesn't exceed maximum allowed (8 for example)
        if (burst_len > 8) burst_len = 8;
    end

endmodule
