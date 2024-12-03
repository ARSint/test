/*
 * clk_gen.sv
 *
 *  Created on: 2024-12-01 
 *      Author: 
 */

module clk_gen #(
    parameter W = 8,
    parameter R = 1
) (
    input logic clk_i,
    input logic rst_n_i,

    input logic data_i,

    output logic clk_gen_o
);

logic clk_gen, clk_syn;

logic [W-1:0] rst_cnt;

logic [W-1:0] clk_syn_cnt;
logic [W-1:0] clk_syn_val;
logic [W-1:0] clk_syn_min;

logic [W-1:0] clk_gen_val;
logic [W-1:0] clk_gen_cnt;

logic pos_edge, neg_edge;

wire clk_rst = (rst_cnt >= R - 1'b1);
wire clk_min = (clk_syn_val <= clk_syn_min);
wire clk_ovf = (clk_gen_cnt == clk_gen_val - 1'b1);
logic      pos;              // Output clock
logic      neg;            // Enable signal is asserted for one Clk period before Mdc rises.
logic      clk_out;          // Enable signal is asserted for one Clk period before Mdc falls.
assign clk_gen_o = clk_gen;

data_delay #(.N(1)) clk_ovf_delay(
   .clk_i(clk_i),
   .rst_n_i(rst_n_i),
   .data_i(clk_ovf),
   .data_o(clk_syn)
);

edge_detect data_edge(
   .clk_i(clk_i),
   .rst_n_i(rst_n_i),
   .data_i(data_i),
   .pos_edge_o(pos_edge),
   .neg_edge_o(neg_edge)
);

eth_clockgen eth_clockgen(
	.Clk(clk_i),
	.Reset(rst_n_i),
	.Divider(clk_syn_val),
	.pos(pos),
	.neg(neg),
	.clk_out(clk_out)
);
always_ff @(posedge clk_i or negedge rst_n_i)
begin
    if (!rst_n_i) begin
        clk_gen <= 1'b0;

        rst_cnt <= {W{1'b0}};

        clk_syn_cnt <= {W{1'b0}};
        clk_syn_val <= {W{1'b0}};
        clk_syn_min <= {W{1'b0}};

        clk_gen_val <= {W{1'b0}};
        clk_gen_cnt <= {W{1'b0}};
    end else begin
        clk_gen <= (clk_gen_cnt < clk_gen_val[W-1:1]);

        rst_cnt <= pos_edge & (clk_rst | clk_min) ? {W{1'b0}} : rst_cnt + pos_edge;

        clk_syn_cnt <= pos_edge ? {W{1'b0}} : clk_syn_cnt + 1'b1;
        clk_syn_val <= neg_edge ? clk_syn_cnt + 1'b1 : clk_syn_val;
        clk_syn_min <= pos_edge & (clk_rst | clk_min) ? clk_syn_val : clk_syn_min;

        clk_gen_val <= pos_edge & clk_rst ? clk_syn_min : clk_gen_val;
        clk_gen_cnt <= pos_edge | clk_syn ? {W{1'b0}} : clk_gen_cnt + 1'b1;
    end
end

endmodule
