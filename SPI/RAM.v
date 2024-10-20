module RAM #(parameter N=8, parameter M=32)(
  input  wire         clk,
  input  wire [N-1:0] Data_in,
  input  wire         WE,
  input  wire [$clog2(M)-1:0] Addr,
  output wire [N-1:0] Data_out
);

  reg [N-1:0] ram[0:M-1];
  reg [N-1:0] d_out;
  assign Data_out = d_out;

  always @(posedge clk) begin
    if (!WE) d_out <= ram[Addr];
    else ram[Addr] <= Data_in;
  end

endmodule