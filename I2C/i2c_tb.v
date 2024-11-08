module tb();
  reg        clk;
  reg        rst;
  reg        en;
  reg        rw;
  reg  [6:0] addr;
  reg  [4:0] mem_addr;
  reg  [7:0] data_wr;
  wire [7:0] data_rd;
  wire       ack_err;
  wire       busy;
  tri        sda;
  tri        scl;

  parameter A = 1;
  parameter B = 2;
  parameter N = 8;
  parameter M = 32;

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

 initial begin
     rst = 1;
  #5 rst = 0;
  #5 rst = 1;
  end

 initial begin
       en = 0;
  #30  en = 1;
  #10  en = 0;
  #300 en = 1;
 end

 initial begin
  #26 addr = 1;
      rw = 1;
      mem_addr = 0;
      data_wr = 8'h00;

  #280 mem_addr = 1;
       data_wr = 8'h11;

  #280 mem_addr = 2;
       data_wr = 8'h22;

  #280 mem_addr = 3;
       data_wr = 8'h33;

  #280 mem_addr = 0;
       data_wr = 8'hAA;
       addr = 2;

  #280 mem_addr = 2;
       data_wr = 8'hCC;

  #280 mem_addr = 1;
       data_wr = 8'hBB;

  #280 mem_addr = 3;
       data_wr = 8'hDD;

  #280 mem_addr = 5;
       data_wr = 8'hFF;

  #280 mem_addr = 4;
       data_wr = 8'hEE;

  #280 mem_addr = 4;
       data_wr = 8'h44;
       addr = 1;

  #280 mem_addr = 5;
       data_wr = 8'h55;

  #280 mem_addr = 6;
       data_wr = 8'h66;
 
  #280 mem_addr = 7;
       data_wr = 8'h77;

  #280 mem_addr = 8;
       data_wr = 8'h88;

  #280 rw = 0;

  #280 mem_addr = 3;

  #280 mem_addr = 5;

  #280 mem_addr = 0;
       addr = 2;

  #280 mem_addr = 1;

  #280 mem_addr = 2;
 end


  i2c_master i_master(
    .clk(clk),
    .rst(rst),
    .en(en),
    .addr(addr),
    .rw(rw),
    .mem_addr(mem_addr),
    .data_wr(data_wr),
    .data_rd(data_rd),
    .ack_err(ack_err),
    .busy(busy),
    .sda(sda),
    .scl(scl)
  );

  i2c_slave #(A) i_slave_0(
    .clk(clk),
    .rst(rst),
    .scl(scl),
    .sda(sda)
  );

  i2c_slave #(B) i_slave_1(
    .clk(clk),
    .rst(rst),
    .scl(scl),
    .sda(sda)
  );

endmodule