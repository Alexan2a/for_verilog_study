module i2c_slave #(parameter ADDR=0)(
  input  wire clk,
  input  wire rst,

//  input  wire scl,
  input  wire scl_i,
  output wire scl_o,
  output wire scl_t,
  input  wire sda_i,
  output wire sda_o,
  output wire sda_t
);

  localparam N = 8;
  localparam M = 32;

  wire [7:0] d_out;
  wire [7:0] d_in;
  wire [4:0] m_addr;
  wire       WE;

  i2c_slave_contr #(ADDR) i_slave(
    .clk(clk),
    .rst(rst),
    .scl_i(scl_i),
    .scl_o(scl_o),
    .scl_t(scl_t),
    .sda_i(sda_i),
    .sda_o(sda_o),
    .sda_t(sda_t),
    .data_out(d_out),
    .WE(WE),
    .mem_addr(m_addr),
    .data_in(d_in)
  );

  RAM #(N,M) i_ram(
    .clk(clk),
    .Data_in(d_out),
    .WE(WE),
    .Addr(m_addr),
    .Data_out(d_in)
  );

endmodule