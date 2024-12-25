module tb_eth_sb_axi_fsm;

  // Parameters
  parameter ADDR_WIDTH = 24;
  parameter DATA_WIDTH = 32;

  // Testbench Signals
  logic                   i_clk;
  logic                   i_reset_n;
  logic                   i_fuse_enable;
  logic                   i_fifo_full; 
  logic                   i_fifo_empty;
  logic                   i_dec_flash_en;
  logic                   i_dec_axi_en;
  logic                   i_dec_loc_mem_map;
  logic [3:0]             i_core_wstrb;
  logic [ADDR_WIDTH-1:0]  i_core_addr;
  logic                   i_core_valid;
  logic [DATA_WIDTH-1:0]  i_core_wdata;
  logic [2:0]             i_axi_sresp;
  logic [DATA_WIDTH-1:0]  i_axi_sdata;
  logic                   i_axi_svalid;
  logic                   i_axi_saccept;

  logic [DATA_WIDTH-1:0]  o_core_rdata;
  logic [DATA_WIDTH-1:0]  o_sram_wr_data;
  logic                   o_core_ready;
  logic                   o_axi_mread;
  logic                   o_axi_mwrite;
  logic [ADDR_WIDTH-1:0]  o_axi_maddr;
  logic [DATA_WIDTH-1:0]  o_axi_mdata;
  logic                   o_axi_mready;
  logic [3:0]             o_axi_mwstrb;
  logic                   o_axi_slverr;
  logic                   o_axi_decoderr;

  // Clock generation
  always #5 i_clk = ~i_clk;

  // DUT Instantiation
  eth_sb_axi_fsm #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) dut (
    .i_clk(i_clk),
    .i_reset_n(i_reset_n),
    .i_fuse_enable(i_fuse_enable),
    .i_fifo_full(i_fifo_full),
    .i_fifo_empty(i_fifo_empty),
    .i_dec_flash_en(i_dec_flash_en),
    .i_dec_axi_en(i_dec_axi_en),
    .i_dec_loc_mem_map(i_dec_loc_mem_map),
    .i_core_wstrb(i_core_wstrb),
    .i_core_addr(i_core_addr),
    .i_core_valid(i_core_valid),
    .i_core_wdata(i_core_wdata),
    .i_axi_sresp(i_axi_sresp),
    .i_axi_sdata(i_axi_sdata),
    .i_axi_svalid(i_axi_svalid),
    .i_axi_saccept(i_axi_saccept),
    .o_core_rdata(o_core_rdata),
    .o_sram_wr_data(o_sram_wr_data),
    .o_core_ready(o_core_ready),
    .o_axi_mread(o_axi_mread),
    .o_axi_mwrite(o_axi_mwrite),
    .o_axi_maddr(o_axi_maddr),
    .o_axi_mdata(o_axi_mdata),
    .o_axi_mready(o_axi_mready),
    .o_axi_mwstrb(o_axi_mwstrb),
    .o_axi_slverr(o_axi_slverr),
    .o_axi_decoderr(o_axi_decoderr)
  );

  // Task to Reset DUT
  task reset_dut();
    begin
      i_reset_n = 1'b0;
      repeat(2) @(posedge i_clk);
      i_reset_n = 1'b1;
    end
  endtask

  // Test Vectors
  initial begin
    // Initialize signals
    i_clk = 0;
    i_reset_n = 1;
    i_fuse_enable = 0;
    i_fifo_full = 0;
    i_fifo_empty = 0;
    i_dec_flash_en = 0;
    i_dec_axi_en = 0;
    i_dec_loc_mem_map = 0;
    i_core_wstrb = 4'b0000;
    i_core_addr = {ADDR_WIDTH{1'b0}};
    i_core_valid = 0;
    i_core_wdata = {DATA_WIDTH{1'b0}};
    i_axi_sresp = 3'b000;
    i_axi_sdata = {DATA_WIDTH{1'b0}};
    i_axi_svalid = 0;
    i_axi_saccept = 0;

    // Apply Reset
    reset_dut();

    // Test Case 1: AXI Read Transaction
    @(posedge i_clk);
    i_core_valid = 1;
    i_core_addr = 24'h00_1234;
    i_core_wstrb = 4'b0000; // Read request
    @(posedge i_clk);
    i_axi_saccept = 1;
    @(posedge i_clk);
    i_axi_svalid = 1;
    i_axi_sresp = 3'b000; // OK response
    i_axi_sdata = 32'hDEAD_BEEF;
    @(posedge i_clk);
    i_axi_svalid = 0;
    i_core_valid = 0;

    // Check Results
    assert(o_core_rdata == 32'hDEAD_BEEF) else $fatal("Test Case 1 Failed: Incorrect read data");
    assert(o_core_ready == 1) else $fatal("Test Case 1 Failed: Core not ready after read");

    // Test Case 2: AXI Write Transaction
    @(posedge i_clk);
    i_core_valid = 1;
    i_core_addr = 24'h00_5678;
    i_core_wstrb = 4'b1111; // Write request
    i_core_wdata = 32'hCAFEBABE;
    @(posedge i_clk);
    i_axi_saccept = 1;
    @(posedge i_clk);
    i_axi_svalid = 1;
    i_axi_sresp = 3'b000; // OK response
    @(posedge i_clk);
    i_axi_svalid = 0;
    i_core_valid = 0;

    // Check Results
    assert(o_axi_mwrite == 1) else $fatal("Test Case 2 Failed: Write signal not asserted");
    assert(o_axi_mdata == 32'hCAFEBABE) else $fatal("Test Case 2 Failed: Incorrect write data");

    // Test Case 3: Error Response
    @(posedge i_clk);
    i_core_valid = 1;
    i_core_addr = 24'h00_ABCD;
    i_core_wstrb = 4'b0000; // Read request
    @(posedge i_clk);
    i_axi_saccept = 1;
    @(posedge i_clk);
    i_axi_svalid = 1;
    i_axi_sresp = 3'b100; // SLVERR response
    @(posedge i_clk);
    i_axi_svalid = 0;
    i_core_valid = 0;

    // Check Results
    assert(o_axi_slverr == 1) else $fatal("Test Case 3 Failed: Error not flagged");

    // End Simulation
    $display("All Test Cases Passed!");
    $finish;
  end
endmodule
