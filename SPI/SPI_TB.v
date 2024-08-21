module spi_tb ();

  reg        clk;
  reg        rst;
  reg        CS_sel;
  reg        valid;
  reg [13:0] data_in;
  wire       MISO;
  wire       CS;
  wire       ready;
  wire       MOSI;
  wire [7:0] ram_in;
  wire [7:0] ram_out;
  wire [7:0] data_out;
  wire [4:0] addr;
  wire       mode;
  
  parameter N=8;
  parameter M=32;

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin
     CS_sel = 1;
     rst = 1;
  #5 rst = 0;
  #5 rst = 1;
  end

  initial begin
   data_in = 14'b00000000000100;
   valid = 1;
  #50 valid = 0;
   data_in = 14'b00001110001001;
  #230 valid = 1;
  end

  RAM #(N,M) i_ram(
    .clk(clk),
    .Data_in(ram_in),
    .WE(mode),
    .Addr(addr),
    .Data_out(ram_out)
  );

  spi_slave_ctrl i_slave(
    .rst(rst),
    .clk(clk),
    .MISO(MISO),
    .CS(CS),
    .Data_in(ram_out),
    .MOSI(MOSI),
    .Data_out(ram_in),
    .Addr(addr),
    .Mode(mode)
);

  spi_master i_master(
    .rst(rst),
    .clk(clk),
    .MISO(MISO),
    .Data_in(data_in),
    .tx_valid(valid),
    .CS_Sel(CS_sel),
    .CS0(CS),
    .CS1(),
    .MOSI(MOSI),
    .rx_ready(ready),
    .Data_out(data_out)
);

endmodule
