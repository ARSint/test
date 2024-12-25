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
input    logic                       fifo_full,         //input from fifo to support backpressure
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
    end else begin
        paddr_q        <=    i_eth_sb_paddr;
        pwdata_q       <=    i_eth_sb_pwdata;
        pstrb_q        <=    i_eth_sb_pstrb;
        wr_en_q        <=    wr_en;
		rd_en_q        <=    rd_en;
        prdata_q       <=    i_eth_sb_ctrl_rdata;
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
            if(~(i_eth_sb_psel)) begin
                next_state    = IDLE;
            end else begin
                next_state    = ENABLE;
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
	    wr_en              =   1'b0;
	    rd_en              =   1'b0;    
    end
    ENABLE: begin
        if(i_eth_sb_pwrite) begin
			 if( !fifo_full)begin
            o_eth_sb_pready    =   1'b1;
			wr_en              =   1'b1;
			rd_en              = 1'b0; 
            pwdata_w           =   i_eth_sb_pwdata;
            pstrb_w            =   i_eth_sb_pstrb;        
            o_eth_sb_pslverr   =   i_eth_sb_ctrl_inv_addr; end
        end else begin
		   if(!(fifo_empty)) begin
            o_eth_sb_pready    = 1'b1;
			o_eth_sb_prdata    = i_eth_sb_ctrl_rdata;
			rd_en              = 1'b1;  
			wr_en              = 1'b0;			
            o_eth_sb_pslverr   = i_eth_sb_ctrl_inv_addr; end
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