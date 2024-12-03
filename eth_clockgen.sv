/*
 * eth_clockgen.sv
 *
 *  Created on: 2024-12-01 
 *      Author: 
 */
 module eth_clockgen(Clk, Reset, Divider, pos, neg, clk_out);

input       Clk;              // Input clock (Host clock)
input       Reset;            // Reset signal
input [7:0] Divider;          // Divider (input clock will be divided by the Divider[7:0])

output      clk_out;              // Output clock
output      pos;            // Enable signal is asserted for one Clk period before clk_out rises.
output      neg;          // Enable signal is asserted for one Clk period before clk_out falls.

reg         clk_out;
reg   [7:0] Counter;

wire        CountEq0;
wire  [7:0] CounterPreset;
wire  [7:0] TempDivider;


assign TempDivider[7:0]   = (Divider[7:0]<2)? 8'h14 : Divider[7:0]; // If smaller than 2
assign CounterPreset[7:0] = (TempDivider[7:0]>>1) - 8'b1;           // We are counting half of period


// Counter counts half period
always @ (posedge Clk or negedge Reset)
begin
  if(!Reset)
    Counter[7:0] <=  8'h1;
  else
    begin
      if(CountEq0)
        begin
          Counter[7:0] <=  CounterPreset[7:0];
        end
      else
        Counter[7:0] <=  Counter - 8'h1;
    end
end


// clk_out is asserted every other half period
always @ (posedge Clk or negedge Reset)
begin
  if(!Reset)
    clk_out <=  1'b0;
  else
    begin
      if(CountEq0)
        clk_out <=  ~clk_out;
    end
end


assign CountEq0 = Counter == 8'h0;
assign pos = CountEq0 & ~clk_out;
assign neg = CountEq0 & clk_out;

endmodule