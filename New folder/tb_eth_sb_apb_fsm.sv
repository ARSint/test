module tb_eth_sb_apb_fsm;

    // Parameters
    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;

    // DUT Signals
    logic i_clk, i_reset_n;
    logic i_eth_sb_psel, i_eth_sb_penable, i_eth_sb_pwrite;
    logic [ADDR_WIDTH-1:0] i_eth_sb_paddr;
    logic [DATA_WIDTH-1:0] i_eth_sb_pwdata;
    logic [3:0] i_eth_sb_pstrb;
    logic [DATA_WIDTH-1:0] i_eth_sb_ctrl_rdata;
    logic i_eth_sb_ctrl_slverr, i_eth_sb_ctrl_inv_addr;
    logic wdata_resp, rdata_resp, fuse_enable, fifo_full, fifo_empty;

    logic o_eth_sb_pready, o_eth_sb_pslverr;
    logic [DATA_WIDTH-1:0] o_eth_sb_prdata, o_eth_sb_ctrl_wdata;
    logic [ADDR_WIDTH-1:0] o_eth_sb_ctrl_addr;
    logic o_eth_sb_ctrl_wr_en, o_eth_sb_ctrl_rd_en;
    logic [3:0] o_eth_sb_ctrl_pstrb;

    // Instantiate DUT
    eth_sb_apb_fsm #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .i_clk(i_clk), 
		.i_reset_n(i_reset_n), 
		.i_eth_sb_psel(i_eth_sb_psel),
        .i_eth_sb_penable(i_eth_sb_penable), 
		.i_eth_sb_pwrite(i_eth_sb_pwrite),
        .i_eth_sb_paddr(i_eth_sb_paddr), 
		.i_eth_sb_pwdata(i_eth_sb_pwdata),
        .i_eth_sb_pstrb(i_eth_sb_pstrb), 
		.o_eth_sb_pready(o_eth_sb_pready),
        .o_eth_sb_pslverr(o_eth_sb_pslverr), 
		.o_eth_sb_prdata(o_eth_sb_prdata),
        .o_eth_sb_ctrl_wdata(o_eth_sb_ctrl_wdata), 
		.o_eth_sb_ctrl_addr(o_eth_sb_ctrl_addr),
        .o_eth_sb_ctrl_wr_en(o_eth_sb_ctrl_wr_en), 
		.o_eth_sb_ctrl_rd_en(o_eth_sb_ctrl_rd_en),
        .o_eth_sb_ctrl_pstrb(o_eth_sb_ctrl_pstrb), 
		.i_eth_sb_ctrl_rdata(i_eth_sb_ctrl_rdata),
        .i_eth_sb_ctrl_slverr(i_eth_sb_ctrl_slverr), 
		.i_eth_sb_ctrl_inv_addr(i_eth_sb_ctrl_inv_addr),
        .wdata_resp(wdata_resp), 
		.rdata_resp(rdata_resp), 
		.fuse_enable(fuse_enable),
        .fifo_full(fifo_full), 
		.fifo_empty(fifo_empty)
    );

    // Clock Generation
    always #5 i_clk = ~i_clk;

    // Test Sequence
    initial begin
        // Initialize signals
        i_clk = 0;
        i_reset_n = 0;
        i_eth_sb_psel = 0;
        i_eth_sb_penable = 0;
        i_eth_sb_pwrite = 0;
        i_eth_sb_paddr = 0;
        i_eth_sb_pwdata = 0;
        i_eth_sb_pstrb = 0;
        i_eth_sb_ctrl_rdata = 0;
        i_eth_sb_ctrl_slverr = 0;
        i_eth_sb_ctrl_inv_addr = 0;
        wdata_resp = 0;
        rdata_resp = 0;
        fuse_enable = 1;
        fifo_full = 0;
        fifo_empty = 0;

        // Reset sequence
        #10 i_reset_n = 1;

        // Test Write Transaction
        #10 i_eth_sb_psel = 1; i_eth_sb_penable = 1; i_eth_sb_pwrite = 1;
        i_eth_sb_paddr = 32'hAABBCCDD; i_eth_sb_pwdata = 32'h12345678;
        i_eth_sb_pstrb = 4'hF;

        #10 assert(o_eth_sb_ctrl_wr_en == 1) else $error("Write enable failed!");

        // Test Read Transaction
        #20 i_eth_sb_pwrite = 0; i_eth_sb_ctrl_rdata = 32'h87654321;

        #10 assert(o_eth_sb_prdata == 32'h87654321) else $error("Read data mismatch!");

        // End of Test
        #50 $finish;
    end

endmodule
