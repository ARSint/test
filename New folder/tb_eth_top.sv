`timescale 1ns / 1ps

module tb_eth_top;

    // Clock and Reset
    reg clk;
    reg reset;

    // RX Interface
    reg MRxClk;
    reg [7:0] MRxD;
    reg MRxDV;

    // TX Interface
	reg MTxClk;
    wire [7:0] MTxD;
    wire MTxEn;
    wire MTxErr;

    // MAC Configuration
    reg [47:0] MAC;
    reg [15:0] MaxFL;
    reg HugEn;
    reg DlyCrcEn;
    reg r_IFG;

    // AXI-Lite Master Interface (from MAC)
    wire [31:0] AWADDR;
    wire AWVALID;
    wire AWREADY;
    wire [31:0] WDATA;
    wire WVALID;
    wire WREADY;
    wire BVALID;
    wire BREADY;
    wire [31:0] ARADDR;
    wire ARVALID;
    wire ARREADY;
    wire [31:0] RDATA;
    wire RVALID;
    wire RREADY;

    // Instantiate the Ethernet MAC (eth_top)
    eth_top uut (
        .clk(clk),
        .reset(reset),
        .MRxClk(MRxClk),
        .MRxD(MRxD),
        .MRxDV(MRxDV),
		.MTxClk(MTxClk),
        .MTxD(MTxD),
        .MTxEn(MTxEn),
        .MTxErr(MTxErr),
        .MAC(MAC),
        .MaxFL(MaxFL),
        .HugEn(HugEn),
        .DlyCrcEn(DlyCrcEn),
        .r_IFG(r_IFG),
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
        .RREADY(RREADY)
    );

    // Slave Model for AXI-Lite Interface (Simplified)
    axi_slave_model axi_slave (
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
        .RREADY(RREADY)
    );

    // Generate Clock
    always begin
        #5 clk = ~clk; // 100 MHz clock
    end

    always begin
        #5 MRxClk = ~MRxClk; // 100 MHz RX clock (same as system clock for simplicity)
        #5 MTxClk = ~MTxClk; // 100 MHz RX clock (same as system clock for simplicity)
		
    end

    // Test Initialization
    initial begin
        // Initialize Signals
        clk = 0;
        MRxClk = 0;
		MTxClk = 0;
        reset = 0;
        MRxD = 8'b0;
        MRxDV = 0;
        MAC = 48'hAA_BB_CC_DD_EE_FF; // Example MAC address
        MaxFL = 16'd1500;            // Max frame length (standard Ethernet frame size)
        HugEn = 0;
        DlyCrcEn = 0;
        r_IFG = 12'd12;              // Default inter-frame gap

        // Apply Reset
        reset = 1;
        #10;
        reset = 0;

        // Stimulate RX Frames with Different Sizes
        #10;
        stimulate_rx_frame(64);     // Minimum frame size (64 bytes including header)
        #20;
        stimulate_rx_frame(1500);    // Standard frame size (1500 bytes)
        #20;
        stimulate_rx_frame(1518);   // Large frame size (e.g., jumbo frame)
        #20;
        stimulate_rx_frame(1024);   // Very large frame (testing max frame size)
        #20;
        stimulate_rx_frame(200);     // Short frame (less than minimum frame size, should be rejected)

        // End of simulation
        #100;
        $finish;
    end
task stimulate_rx_frame(input [15:0] size);
    integer i;
    reg [7:0] frame_data [0:1517]; // Ethernet Frame Buffer
    reg [31:0] crc;                // CRC for the frame
    reg [47:0] dst_mac;
    reg [47:0] src_mac;
    reg [15:0] length;
    reg [15:0] frame_size;
    reg [7:0]  sdf;
	reg [23:0] address;
	reg [3:0]  opcode;
    begin
        // Validate and Set Frame Size
        if (size < 64) frame_size = 64;          // Minimum Ethernet Frame Size
        else if (size > 1518) frame_size = 1518; // Maximum Ethernet Frame Size
        else frame_size = size;

        // Initialize MAC Addresses and Length Field
        dst_mac = 48'hAA_BB_CC_DD_EE_FF; // Destination MAC
        src_mac = 48'h11_22_33_44_55_66; // Source MAC
        length  = frame_size - 19;       // Subtract MAC headers (14 bytes) and CRC (4 bytes)
        sdf = 8'hd5;
		address=24'h11_22_33;
		opcode=4'h1;
        // Fill Ethernet Frame Header
		frame_data[0]  = sdf;
        frame_data[1]  = dst_mac[47:40];
        frame_data[2]  = dst_mac[39:32];
        frame_data[3]  = dst_mac[31:24];
        frame_data[4]  = dst_mac[23:16];
        frame_data[5]  = dst_mac[15:8];
        frame_data[6]  = dst_mac[7:0];

        frame_data[7]  = src_mac[47:40];
        frame_data[8]  = src_mac[39:32];
        frame_data[9]  = src_mac[31:24];
        frame_data[10] = src_mac[23:16];
        frame_data[11] = src_mac[15:8];
        frame_data[12] = src_mac[7:0];

        frame_data[13] = length[15:8];
        frame_data[14] = length[7:0];

//hearderin data first 32bit
        frame_data[15] = address[23:16];
        frame_data[16] = address[15:8];
        frame_data[17] = address[7:0];
        frame_data[18] = {4'h0,opcode};
        // Fill Payload with Random Data
        for (i = 19; i < frame_size - 4; i = i + 1) begin
            frame_data[i] = $random;
        end

        // Compute CRC for the Frame (excluding CRC bytes)
        crc = compute_crc32(frame_data, frame_size - 4);

        // Append CRC to Frame (Last 4 Bytes)
        frame_data[frame_size - 4] = crc[31:24];
        frame_data[frame_size - 3] = crc[23:16];
        frame_data[frame_size - 2] = crc[15:8];
        frame_data[frame_size - 1] = crc[7:0];

        // Simulate RX Frame Transmission
        MRxDV = 1; // Assert RX Data Valid
        for (i = 0; i < frame_size; i = i + 1) begin
            @(posedge MRxClk); // Wait for RX Clock Rising Edge
            MRxD = frame_data[i]; // Transmit Byte on Each Clock Cycle
        end
        MRxDV = 0; // De-assert RX Data Valid at End of Frame
    end
endtask


// CRC Calculation (Simple CRC32 computation)
function [31:0] compute_crc32(input [7:0] data [0:1517], input integer length);
    integer i, j;
    reg [31:0] crc;
    reg [7:0] bytet;
    begin
        crc = 32'hFFFFFFFF;  // Initial CRC value
        for (i = 0; i < length; i = i + 1) begin
            bytet = data[i];
            crc = crc ^ {24'b0, bytet};
            for (j = 0; j < 8; j = j + 1) begin
                if (crc[31]) begin
                    crc = {crc[30:0], 1'b0} ^ 32'h04C11DB7; // CRC polynomial
                end else begin
                    crc = {crc[30:0], 1'b0};
                end
            end
        end
        compute_crc32 = crc ^ 32'hFFFFFFFF; // Final XOR
    end
endfunction


endmodule

// Example AXI-Lite Slave Model
module axi_slave_model (
    input [31:0] AWADDR,
    input AWVALID,
    output AWREADY,
    input [31:0] WDATA,
    input WVALID,
    output WREADY,
    output BVALID,
    input BREADY,
    input [31:0] ARADDR,
    input ARVALID,
    output ARREADY,
    output [31:0] RDATA,
    output RVALID,
    input RREADY
);

    // Simple AXI slave response logic
    reg [31:0] mem [0:255];  // Simple memory model
    reg [31:0] read_data;
    reg write_valid, read_valid;

    assign AWREADY = 1;
    assign WREADY = 1;
    assign ARREADY = 1;
    assign RDATA = read_data;
    assign RVALID = read_valid;
    assign BVALID = write_valid;

    always @(posedge AWVALID) begin
        if (AWVALID) begin
            mem[AWADDR[7:0]] <= WDATA;  // Write to memory
            write_valid <= 1;
        end
    end

    always @(posedge ARVALID) begin
        if (ARVALID) begin
            read_data <= mem[ARADDR[7:0]];  // Read from memory
            read_valid <= 1;
        end
    end

    always @(posedge BREADY) begin
        write_valid <= 0;
    end

    always @(posedge RREADY) begin
        read_valid <= 0;
    end

endmodule
