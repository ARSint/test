Summary of the FSM (eth_sb_axi_fsm):
Inputs:

System signals: i_clk, i_reset_n
AXI-specific signals: i_axi_sresp, i_axi_sdata, etc.
FIFO-specific signals: write_fifo_empty, read_fifo_full, etc.
Control parameters: i_fuse_enable, i_core_wstrb, etc.
Transaction parameters: byte_length, address
Outputs:

AXI transactions: o_axi_mread, o_axi_mwrite, o_axi_maddr, etc.
FIFO interactions: read_fifo_write, read_fifo_data, etc.
States:

IDLE: Waits for transactions to start.
AXI_REQ: Issues AXI read/write requests.
AXI_RES: Handles AXI responses (e.g., read/write acknowledgment or errors).
Features:

Automatic address incrementing (addr_counter).
Byte-length-driven transaction looping (counter vs. byte_length).
State machine transition logic.

State Transition Logic:

The transitions between states (IDLE, AXI_REQ, AXI_RES) seem logically correct.
Ensure axi_saccept_q properly synchronizes with i_axi_saccept for edge-sensitive behavior.
Address Handling:

The addr_counter is incremented by 4, assuming 32-bit (4-byte) words. Ensure this matches your AXI word size.
FIFO Backpressure:

write_fifo_empty and read_fifo_full are well-handled for flow control.
Response Handling:

AXI responses (i_axi_sresp) include OK and SLVERR conditions. Ensure these are adequately tested.


Explanation of Key Variables and Outputs
Inputs:

i_fuse_enable: Mode select (AXI or APB).
write_fifo_empty, read_fifo_full: Indicate FIFO readiness for data flow.
i_axi_sresp: Indicates AXI response status (OK, SLVERR, etc.).
i_axi_svalid: Confirms a valid response is available.
Outputs:

o_axi_mread, o_axi_mwrite: AXI master read/write enable signals.
o_axi_maddr: Address for AXI transactions.
o_axi_mdata: Data for write transactions.
read_fifo_write, read_fifo_data: Control and data for the read FIFO.
o_axi_slverr: Indicates a slave error response.
o_axi_decoderr: Indicates a decoding error (reserved or unused).

//***********************************************************************************************
//                                      sbeth FSM 
//***********************************************************************************************
module eth_sb_axi_fsm #(
  parameter ADDR_WIDTH = 24,
  parameter DATA_WIDTH = 32
) (
//********************************************************
//              I/O Declaration                   
//********************************************************
input logic                   i_clk,            //System clock
input logic                   i_reset_n,        //System reset

input logic                   i_fuse_enable,      // mode select 0-axi 1-apb
input logic  [3:0]            i_core_wstrb,     //Indicate instruction R/W from controller
input logic		      i_rw,
input logic  [2:0]            i_axi_sresp,      //Indicates slave response status (R/W)
input logic  [DATA_WIDTH-1:0] i_axi_sdata,      //AXI slave Data
input logic                   i_axi_svalid,     //Valid response indicator from AXI
input logic                   i_axi_saccept,    //Subordinate accept current R/W request

output logic                  o_axi_mread,      //Read enable signal for AXI master
output logic                  o_axi_mwrite,     //Write enable signal for AXI master
output logic [ADDR_WIDTH-1:0] o_axi_maddr,      //AXI Master address for Read and Write    
output logic [DATA_WIDTH-1:0] o_axi_mdata,      //Write data for AXI
output logic                  o_axi_mready,     //Response accept from D2D controller
output logic [3:0]            o_axi_mwstrb,     //Write byte lane write strobes
output logic                  o_axi_slverr,     //slave error response from AXI
output logic                  o_axi_decoderr,   //decoder error response from AXI

// Write FIFO Interface
input logic              	  write_fifo_empty, //input from fifo to support backpressure
output logic          	  write_fifo_read,  
input logic [DATA_WIDTH-1:0]  write_fifo_data, //input from fifo for write request
// Read FIFO Interface
input logic              	  read_fifo_full, //input from fifo to support backpressure
output logic             	  read_fifo_write,
output logic [DATA_WIDTH-1:0] read_fifo_data,//output from axi for read request
// Byte Length Input
input  logic [7:0]            byte_length, //R/W operation byte length from controller
// Address Initialization Input
input logic [ADDR_WIDTH-1:0]  address //R/W operation address from controller
);

