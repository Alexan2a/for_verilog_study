module single_port_RAM #(parameter N=8, parameter M=32)(
  input  wire         clk,
  input  wire [N-1:0] din,
  input  wire         we,
  input  wire [$clog2(M)-1:0] addr,
  output reg [N-1:0] dout
);

  reg [N-1:0] ram[0:M-1];

  always @(posedge clk) begin
    if (we) ram[addr] <= din;
    else dout <= ram[addr];
  end

endmodule