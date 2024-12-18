
module fifo #(
    parameter DATA_WIDTH = 32,  // Width of data in the FIFO
    parameter DEPTH = 16        // Number of entries in the FIFO
)(
    input wire                 clk,       // Clock signal
    input wire                 reset,     // Reset signal (active high)
    input wire                 wr_en,     // Write enable
    input wire                 rd_en,     // Read enable
    input wire [DATA_WIDTH-1:0] data_in,  // Data to be written
    output reg [DATA_WIDTH-1:0] data_out, // Data read from FIFO
    output wire                empty,     // FIFO empty flag
    output wire                full       // FIFO full flag
);

    // Parameters and constants
    localparam ADDR_WIDTH = $clog2(DEPTH);  // Calculate address width for depth

    // Internal signals
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];  // FIFO memory array
    reg [ADDR_WIDTH:0]   wr_ptr;           // Write pointer
    reg [ADDR_WIDTH:0]   rd_ptr;           // Read pointer
    reg [ADDR_WIDTH:0]   fifo_count;       // Number of elements in the FIFO

    // Assignments for empty and full flags
    assign empty = (fifo_count == 0);
    assign full = (fifo_count == DEPTH);

    // Write operation
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            wr_ptr <= 0;
        end else if (wr_en && !full) begin
            mem[wr_ptr[ADDR_WIDTH-1:0]] <= data_in;
            wr_ptr <= wr_ptr + 1;
        end
    end

    // Read operation
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            rd_ptr <= 0;
            data_out <= 0;
        end else if (rd_en && !empty) begin
            data_out <= mem[rd_ptr[ADDR_WIDTH-1:0]];
            rd_ptr <= rd_ptr + 1;
        end
    end

    // FIFO count logic
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            fifo_count <= 0;
        end else begin
            case ({wr_en && !full, rd_en && !empty})
                2'b10: fifo_count <= fifo_count + 1;  // Write only
                2'b01: fifo_count <= fifo_count - 1;  // Read only
                default: fifo_count <= fifo_count;    // No change
            endcase
        end
    end

endmodule
