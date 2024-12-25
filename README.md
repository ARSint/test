//***********************************************************************************************
//                                      D2D FSM 
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
input logic                   i_fifo_full,         //input from fifo to support backpressure
input logic                   i_fifo_empty,        //input from fifo to support backpressure
input logic                   i_dec_flash_en,   //Enable signal for flash from addr decoder   
input logic                   i_dec_axi_en,     //Enable signal for AXI from addr decoder
input logic                   i_dec_loc_mem_map,//local memory mapped IO/via-in-one interface
input logic  [3:0]            i_core_wstrb,     //Indicate instruction R/W from picoRV32
input logic  [ADDR_WIDTH-1:0] i_core_addr,      //R/W operation address from picoRV32
input logic                   i_core_valid,     //Valid from picoRV32
input logic  [DATA_WIDTH-1:0] i_core_wdata,     //Write data from picoRV32
input logic  [2:0]            i_axi_sresp,      //Indicates slave response status (R/W)
input logic  [DATA_WIDTH-1:0] i_axi_sdata,      //AXI slave Data
input logic                   i_axi_svalid,     //Valid response indicator from AXI
input logic                   i_axi_saccept,    //Subordinate accept current R/W request

output logic [DATA_WIDTH-1:0] o_core_rdata,     //Read data for picoRV32
output logic [DATA_WIDTH-1:0] o_sram_wr_data,   //Write data for SRAM
output logic                  o_core_ready,     //read data can be sampled and request has been executed
output logic                  o_axi_mread,      //Read enable signal for AXI master
output logic                  o_axi_mwrite,     //Write enable signal for AXI master
output logic [ADDR_WIDTH-1:0] o_axi_maddr,      //AXI Master address for Read and Write    
output logic [DATA_WIDTH-1:0] o_axi_mdata,      //Write data for AXI
output logic                  o_axi_mready,     //Response accept from D2D controller
output logic [3:0]            o_axi_mwstrb,     //Write byte lane write strobes
output logic                  o_axi_slverr,     //slave error response from AXI
output logic                  o_axi_decoderr,   //decoder error response from AXI
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
logic                           core_valid_q;
logic                           core_valid_q1;
logic    [ADDR_WIDTH-1:0]       core_addr_w;
logic    [DATA_WIDTH-1:0]       o_core_rdata_w;
logic                           core_ready_q;

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
    end else begin
        current_state      <= next_state;
    end
