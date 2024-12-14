module dual_port_RAM #(parameter N=8, parameter M=32)(
  input  wire         clk,
  input  wire [$clog2(M)-1:0] wr_addr,
  input  wire [$clog2(M)-1:0] rd_addr,
  input  wire [N-1:0] wr_din,
  input  wire         WE,
 // output wire [N-1:0] wr_dout,
  output wire [N-1:0] rd_dout
);

  reg [N-1:0] ram[0:M-1];
  //reg [N-1:0] wr_dout_r;
  reg [N-1:0] rd_dout_r;

 // assign wr_dout = wr_dout_r;
  assign rd_dout = rd_dout_r;

  always @(posedge clk) begin
    if (WE) begin
      //wr_dout_r <= ram[wr_addr];
      ram[wr_addr] <= wr_din;
    end 
    rd_dout_r <= ram[rd_addr];
  end

endmodule