module MAC #(parameter SIZE = 43, parameter SAMPLE_SIZE = 16, parameter COEFF_SIZE = 16)(
  input  wire clk,
  input  wire nrst,
  input  wire en,

  input  wire c_we,
  input  wire c_en,
  input  wire [$clog2(SIZE)-1:0] c_addr,
  input  wire [SAMPLE_SIZE-1:0] c_in,

  input  wire s_we,
  input  wire s_en,
  input  wire [$clog2(SIZE)-1:0] s_addr,
  input  wire [SAMPLE_SIZE-1:0] s_in,
  output wire [SAMPLE_SIZE-1:0] s_out,

  output wire [SAMPLE_SIZE+COEFF_SIZE-1:0] dout
);

  localparam GND = 0;
  
  wire [SAMPLE_SIZE+COEFF_SIZE-1:0] mult;
  reg  [SAMPLE_SIZE+COEFF_SIZE-1:0] acc;
  reg  acc_rst;

 // wire [SAMPLE_SIZE-1:0] s_mem_out;
  wire [COEFF_SIZE-1:0]  c_out;

  assign dout = acc;
//  assign s_out = s_mem_out;

  dual_port_RAM #(SAMPLE_SIZE, SIZE) sample_ram(
    .clk(clk),
    .en(s_en),
    .wr_addr(s_addr),
    .rd_addr(s_addr),
    .wr_din(s_in),
    .we(s_we),
    .rd_dout(s_out)
  );


  single_port_RAM #(COEFF_SIZE, SIZE) coeff_ram(
    .clk(clk),
    .en(c_en),
    .we(c_we),
    .addr(c_addr),
    .din(c_in),
    .dout(c_out)
  );

  assign mult = ($signed(s_out) * $signed(c_out)) >>> 3; //32.30

  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      acc <= 0;
    end else if (en) begin 
      acc <= $signed(acc) + $signed(mult); //32.30
    end
  end


endmodule