module single_port_RAM #(parameter N=8, parameter M=32)(
  input  wire         clk,
  input  wire         en,
  input  wire         we,
  input  wire [$clog2(M)-1:0] addr,
  input  wire [N-1:0] din,
  output reg  [N-1:0] dout
);

  reg [N-1:0] ram[0:M-1];

  always @(posedge clk) begin
    if (en) begin
      if (we) ram[addr] <= din;
      dout <= ram[addr];
    end
  end

endmodule