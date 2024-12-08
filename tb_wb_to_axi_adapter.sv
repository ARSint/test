module tb_wb_to_axi_adapter;

    // Testbench signals
    reg wb_clk_i;
    reg wb_rst_i;
    reg [31:0] wb_adr_i;
    reg [31:0] wb_dat_i;
    wire [31:0] wb_dat_o;
    reg wb_we_i;
    reg wb_stb_i;
    reg wb_cyc_i;
    reg [3:0] wb_sel_i;
    reg wb_ack_o; // Register to hold ack value
    wire wb_err_o;

    // AXI signals
    wire m_axi_awvalid;
    reg m_axi_awready;
    wire [31:0] m_axi_awaddr;
    wire [7:0] m_axi_awlen;
    wire m_axi_wvalid;
    reg m_axi_wready;
    wire [31:0] m_axi_wdata;
    wire [3:0] m_axi_wstrb;
    wire m_axi_wlast;
    reg m_axi_bvalid;
    wire m_axi_bready;
    wire m_axi_arvalid;
    reg m_axi_arready;
    wire [31:0] m_axi_araddr;
    wire [7:0] m_axi_arlen;
    reg m_axi_rvalid;
    wire m_axi_rready;
    reg [31:0] m_axi_rdata;
    reg [1:0] m_axi_rresp;
    reg [1:0] m_axi_bresp;

    // Memory model for AXI slave
    reg [31:0] axi_memory [0:255];

    // Instantiate DUT
    wb_to_axi_adapter dut (
        .wb_clk_i(wb_clk_i),
        .wb_rst_i(wb_rst_i),
        .wb_adr_i(wb_adr_i),
        .wb_dat_i(wb_dat_i),
        .wb_dat_o(wb_dat_o),
        .wb_we_i(wb_we_i),
        .wb_stb_i(wb_stb_i),
        .wb_cyc_i(wb_cyc_i),
        .wb_sel_i(wb_sel_i),
        .wb_ack_o(wb_ack_o), // Assign to register to hold value
        .wb_err_o(wb_err_o),
        .m_axi_awvalid(m_axi_awvalid),
        .m_axi_awready(m_axi_awready),
        .m_axi_awaddr(m_axi_awaddr),
        .m_axi_awlen(m_axi_awlen),
        .m_axi_wvalid(m_axi_wvalid),
        .m_axi_wready(m_axi_wready),
        .m_axi_wdata(m_axi_wdata),
        .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wlast(m_axi_wlast),
        .m_axi_bvalid(m_axi_bvalid),
        .m_axi_bready(m_axi_bready),
        .m_axi_arvalid(m_axi_arvalid),
        .m_axi_arready(m_axi_arready),
        .m_axi_araddr(m_axi_araddr),
        .m_axi_arlen(m_axi_arlen),
        .m_axi_rvalid(m_axi_rvalid),
        .m_axi_rready(m_axi_rready),
        .m_axi_rdata(m_axi_rdata),
        .m_axi_rresp(m_axi_rresp),
        .m_axi_bresp(m_axi_bresp)
    );

    // Clock generation
    always #5 wb_clk_i = ~wb_clk_i;

    // AXI Slave model
    always @(posedge wb_clk_i or posedge wb_rst_i) begin
        if (wb_rst_i) begin
            m_axi_awready <= 0;
            m_axi_wready <= 0;
            m_axi_bvalid <= 0;
            m_axi_arready <= 0;
            m_axi_rvalid <= 0;
        end else begin
            // Write Address Phase
            if (m_axi_awvalid && !m_axi_awready) begin
                m_axi_awready <= 1;
            end else begin
                m_axi_awready <= 0;
            end

            // Write Data Phase
            if (m_axi_wvalid && !m_axi_wready) begin
                axi_memory[m_axi_awaddr[7:0]] <= m_axi_wdata; // Write data to memory
                m_axi_wready <= 1;
            end else begin
                m_axi_wready <= 0;
            end

            // Write Response Phase
            if (m_axi_wlast && m_axi_wready && !m_axi_bvalid) begin
                m_axi_bvalid <= 1;
                m_axi_bresp <= 2'b00; // OKAY response
            end else if (m_axi_bvalid && m_axi_bready) begin
                m_axi_bvalid <= 0;
            end

            // Read Address Phase
            if (m_axi_arvalid && !m_axi_arready) begin
                m_axi_arready <= 1;
            end else begin
                m_axi_arready <= 0;
            end

            // Read Data Phase
            if (m_axi_arready && m_axi_arvalid && !m_axi_rvalid) begin
                m_axi_rvalid <= 1;
                m_axi_rdata <= axi_memory[m_axi_araddr[7:0]]; // Read data from memory
                m_axi_rresp <= 2'b00; // OKAY response
            end else if (m_axi_rvalid && m_axi_rready) begin
                m_axi_rvalid <= 0;
            end
        end
    end

    // Testbench procedure
    initial begin
        integer i;

        // Initialize
        wb_clk_i = 0;
        wb_rst_i = 1;
        wb_adr_i = 0;
        wb_dat_i = 0;
        wb_we_i = 0;
        wb_stb_i = 0;
        wb_cyc_i = 0;
        wb_sel_i = 4'b1111;
        wb_ack_o = 0; // Initialize wb_ack_o to 0

        #10 wb_rst_i = 0;

        // Single Write Transaction
        $display("Starting Single Write Transaction...");
        wb_adr_i = 32'h10;
        wb_dat_i = 32'hDEADBEEF;
        wb_we_i = 1;
        wb_stb_i = 1;
        wb_cyc_i = 1;

        // Wait for wb_ack_o to be asserted, and hold it
        wait(wb_ack_o == 1);
        @(posedge wb_clk_i);
        wb_stb_i = 0;
        wb_cyc_i = 0;
        wb_ack_o = 0; // Deassert ack
        $display("Single Write Completed.");

        // Single Read Transaction
        $display("Starting Single Read Transaction...");
        wb_adr_i = 32'h10;
        wb_we_i = 0;
        wb_stb_i = 1;
        wb_cyc_i = 1;

        // Wait for wb_ack_o to be asserted, and hold it
        wait(wb_ack_o == 1);
        @(posedge wb_clk_i);
        if (wb_dat_o == 32'hDEADBEEF) begin
            $display("Read Data Matches Expected Value: 0x%08X", wb_dat_o);
        end else begin
            $display("ERROR: Read Data Mismatch! Received: 0x%08X", wb_dat_o);
        end
        wb_stb_i = 0;
        wb_cyc_i = 0;
        wb_ack_o = 0; // Deassert ack

        // Block Write Transaction
        $display("Starting Block Write Transaction...");
        for (i = 0; i < 4; i = i + 1) begin
            wb_adr_i = 32'h20 + i * 4;
            wb_dat_i = 32'hA5A5A5A5 + i;
            wb_we_i = 1;
            wb_stb_i = 1;
            wb_cyc_i = 1;

            // Wait for wb_ack_o to be asserted, and hold it
            wait(wb_ack_o == 1);
            @(posedge wb_clk_i);
            wb_stb_i = 0;
            wb_cyc_i = 0;
            wb_ack_o = 0; // Deassert ack after transaction
        end
        $display("Block Write Completed.");
    end
endmodule

