module dual_port_RAM #(parameter N=8, parameter M=32)(
  input  wire         clk,
  input  wire         en,
  input  wire [$clog2(M)-1:0] wr_addr,
  input  wire [$clog2(M)-1:0] rd_addr,
  input  wire [N-1:0] wr_din,
  input  wire         we,
  output reg  [N-1:0] rd_dout
);

  reg [N-1:0] ram[0:M-1];

  always @(posedge clk) begin
    if (en) begin
      if (we) begin
        ram[wr_addr] <= wr_din;
      end 
      rd_dout <= ram[rd_addr];
    end
  end

endmodule