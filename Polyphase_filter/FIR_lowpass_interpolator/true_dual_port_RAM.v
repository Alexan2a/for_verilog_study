module true_dual_port_RAM #(parameter N = 8, parameter M = 32)(
  input wire clk_a,
  input wire clk_b,
  input wire en_a,
  input wire en_b,
  input wire we_a,
  input wire we_b,
  input wire [$clog2(M)-1:0] addr_a,
  input wire [$clog2(M)-1:0] addr_b,
  input wire [N-1:0] din_a,
  input wire [N-1:0] din_b,
  output reg [N-1:0] dout_a,
  output reg [N-1:0] dout_b
);

  reg [N-1:0] ram [0:M-1];

  always @(posedge clk_a) begin
    if (en_a) begin
      if (we_a) ram[addr_a] <= din_a;
      dout_a <= ram[addr_a];
    end
  end

  always @(posedge clk_b) begin
    if (en_b) begin
      if (we_b) ram[addr_b] <= din_b;
      dout_b <= ram[addr_b];
    end
  end

endmodule