//********************************************************
//                  State Declaration 
//********************************************************
parameter IDLE          = 2'd0;                 //IDLE stage for SRAM/AXI transaction 
parameter AXI_REQ       = 2'd1;                 //AXI Read/Write request access
parameter AXI_RES       = 2'd2;                 //AXI Read/Write response access

//********************************************************
//                  SRESP PARAMETER DECLARATION
//********************************************************
parameter OK_R          = 3'b000;              //AXI Read ok response
parameter OK_W          = 3'b001;              //AXI write ok response
parameter SLVERR_R      = 3'b100;              //AXI slave error read response
parameter SLVERR_W      = 3'b101;              //AXI slave error write response


//********************************************************
//              Reg and Wire Declaration                   
//********************************************************
logic    [2:0]                  current_state; 
logic    [2:0]                  next_state;
logic                           axi_saccept_q;
logic [ADDR_WIDTH-1:0] addr_counter;
    // Transaction Counters
logic [11:0] counter;
//********************************************************
//             Continuous assignments
//********************************************************


//********************************************************
//             Register Declaration 
//********************************************************

always_ff @(posedge i_clk or negedge i_reset_n) begin
    if (!i_reset_n) begin
        axi_saccept_q <= 1'b0; 
    end else begin
        axi_saccept_q <= i_axi_saccept; 
    end
end


//********************************************************
//            Current State Register (seq)  
//********************************************************
always_ff @(posedge i_clk or negedge i_reset_n) begin
    if ( !i_reset_n) begin
        current_state      <= IDLE;
		addr_counter <= address;
	    write_fifo_read = 1'b0;
    end else begin
        current_state      <= next_state;
	// Auto-increment the addresses and counters
        if (current_state == AXI_REQ && axi_saccept_q) begin
            addr_counter <= addr_counter + 4; // Increment by 4 bytes
            counter <= counter + 1'b1;
		end
		if(current_state == IDLE)begin
			addr_counter <= address;
        end
		if(i_axi_saccept)begin
			write_fifo_read = i_rw;
		end
		// Reset counters in IDLE state
        if (current_state == IDLE) begin
            counter <= 12'h000;
        end 
    end
end
//********************************************************
//            Next State Logic (comb)
//********************************************************
always_comb begin
    case (current_state)
        IDLE: begin //IDLE stage to AXI
            if (!i_fuse_enable && (!write_fifo_empty || !read_fifo_full) && (counter < (byte_length >> 2)-1)) begin 
                next_state   = AXI_REQ;
            end else begin
                next_state   = IDLE;
            end
        end
        AXI_REQ: begin //AXI Read/Write request access     
            if(axi_saccept_q) begin 
                next_state   = AXI_RES;
            end else begin
                next_state   = AXI_REQ;
            end
        end
        AXI_RES: begin //AXI Read/Write response access    
           if((counter >= (byte_length >> 2)-1)) begin 
              next_state   = IDLE  ;
           end else begin
              next_state   = AXI_REQ;
           end
      end

    default: begin //Default IDLE stage 
       next_state       = IDLE;
    end
    endcase
end

