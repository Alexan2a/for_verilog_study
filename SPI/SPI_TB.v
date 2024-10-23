module spi_tb ();

  reg  clk;
  reg  rst;
  wire MOSI;
  reg  CS_sel;
  reg  valid;
  wire MISO;
  wire CS0;
  wire CS1;
  wire ready;
  wire data_valid;
  reg [14:0] data_in;
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
       valid = 1; //memory 1
       data_in = 15'b100010000001110; // data = 00, addr = 3,  mode = WR
  #200 data_in = 15'b000100010001100; // data = 11, addr = 3,  mode = RD

  #200 data_in = 15'b000000000000010; // data = 00, addr = 0,  mode = WR
  #200 data_in = 15'b000100010000110; // data = 11, addr = 1,  mode = WR
  #200 data_in = 15'b001000100001010; // data = 22, addr = 2,  mode = WR
  #200 data_in = 15'b001100110001110; // data = 33, addr = 3,  mode = WR
  #200 data_in = 15'b010001000010010; // data = 44, addr = 4,  mode = WR
  #200 data_in = 15'b010101010010110; // data = 55, addr = 5,  mode = WR
  #200 data_in = 15'b011001100011010; // data = 66, addr = 6,  mode = WR
  #200 data_in = 15'b011101110011110; // data = 77, addr = 7,  mode = WR
  #200 data_in = 15'b100010000100010; // data = 88, addr = 8,  mode = WR
  #200 data_in = 15'b001100011110110; // data = 31, addr = 29, mode = WR
  #200 CS_sel = 0; //memory 2
       data_in = 15'b101010100000010; // data = AA, addr = 0,  mode = WR
  #200 data_in = 15'b101110110000110; // data = BB, addr = 1,  mode = WR
  #200 data_in = 15'b110011000001010; // data = CC, addr = 2,  mode = WR
  #200 data_in = 15'b110111010001110; // data = DD, addr = 3,  mode = WR
  #200 data_in = 15'b111011100010010; // data = EE, addr = 4,  mode = WR
  #200 data_in = 15'b111111110010110; // data = FF, addr = 5,  mode = WR
  #200 CS_sel = 1; //memory 1
       data_in = 15'b011100101111010; // data = 72, addr = 30, mode = WR
  #200 data_in = 15'b111100111111110; // data = F3, addr = 31, mode = WR
  #200 data_in = 15'b000001010000101; // addr = 1, mode = RD with increment (n = 5), 
  #70  valid = 0;
  #600 data_in = 15'b000011100010010; // data = 0E, addr = 4, mode = WR
       valid = 1;
  #200 data_in = 15'b000011100001100; // data = 33, addr = 3,  mode = RD
  #200 data_in = 15'b000011100001000; // data = 22, addr = 2,  mode = RD
  #200 data_in = 15'b100110010100110; // data = 99, addr = 9,  mode = WR
  #200 data_in = 15'b000010001111001; // addr = 1, mode = RD with increment (n = 8), actually n=2
  #50  CS_sel = 0; //memory 2
  #200 data_in = 15'b000011100001000; // data = CC, addr = 2,  mode = RD;
  #200 data_in = 15'b000001010000001; // addr = 0, mode = RD with increment (n = 5), 
  #200 data_in = 15'b000001010000101; // addr = 1, mode = RD with increment (n = 5), 
  end

  spi_slave i_slave_0(
    .rst(rst),
    .clk(clk),
    .MISO(MISO),
    .CS(CS0),
    .MOSI(MOSI)
  );

  spi_slave i_slave_1(
    .rst(rst),
    .clk(clk),
    .MISO(MISO),
    .CS(CS1),
    .MOSI(MOSI)
  );

  spi_master i_master(
    .rst(rst),
    .clk(clk),
    .MISO(MISO),
    .Data_in(data_in),
    .data_in_valid(valid),
    .CS_Sel(CS_sel),
    .CS0(CS0),
    .CS1(CS1),
    .MOSI(MOSI),
    .data_out_valid(data_valid),
    .Data_out(data_out)
  );

endmodule