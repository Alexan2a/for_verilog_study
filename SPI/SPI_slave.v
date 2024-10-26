module spi_slave (
  input  wire rst,
  input  wire clk,
  input  wire MOSI,
  input  wire CS,
  output wire MISO
);

  wire [7:0] ram_out;
  wire [7:0] ram_in;
  wire [4:0] addr;
  wire       WE;

  parameter N=8;
  parameter M=32;

  spi_slave_ctrl i_slave_ctrl(
    .rst(rst),
    .clk(clk),
    .MISO(MISO),
    .CS(CS),
    .Data_in(ram_out),
    .MOSI(MOSI),
    .Data_out(ram_in),
    .Addr(addr),
    .WE(WE)
  );

  RAM #(N,M) i_ram(
    .clk(clk),
    .Data_in(ram_in),
    .WE(WE),
    .Addr(addr),
    .Data_out(ram_out)
  );

endmodule