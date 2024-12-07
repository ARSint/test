module csr_fifo_interface (
    input wire PCLK,
    input wire PRESETn,
    input wire csr_write,
    input wire csr_read,
    input wire [7:0] csr_addr,
    input wire [31:0] csr_wdata,
    output reg [31:0] csr_rdata,
    output reg csr_ready,
    output reg csr_error,

    // FIFO Interface
    output reg fifo_push,
    output reg fifo_pop,
    output reg [31:0] fifo_wdata,
    input wire [31:0] fifo_rdata,
    input wire fifo_empty,
    input wire fifo_full
);

    // CSR Registers
    reg [31:0] header_reg;
    reg [31:0] length_reg;
    reg [31:0] rwdata_reg;
    reg [31:0] status_reg;

    // CSR Operations
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            header_reg <= 0;
            length_reg <= 0;
            rwdata_reg <= 0;
            status_reg <= 0;
            fifo_push <= 0;
            fifo_pop <= 0;
            csr_ready <= 1;
            csr_error <= 0;
        end else begin
            fifo_push <= 0;
            fifo_pop <= 0;
            csr_ready <= 1;

            if (csr_write) begin
                case (csr_addr)
                    8'h00: header_reg <= csr_wdata;
                    8'h01: length_reg <= csr_wdata;
                    8'h03: begin
                        rwdata_reg <= csr_wdata;
                        if (!fifo_full) fifo_push <= 1; // Push to FIFO
                        else csr_error <= 1;
                    end
                    8'h04: status_reg <= csr_wdata;
                endcase
            end else if (csr_read) begin
                case (csr_addr)
                    8'h00: csr_rdata <= header_reg;
                    8'h01: csr_rdata <= length_reg;
                    8'h03: begin
                        if (!fifo_empty) begin
                            csr_rdata <= fifo_rdata;
                            fifo_pop <= 1; // Pop from FIFO
                        end else csr_error <= 1;
                    end
                    8'h04: csr_rdata <= status_reg;
                endcase
            end
        end
    end
endmodule
