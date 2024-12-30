// Top-level module to instantiate and connect `eth_sb_axi_fsm` and `eth_sb_apb_fsm`

module eth_sb_fsm_top #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    // Clock and Reset
    input  logic        clk,
    input  logic        reset_n,

    // Ethernet IO GPIO
    inout  logic        ethio_gpio,

    // Interrupts
    output logic        Int_irq12,

    // SB Controls
    input  logic        Sb_otp_lock,
    input  logic        Sb_lock_ovrd,
    input  logic        Sb_perm_lock_otp,

    // APB Interface
    input  logic        i_pclk,
    input  logic        i_preset_n,
    input  logic        i_psel,
    input  logic        i_penable,
    input  logic [31:0] i_paddr,
    input  logic        i_pwrite,
    input  logic [3:0]  i_pstrb,
    input  logic [31:0] i_pwdata,
    output logic        o_pready,
    output logic [31:0] o_prdata,
    output logic        o_pslverr,

    // AXI Master response Interface
    input  logic [2:0]  i_axi_sresp,
    input  logic [31:0] i_axi_sdata,
    input  logic        i_axi_svalid,
    // AXI Master Interface
	input logic         i_axi_saccept,
    output logic        o_axi_ready,
    output logic        o_axi_mread,
    output logic [23:0] o_axi_maddr,
    output logic        o_axi_mwrite,
    output logic [31:0] o_axi_mdata,
    output logic [3:0]  o_axi_mwstrb
);

// Internal signals
logic [DATA_WIDTH-1:0] apb_ctrl_wdata;
logic [ADDR_WIDTH-1:0] apb_ctrl_addr;
logic                  apb_ctrl_wr_en;
logic                  apb_ctrl_rd_en;
logic [3:0]            apb_ctrl_pstrb;
logic [DATA_WIDTH-1:0] apb_ctrl_rdata;
logic                  apb_ctrl_slverr;
logic                  apb_ctrl_inv_addr;
logic                  wdata_resp;
logic                  rdata_resp;
logic                  fifo_full;
logic                  fifo_empty;
 // FIFO signals
logic                  write_fifo_empty;
logic                  read_fifo_full;
logic                  write_fifo_read;
logic                  read_fifo_write;
logic [DATA_WIDTH-1:0] write_fifo_data;
logic [DATA_WIDTH-1:0] read_fifo_data;

    // Address and length
logic [7:0]             byte_length;
logic [ADDR_WIDTH-1:0]  address;
logic fuse_enable;
logic  [3:0]            core_wstrb;
logic  [3:0]            rw;
logic        o_axi_slverr;  
logic        o_axi_decoderr;

assign fuse_enable = Sb_otp_lock Sb_lock_ovrd Sb_perm_lock_otp
// Instantiate AXI FSM
eth_sb_axi_fsm #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
) axi_fsm (
    .i_clk(clk),
    .i_reset_n(reset_n),
    .i_fuse_enable(fuse_enable),
    .i_core_wstrb(core_wstrb),
    .i_rw(rw),
    .i_axi_sresp(i_axi_sresp),
    .i_axi_sdata(i_axi_sdata),
    .i_axi_svalid(i_axi_svalid),
    .i_axi_saccept(i_axi_saccept),
    .o_axi_mread(o_axi_mread),
    .o_axi_mwrite(o_axi_mwrite),
    .o_axi_maddr(o_axi_maddr),
    .o_axi_mdata(o_axi_mdata),
    .o_axi_mready(o_axi_mready),
    .o_axi_mwstrb(o_axi_mwstrb),
    .o_axi_slverr(o_axi_slverr),
    .o_axi_decoderr(o_axi_decoderr),
    .write_fifo_empty(write_fifo_empty),
    .write_fifo_read(write_fifo_read),
    .write_fifo_data(write_fifo_data),
    .read_fifo_full(read_fifo_full),
    .read_fifo_write(read_fifo_write),
    .read_fifo_data(read_fifo_data),
    .byte_length(byte_length),
    .address(address)
);

// Instantiate APB FSM
eth_sb_apb_fsm #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
) apb_fsm (
    .i_clk(clk),
    .i_reset_n(reset_n),
    .i_eth_sb_psel(i_psel),
    .i_eth_sb_penable(i_penable),
    .i_eth_sb_pwrite(i_pwrite),
    .i_eth_sb_paddr(i_paddr),
    .i_eth_sb_pwdata(i_pwdata),
    .i_eth_sb_pstrb(i_pstrb),
    .o_eth_sb_pready(o_pready),
    .o_eth_sb_pslverr(o_pslverr),
    .o_eth_sb_prdata(o_prdata),
    .o_eth_sb_ctrl_wdata(apb_ctrl_wdata),
    .o_eth_sb_ctrl_addr(apb_ctrl_addr),
    .o_eth_sb_ctrl_wr_en(apb_ctrl_wr_en),
    .o_eth_sb_ctrl_rd_en(apb_ctrl_rd_en),
    .o_eth_sb_ctrl_pstrb(apb_ctrl_pstrb),
    .i_eth_sb_ctrl_rdata(apb_ctrl_rdata),
    .i_eth_sb_ctrl_slverr(apb_ctrl_slverr),
    .i_eth_sb_ctrl_inv_addr(apb_ctrl_inv_addr),
    .wdata_resp(wdata_resp),
    .rdata_resp(rdata_resp),
    .fuse_enable(fuse_enable),
    .fifo_full(fifo_full),
    .fifo_empty(fifo_empty)
);

endmodule
