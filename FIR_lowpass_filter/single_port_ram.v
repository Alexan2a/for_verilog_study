module single_port_RAM #(parameter N=8, parameter M=32)(
  input  wire         clk,
  input  wire [N-1:0] din,
  input  wire         WE,
  input  wire [$clog2(M)-1:0] addr,
  output wire [N-1:0] dout
);

  reg [N-1:0] ram[0:M-1];
  reg [N-1:0] dout_r;

  assign dout = dout_r;

  always @(posedge clk) begin
    if (!WE) dout_r <= ram[addr];
    else ram[addr] <= din;
  end

endmodule