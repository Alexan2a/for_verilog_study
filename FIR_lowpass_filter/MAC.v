module MAC #(parameter SIZE = 43, parameter COEFF_SIZE = 16, parameter SAMPLE_SIZE = 16, parameter DISC = 52)(
  input  wire clk,
  input  wire rst,
  input  wire WE,
  input  wire c_WE,
  input  wire en,

  input  wire [COEFF_SIZE-1:0] c_in,
  input  wire [$clog2(SIZE)-1:0] c_addr,

  input  wire [$clog2(SIZE)-1:0] wr_addr_0,
  input  wire [$clog2(SIZE)-1:0] wr_addr_1,
  input  wire [$clog2(SIZE)-1:0] rd_addr_0,
  input  wire [$clog2(SIZE)-1:0] rd_addr_1,

  input  wire [SAMPLE_SIZE-1:0] mem_in_0,
  input  wire [SAMPLE_SIZE-1:0] mem_in_1,

  output wire [SAMPLE_SIZE-1:0] mem_out_0,
  output wire [SAMPLE_SIZE-1:0] mem_out_1,

  output wire [SAMPLE_SIZE-1:0] dout
);

  reg [SAMPLE_SIZE-1:0] dout_r;
  reg [SAMPLE_SIZE:0] sum;
  reg [SAMPLE_SIZE+COEFF_SIZE:0] mult;
  reg [SAMPLE_SIZE+COEFF_SIZE:0] acc;
  reg acc_rst;
  wire [COEFF_SIZE-1:0] c_out;
  wire i_clk;
  assign i_clk = (en) ? clk : 1'b0;
  assign dout =  acc[SAMPLE_SIZE*2 - 2 -: SAMPLE_SIZE]; 

  dual_port_RAM #(SAMPLE_SIZE, SIZE) sample_ram_0(
    .clk(i_clk),
    .wr_addr(wr_addr_0),
    .rd_addr(rd_addr_0),
    .wr_din(mem_in_0),
    .WE(WE),
    .rd_dout(mem_out_0)
  );

  dual_port_RAM #(SAMPLE_SIZE, SIZE) sample_ram_1(
    .clk(i_clk),
    .wr_addr(wr_addr_1),
    .rd_addr(rd_addr_1),
    .wr_din(mem_in_1),
    .WE(WE),
    .rd_dout(mem_out_1)
  );

  single_port_RAM #(COEFF_SIZE, SIZE) coeff_ram(
    .clk(i_clk),
    .addr(c_addr),
    .din(c_in),
    .WE(c_WE),
    .dout(c_out)
  );

  always @(*) begin
    sum = $signed(mem_out_0) + $signed(mem_out_1); //17.15
    mult = ($signed(sum) * $signed(c_out)) >>> 3; //33.30
  end

  always @(posedge i_clk) begin
    acc_rst <= WE;
  end

  always @(posedge i_clk) begin
    if (acc_rst) begin
      acc <= 0;
    end else begin 
      acc <= $signed(acc) + $signed(mult); //33.30
    end
  end


endmodule