//********************************************************
//            Output Logic (comb)
//********************************************************
always_comb begin
   
    read_fifo_write         = 1'b0;
    o_axi_mread             = 1'b0;
    o_axi_mwrite            = 1'b0;
    o_axi_maddr             = {ADDR_WIDTH{1'b0}}; //26'h00_0000;
    o_axi_mdata             = 32'h0000_0000;
    o_axi_mready            = 1'b0;
    o_axi_mwstrb            = 4'h0;
    read_fifo_data          = 32'h0000_0000;
    o_axi_slverr            = 1'b0;
    o_axi_decoderr          = 1'b0;
    case (next_state) 
        IDLE: begin //IDLE state

            read_fifo_data    = 32'h0000_0000;
            o_axi_mread     = 1'b0;
            o_axi_mwrite    = 1'b0;
            o_axi_maddr     = {ADDR_WIDTH{1'b0}}; //24'h00_0000;
            o_axi_mdata     = 32'h0000_0000;
            o_axi_mready    = 1'b0;
            o_axi_mwstrb    = 4'h0; 
            o_axi_slverr    = 1'b0;
            o_axi_decoderr  = 1'b0;
            read_fifo_write = 1'b0;
			
        end
        AXI_REQ: begin //Logic for AXI read/Write reqest  
            if(i_rw == 1'b0) begin //READ REQ
                o_axi_mread     = 1'b1;
                o_axi_mwrite    = 1'b0;
                o_axi_maddr     = addr_counter;
				//read_fifo_write = 1'b1;
                //read_fifo_data  = i_axi_sdata;
            end else begin  //WRITE REQ
                o_axi_mread     = 1'b0;
                o_axi_mwrite    = 1'b1;
                o_axi_mwstrb    = i_core_wstrb;
                o_axi_maddr     = addr_counter;
                o_axi_mdata     = write_fifo_data;
            end
        end
        AXI_RES: begin //Logic for AXI read/Write response
            if((i_axi_sresp == OK_R) && i_axi_svalid)begin  //READ OK RES
                read_fifo_write     = 1'b1;
                read_fifo_data      = i_axi_sdata;
                o_axi_mready        = 1'b1;
                o_axi_slverr        = 1'b0;
                o_axi_decoderr      = 1'b0;
            end else if ((i_axi_sresp == OK_W) && i_axi_svalid) begin   //WRITE OK RES
                o_axi_mready        = 1'b1;
                read_fifo_write     = 1'b1;
                read_fifo_data      = i_axi_sdata;
                o_axi_slverr        = 1'b0;
                o_axi_decoderr      = 1'b0;
            end else if (((i_axi_sresp == SLVERR_R) || (i_axi_sresp == SLVERR_W)) && i_axi_svalid) begin //SLAVE ERROR RESP
                o_axi_mready        = 1'b1;
                read_fifo_write     = 1'b1;
                read_fifo_data      = i_axi_sdata;
                o_axi_decoderr      = 1'b0;
                o_axi_slverr        = 1'b1;
            end else begin
                o_axi_mready        = 1'b0;
                read_fifo_write     = 1'b0;
                read_fifo_data      = 32'h0000_0000;
                o_axi_slverr        = 1'b0;
                o_axi_decoderr      = 1'b0;
            end
        end

     default: begin
            read_fifo_write     = 1'b0;
            o_axi_mread         = 1'b0;
            o_axi_mwrite        = 1'b0;
            o_axi_maddr         = {ADDR_WIDTH{1'b0}};//24'h00_0000;
            o_axi_mdata         = 32'h0000_0000;
            o_axi_mready        = 1'b0;
            o_axi_mwstrb        = 4'h0;
            read_fifo_data      = 32'h0000_0000;
            o_axi_slverr        = 1'b0;
            o_axi_decoderr      = 1'b0;
     end
    endcase
    
end 

endmodule


module tb_eth_sb_axi_fsm;

  // Parameters
  parameter ADDR_WIDTH = 24;
  parameter DATA_WIDTH = 32;

  // DUT Inputs
  reg                   i_clk;
  reg                   i_reset_n;
  reg                   i_fuse_enable;
  reg [3:0]             i_core_wstrb;
  reg                   i_rw;
  reg [2:0]             i_axi_sresp;
  reg [DATA_WIDTH-1:0]  i_axi_sdata;
  reg                   i_axi_svalid;
  reg                   i_axi_saccept;
  reg                   write_fifo_empty;
  reg                   read_fifo_full;
  reg [7:0]             byte_length;
  reg [DATA_WIDTH-1:0]  address;
  reg [DATA_WIDTH-1:0]  write_fifo_data;

  // DUT Outputs
  wire                  o_axi_mread;
  wire                  o_axi_mwrite;
  wire [ADDR_WIDTH-1:0] o_axi_maddr;
  wire [DATA_WIDTH-1:0] o_axi_mdata;
  wire                  o_axi_mready;
  wire [3:0]            o_axi_mwstrb;
  wire                  o_axi_slverr;
  wire                  o_axi_decoderr;
  wire                  read_fifo_write;
  wire [DATA_WIDTH-1:0] read_fifo_data;
  wire                  write_fifo_read;
    reg [31:0] slave_memory [0:255];
  // Instantiate the DUT
  eth_sb_axi_fsm #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) dut (
    .i_clk(i_clk),
    .i_reset_n(i_reset_n),
    .i_fuse_enable(i_fuse_enable),
    .i_core_wstrb(i_core_wstrb),
    .i_rw(i_rw),
    .i_axi_sresp(i_axi_sresp),
    .i_axi_sdata(i_axi_sdata),
    .i_axi_svalid(i_axi_svalid),
    .i_axi_saccept(i_axi_saccept),
    .write_fifo_empty(write_fifo_empty),
    .write_fifo_read(write_fifo_read),
    .write_fifo_data(write_fifo_data),
    .read_fifo_full(read_fifo_full),
    .read_fifo_write(read_fifo_write),
    .read_fifo_data(read_fifo_data),
    .byte_length(byte_length),
    .address(address),
    .o_axi_mread(o_axi_mread),
    .o_axi_mwrite(o_axi_mwrite),
    .o_axi_maddr(o_axi_maddr),
    .o_axi_mdata(o_axi_mdata),
    .o_axi_mready(o_axi_mready),
    .o_axi_mwstrb(o_axi_mwstrb),
    .o_axi_slverr(o_axi_slverr),
    .o_axi_decoderr(o_axi_decoderr)
  );

  // Clock Generation
  always #5 i_clk = ~i_clk;

  // Task to Reset DUT
  task reset_dut;
    begin
      i_reset_n = 0;
      #20;
      i_reset_n = 1;
    end
  endtask

  // Task to Generate Stimulus
  task generate_stimulus(
    input [DATA_WIDTH-1:0] start_addr,
    input [7:0] len,
    input logic rw
  );
    begin
      address = start_addr;
      byte_length = len;
      i_rw = rw;
      i_fuse_enable = 0;  // AXI Mode
      i_core_wstrb = 4'b1111;
      write_fifo_empty = 0;
      read_fifo_full = 0;
    end
  endtask

  // Self-Check Logic
  always @(posedge i_clk) begin
    if (!i_reset_n) begin
      // No check during reset
    end else begin
      // Example Check: Verify Read Transaction
      if (o_axi_mread && i_axi_saccept) begin
        if (o_axi_maddr !== address) begin
          $error("Mismatch in read address: Expected %h, Got %h", address, o_axi_maddr);
        end
      end

      // Example Check: Verify Write Transaction
      if (o_axi_mwrite && i_axi_saccept) begin
        if (o_axi_mdata !== write_fifo_data) begin
          $error("Mismatch in write data: Expected %h, Got %h", write_fifo_data, o_axi_mdata);
        end
      end
    end
  end
// Slave Model for Write Transactions
    always @(posedge i_clk) begin
        if (o_axi_mwrite) begin
            slave_memory[o_axi_maddr[23:0]] <= o_axi_mdata; // Write data to slave memory
            //bvalid <= 1; // Assert bvalid to indicate write completion
			 i_axi_svalid = 1;
			 end else begin
			 i_axi_svalid = 0;
        end
    end

    // Slave Model for Read Transactions
    always @(posedge i_clk) begin
        if (o_axi_mread) begin
            i_axi_sdata <= slave_memory[o_axi_maddr[23:0]]; // Read data from slave memory
			 i_axi_svalid = 1;
            //rvalid <= 1; // Assert rvalid to indicate read completion
			 end else begin
			 i_axi_svalid = 0;
        end
    end
  // Testbench Sequence
  initial begin
    // Initialize Inputs
    i_clk = 0;
    i_reset_n = 1;
    i_fuse_enable = 0;
    i_core_wstrb = 4'b0;
    i_rw = 0;
    i_axi_sresp = 3'b000;
    //i_axi_sdata = 32'h0;
    //i_axi_svalid = 0;
    i_axi_saccept = 1;
    write_fifo_empty = 1;
    read_fifo_full = 0;
    byte_length = 8'h0;
    address = 32'h0;
    write_fifo_data = 32'h0;

    // Reset DUT
    reset_dut();

    // Stimulus 1: Write Transaction
    generate_stimulus(32'h0000_0000, 8'h10, 1'b1);
    write_fifo_data = 32'hDEADBEEF;
    #100;

    // Stimulus 2: Read Transaction
    generate_stimulus(32'h0000_0000, 8'h08, 1'b0);
    #100;

    // Add More Stimuli...
    #1000;

    // End Simulation
    $finish;
  end


endmodule

