module eth_top (
    // Clock and Reset
    input logic          clk,             // System clock
    input logic          reset,           // Reset signal

    // RX Interface
    input logic          MRxClk,          // RX clock
    input logic  [7:0]   MRxD,            // RX data
    input logic          MRxDV,           // RX data valid

    // TX Interface
    input logic          MTxClk,          // TX clock
    output logic  [7:0]  MTxD,            // TX data
    output logic         MTxEn,           // TX enable
    output logic         MTxErr,          // TX error

    // MAC Configuration
    input logic  [47:0]  MAC,             // MAC address for filtering
    input logic  [15:0]  MaxFL,           // Maximum frame length
    input logic          HugEn,           // Jumbo frame enable
    input logic          DlyCrcEn,        // CRC delay enable
    input logic          r_IFG,           // Inter-frame gap

    // AXI-Lite Master Interface
    output reg  [31:0]  AWADDR,
    output reg          AWVALID,
    input  wire         AWREADY,
    output reg  [31:0]  WDATA,
    output reg          WVALID,
    input  wire         WREADY,
    input  wire         BVALID,
    output reg          BREADY,
    output reg  [31:0]  ARADDR,
    output reg          ARVALID,
    input  wire         ARREADY,
    input  wire [31:0]  RDATA,
    input  wire         RVALID,
    output reg          RREADY
);

    // Internal Signals
    logic  [47:0] dst_mac_reg, src_mac_reg;
    logic  [15:0] length_reg;
    logic  [31:0] first_32bits;
    logic  [23:0] address;
    logic  [3:0]  opcode;
    logic  [15:0] ByteCnt;
    logic         RxValid;

    // FIFOs
    logic         rxfifo_wr_en, rxfifo_rd_en, rxfifo_empty, rxfifo_full;
    logic  [31:0] rxfifo_data_in, rxfifo_data_out;

    logic         hfifo_wr_en, hfifo_rd_en, hfifo_empty, hfifo_full;
    logic  [43:0] hfifo_data_in, hfifo_data_out;

    logic         txfifo_wr_en, txfifo_rd_en, txfifo_empty, txfifo_full;
    logic  [31:0] txfifo_data_in, txfifo_data_out;
 logic         write_error;
    logic          read_error;


    // Instantiate eth_rxethmacdecoder
    eth_rxethmacdecoder eth_decoder (
        .MRxClk(MRxClk),
        .Reset(reset),
        .MRxDV(MRxDV),
        .MRxD(MRxD),
        .MAC(MAC),
        .MaxFL(MaxFL),
        .r_IFG(r_IFG),
        .HugEn(HugEn),
        .DlyCrcEn(DlyCrcEn),
        .RxStartFrm(MRxDV),   // Start-of-frame derived from MRxDV
        .RxEndFrm(!MRxDV),    // End-of-frame derived from !MRxDV
        .CrcError(1'b0),      // Stubbed CRC Error (customize as needed)
        .AddressMiss(1'b0),   // Stubbed Address Miss (customize as needed)

        .dst_mac_reg(dst_mac_reg),
        .src_mac_reg(src_mac_reg),
        .length_reg(length_reg),
        .RxValid(RxValid),
        .first_32bits(first_32bits),
        .address(address),
        .opcode(opcode),
        .ByteCnt(ByteCnt),
        .rxfifo_wr_en(rxfifo_wr_en),
        .rxfifo_data(rxfifo_data_in),
        .hfifo_wr_en(hfifo_wr_en),
        .hfifo_data(hfifo_data_in)
    );

    // Instantiate RX FIFO fo mac
    fifo #(32, 128) rx_fifo (
        .clk(clk),
        .reset(reset),
        .wr_en(rxfifo_wr_en),
        .rd_en(rxfifo_rd_en),
        .data_in(rxfifo_data_in),
        .data_out(rxfifo_data_out),
        .empty(rxfifo_empty),
        .full(rxfifo_full)
    );

    // Instantiate Header FIFO for mac
    fifo #(44, 16) header_fifo (
        .clk(clk),
        .reset(reset),
        .wr_en(hfifo_wr_en),
        .rd_en(hfifo_wr_en),
        .data_in(hfifo_data_in),
        .data_out(hfifo_data_out),
        .empty(hfifo_empty),
        .full(hfifo_full)
    );

    // Instantiate TX FIFO
     fifo #(32, 128) tx_fifo (
        .clk(clk),
        .reset(reset),
        .wr_en(txfifo_wr_en),
        .rd_en(txfifo_rd_en),
        .data_in(txfifo_data_in),
        .data_out(txfifo_data_out),
        .empty(txfifo_empty),
        .full(txfifo_full)
    );

/*     // FIFO Glue Logic
    fifo_glue_logic glue_logic (
        .clk(clk),
        .reset(reset),
        .header_fifo_empty(hfifo_empty),
        .rxfifo_empty(rxfifo_empty),
        .txfifo_full(),
        .header_fifo_data(hfifo_data_out[31:0]),
        .rxfifo_data(rxfifo_data_out),
        .axi_read_data(axi_read_data),
        .header_fifo_rd_en(hfifo_rd_en),
        .rxfifo_rd_en(),
        .txfifo_wr_en(),
        .txfifo_data(txfifo_data_in)
    ); */

    // AXI Lite FSM
    axi_lite_fsm axi_fsm (
        .clk(clk),
        .reset_n(reset),
		.AWADDR(AWADDR),
		.AWVALID(AWVALID),
		.AWREADY(AWREADY),
		.WDATA(WDATA),
		.WVALID(WVALID),
		.WREADY(WREADY),
		.BVALID(BVALID),
		.BREADY(BREADY),
		.ARADDR(ARADDR),
		.ARVALID(ARVALID),
		.ARREADY(ARREADY),
		.RDATA(RDATA),
		.RVALID(RVALID),
		.RREADY(RREADY),
        .head_reg(hfifo_data_out),
        .tx_fifo_data(rxfifo_data_out), //input data
		.tx_fifo_empty(rxfifo_empty), //input
		.tx_fifo_rd_en(rxfifo_rd_en), //output
		.rx_fifo_data(txfifo_data_in), //output
		.rx_fifo_full(txfifo_full), //input
		.rx_fifo_wr_en(txfifo_wr_en), //output
		.hfifo_rd_en(hfifo_rd_en),
		.write_error(write_error), //error 
		.read_error(read_error) //error
    );

    // TX Logic to Connect TX FIFO to MAC TX Interface
    reg [7:0] tx_data_reg;
    reg       tx_enable_reg;
    reg       tx_error_reg;

    always @(posedge MTxClk or posedge reset) begin
        if (reset) begin
            tx_data_reg   <= 8'b0;
            tx_enable_reg <= 1'b0;
            tx_error_reg  <= 1'b0;
        end else if (!txfifo_empty) begin
            tx_data_reg   <= txfifo_data_out[7:0];
            tx_enable_reg <= 1'b1;
            tx_error_reg  <= 1'b0;
            txfifo_rd_en  <= 1'b1; // Read from TX FIFO
        end else begin
            tx_enable_reg <= 1'b0;
            txfifo_rd_en  <= 1'b0;
        end
    end

    // Assign TX interface outputs
    assign MTxD    = tx_data_reg;
    assign MTxEn   = tx_enable_reg;
    assign MTxErr  = tx_error_reg;

endmodule