end
//********************************************************
//            Next State Logic (comb)
//********************************************************
always_comb begin
    case (current_state)
        IDLE: begin //IDLE stage to AXI
            if (!i_fuse_enable) begin 
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
           if(!i_core_valid) begin 
              next_state   = IDLE;
           end else begin
              next_state   = AXI_RES;
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
   
    o_core_ready            = 1'b0;
    o_axi_mread             = 1'b0;
    o_axi_mwrite            = 1'b0;
    o_axi_maddr             = {ADDR_WIDTH{1'b0}}; //26'h00_0000;
    o_axi_mdata             = 32'h0000_0000;
    o_axi_mready            = 1'b0;
    o_axi_mwstrb            = 4'h0;
    o_core_rdata            = 32'h0000_0000;
    o_core_rdata_w          = 32'h0000_0000;
    o_axi_slverr            = 1'b0;
    o_axi_decoderr          = 1'b0;
    case (next_state) 
        IDLE: begin //IDLE state

            o_core_rdata    = 32'h0000_0000;
            o_core_ready    = 1'b0;
            o_axi_mread     = 1'b0;
            o_axi_mwrite    = 1'b0;
            o_axi_maddr     = {ADDR_WIDTH{1'b0}}; //24'h00_0000;
            o_axi_mdata     = 32'h0000_0000;
            o_axi_mready    = 1'b0;
            o_axi_mwstrb    = 4'h0; 
            o_axi_slverr    = 1'b0;
            o_axi_decoderr  = 1'b0;
            o_core_rdata_w  = 32'h0;
        end
        AXI_REQ: begin //Logic for AXI read/Write reqest  
            if(i_core_wstrb == 0) begin //READ REQ
                o_axi_mread     = 1'b1;
                o_axi_mwrite    = 1'b0;
                o_axi_maddr     = i_core_addr;
            end else begin  //WRITE REQ
                o_axi_mread     = 1'b0;
                o_axi_mwrite    = 1'b1;
                o_axi_mwstrb    = i_core_wstrb;
                o_axi_maddr     = i_core_addr;
                o_axi_mdata     = i_core_wdata;
            end
        end
        AXI_RES: begin //Logic for AXI read/Write response
            if((i_axi_sresp == OK_R) && i_axi_svalid)begin  //READ OK RES
                o_core_ready        = 1'b1;
                o_core_rdata        = i_axi_sdata;
                o_axi_mready        = 1'b1;
                o_axi_slverr        = 1'b0;
                o_axi_decoderr      = 1'b0;
            end else if ((i_axi_sresp == OK_W) && i_axi_svalid) begin   //WRITE OK RES
                o_axi_mready        = 1'b1;
                o_core_ready        = 1'b1;
                o_core_rdata        = i_axi_sdata;
                o_axi_slverr        = 1'b0;
                o_axi_decoderr      = 1'b0;
            end else if (((i_axi_sresp == SLVERR_R) || (i_axi_sresp == SLVERR_W)) && i_axi_svalid) begin //SLAVE ERROR RESP
                o_axi_mready        = 1'b1;
                o_core_ready        = 1'b1;
                o_core_rdata        = i_axi_sdata;
                o_axi_decoderr      = 1'b0;
                o_axi_slverr        = 1'b1;
            end else begin
                o_axi_mready        = 1'b0;
                o_core_ready        = 1'b0;
                o_core_rdata        = 32'h0000_0000;
                o_axi_slverr        = 1'b0;
                o_axi_decoderr      = 1'b0;
            end
        end

     default: begin
            o_core_ready        = 1'b0;
            o_axi_mread         = 1'b0;
            o_axi_mwrite        = 1'b0;
            o_axi_maddr         = {ADDR_WIDTH{1'b0}};//24'h00_0000;
            o_axi_mdata         = 32'h0000_0000;
            o_axi_mready        = 1'b0;
            o_axi_mwstrb        = 4'h0;
            o_core_rdata        = 32'h0000_0000;
            o_axi_slverr        = 1'b0;
            o_axi_decoderr      = 1'b0;
            o_core_rdata_w      = 32'h0;
     end
    endcase
    
end 

endmodule
//***********************************************************************************************
//                                  ETH SB FSM
//***********************************************************************************************
module    eth_sb_apb_fsm #( 
parameter ADDR_WIDTH = 32,
parameter DATA_WIDTH = 32
) (
//********************************************************
//              I/O Declaration                   
//********************************************************
input    logic                       i_clk,            //input clk
input    logic                       i_reset_n,        //input active low reset
input    logic                       i_eth_sb_psel,   //Slave device is selected                               
input    logic                       i_eth_sb_penable,//Second and subsequent cycle of APB transfer
input    logic                       i_eth_sb_pwrite, //APB write access when high and APB read acces when low 
input    logic   [ADDR_WIDTH-1:0]    i_eth_sb_paddr,  //APB address bus
input    logic   [DATA_WIDTH-1:0]    i_eth_sb_pwdata, //APB write data received
input    logic   [3:0]               i_eth_sb_pstrb,  //APB write strobe received
output   logic                       o_eth_sb_pready, //Indicate extend an APB transfer
output   logic                       o_eth_sb_pslverr,//Signal indicates a tranfer failure
output   logic   [DATA_WIDTH-1:0]    o_eth_sb_prdata, //APB read data when PWRITE low

output   logic   [DATA_WIDTH-1:0]    o_eth_sb_ctrl_wdata,//output write data to the controller 
output   logic   [DATA_WIDTH-1:0]    o_eth_sb_ctrl_addr, //output address to the controller
output   logic                       o_eth_sb_ctrl_wr_en,//output write enable to the controller
output   logic                       o_eth_sb_ctrl_rd_en,//output read enable to the controller
output   logic   [3:0]               o_eth_sb_ctrl_pstrb,// output strobe for determining which byte lane wdata needs to be updated 
input    logic   [DATA_WIDTH-1:0]    i_eth_sb_ctrl_rdata, //input read data from the controller
input    logic                       i_eth_sb_ctrl_slverr,// input slave error from controller
input    logic                       i_eth_sb_ctrl_inv_addr, //invalid address enable recieved from controller
input    logic                       wdata_resp,       //input from thecontroller indicates write data transfer complete
input    logic                       rdata_resp,       //input from thecontroller indicates read data transfer complete
input    logic                       fuse_enable,      // mode select 0-axi 1-apb
input    logic                       fifo_full         //input from fifo to support backpressure
input    logic                       fifo_empty        //input from fifo to support backpressure
);
//********************************************************
//                  STATE PARAMETERS
//********************************************************

parameter    IDLE     =   2'b00;         //IDLE state
parameter    SETUP    =   2'b01;         //SETUP STATE 
parameter    ENABLE   =   2'b10;         //WRITE/READ DATA STATE 

//********************************************************
//              Reg and Wire Declaration                   
//********************************************************
logic    [ADDR_WIDTH-1:0]    paddr_w;
logic    [ADDR_WIDTH-1:0]    paddr_q;
logic    [DATA_WIDTH-1:0]    pwdata_w;
logic    [DATA_WIDTH-1:0]    pwdata_q;
logic    [3:0]               pstrb_q;
logic    [3:0]               pstrb_w;
logic    [DATA_WIDTH-1:0]    wr_status_q;
logic    [DATA_WIDTH-1:0]    rd_status_q;
logic    [DATA_WIDTH-1:0]    prdata_q;
logic                        rdata_resp_q;
logic                        wr_en_q;
logic                        rd_en_q;
logic                        ready_q;
logic    [DATA_WIDTH-1:0]    slverr_w;
logic    [ADDR_WIDTH-1:0]    paddr;       
logic    [DATA_WIDTH-1:0]    pwdata;
logic    [3:0]               pstrb;
logic                        wr_en;
logic    [DATA_WIDTH-1:0]    prdata;
logic    [DATA_WIDTH-1:0]    wr_status;
logic    [DATA_WIDTH-1:0]    rd_status;
logic                        rd_en;
logic                        rd_resp;
logic    [1:0]               current_state,next_state;
//********************************************************
//             Continuous assignments
//********************************************************
assign    o_eth_sb_ctrl_wdata    =    pwdata_q;
assign    o_eth_sb_ctrl_addr     =    paddr_q;
assign    o_eth_sb_ctrl_wr_en    =    wr_en_q;
assign    o_eth_sb_ctrl_pstrb    =    pstrb_q;
assign    o_eth_sb_ctrl_rd_en    =    rd_en_q;
assign    slverr_w         =    ~i_eth_sb_ctrl_slverr ? 'h80 : 'hff;

//********************************************************
//             data,address registers
//********************************************************

always_ff @(posedge i_clk or negedge i_reset_n) begin 
    if(!i_reset_n) begin
        paddr_q        <=    32'h0;   
        pwdata_q       <=    32'h0; 
        pstrb_q        <=    4'h0;   
        wr_en_q        <=    1'b0; 
        prdata_q       <=    1'b0;
        wr_status_q    <=    1'b0;
        rd_status_q    <=    1'b0;
    end else begin
        paddr_q        <=    paddr;
        pwdata_q       <=    pwdata;
        pstrb_q        <=    pstrb;
        wr_en_q        <=    wr_en;
		rd_en_q        <=    rd_en;
        prdata_q       <=    prdata;
        wr_status_q    <=    wr_status;
        rd_status_q    <=    rd_status;
    end
end

//********************************************************
//             Current state register
//********************************************************

always_ff @(posedge i_clk or negedge i_reset_n) begin
    if(!i_reset_n ) begin
        current_state    <=    IDLE;
    end else begin
        current_state    <=    next_state;
    end
end
//********************************************************
//             next_state combinational logic
//********************************************************

always_comb    begin
next_state = IDLE;
    case(current_state)
        IDLE: begin
            if((i_eth_sb_psel && fuse_enable)) begin
                next_state    =  SETUP;
            end else begin
                next_state    = IDLE;
            end
        end
        SETUP: begin
            if(~(i_eth_sb_psel)) begin
                next_state    = IDLE;
            end else begin
                next_state    = ENABLE;
            end
        end
        ENABLE: begin
                next_state    = IDLE;
            end
        end
        default: begin
            next_state    = IDLE;
        end
    endcase
end
//********************************************************
//             output combinational logic
//********************************************************

always_comb    begin
		o_eth_sb_pready    =    1'b0;        
		o_eth_sb_pslverr   =    1'b0;
		o_eth_sb_prdata    =    32'h0;           
		paddr_w            =    32'h0;
		pwdata_w           =    32'h0;
		pstrb_w            =    4'h0; 
    case(next_state)
    IDLE: begin
        o_eth_sb_pready    =    1'b0;        
        o_eth_sb_pslverr   =    1'b0;
        o_eth_sb_prdata    =    32'h0;               
        paddr_w            =    32'h0;
        pstrb_w            =    4'h0;
        pwdata_w           =    32'h0;
	    wr_en              =   1'b0;
	    rd_en              =   1'b0;
    end
    SETUP: begin
        o_eth_sb_pready = 1'b0;       
    end
    ENABLE: begin
        if(i_eth_sb_pwrite && !fifo_full) begin
            o_eth_sb_pready    =   1'b1;
			wr_en              =   1'b1;
            pwdata_w           =   i_eth_sb_pwdata;
            pstrb_w            =   i_eth_sb_pstrb;        
            o_eth_sb_pslverr   =   i_eth_sb_ctrl_inv_addr;
        end 
		if(!(i_eth_sb_pwrite && fifo_empty)) begin
            o_eth_sb_pready    = 1'b1;
			o_eth_sb_prdata    = i_eth_sb_ctrl_rdata;
			rd_en              = 1'b1;       
            o_eth_sb_pslverr   = i_eth_sb_ctrl_inv_addr;
        end
    end
    default: begin
	    wr_en              =   1'b0;
	    rd_en              =   1'b0;
        o_eth_sb_pready    =   1'b0;        
        o_eth_sb_pslverr   =   1'b0;
        o_eth_sb_prdata    =   32'h0;               
        paddr_w            =   32'h0;
        pwdata_w           =   32'h0;
        pstrb_w            =   4'h0;
       end
    endcase
end

endmodule
        
        
        
        
