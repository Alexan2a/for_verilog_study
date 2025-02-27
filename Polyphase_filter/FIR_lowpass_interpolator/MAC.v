module MAC #(parameter SIZE = 43, parameter SAMPLE_SIZE = 16, parameter COEFF_SIZE = 16)(
  input  wire clk,
  input  wire nrst,
  input  wire en_a,  
  input  wire en_b,
  input  wire mem_en_a,
  input  wire mem_en_b,
  input  wire [COEFF_SIZE-1:0] coeff_a,
  input  wire [COEFF_SIZE-1:0] coeff_b,

  input  wire we,
  input  wire [$clog2(SIZE)-1:0] addr_a,
  input  wire [$clog2(SIZE)-1:0] addr_b,
  input  wire [SAMPLE_SIZE-1:0] mem_in,
  output wire [SAMPLE_SIZE-1:0] mem_out,

  output wire [SAMPLE_SIZE+COEFF_SIZE-1:0] dout_a,
  output wire [SAMPLE_SIZE+COEFF_SIZE-1:0] dout_b
);

  localparam GND = 0;
  
  wire [SAMPLE_SIZE+COEFF_SIZE-1:0] mult_a;
  wire [SAMPLE_SIZE+COEFF_SIZE-1:0] mult_b;
  reg  [SAMPLE_SIZE+COEFF_SIZE-1:0] acc_a;
  reg  [SAMPLE_SIZE+COEFF_SIZE-1:0] acc_b;
  reg  acc_rst;

  wire [SAMPLE_SIZE-1:0] mem_out_a;
  wire [SAMPLE_SIZE-1:0] mem_out_b;

  assign dout_a = acc_a;
  assign dout_b = acc_b;
  assign mem_out = mem_out_a;
  
  true_dual_port_RAM #(SAMPLE_SIZE, SIZE) sample_ram( 
    .clk_a(clk),
    .clk_b(clk),
    .en_a(mem_en_a),
    .en_b(mem_en_b),
    .we_a(we),
    .we_b(GND),
    .addr_a(addr_a),
    .addr_b(addr_b),
    .din_a(mem_in),
    .din_b(GND),
    .dout_a(mem_out_a),
    .dout_b(mem_out_b)
  );

  assign mult_a = ($signed(mem_out_a) * $signed(coeff_a)) >>> 3; //32.30
  assign mult_b = ($signed(mem_out_b) * $signed(coeff_b)) >>> 3; //32.30

  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      acc_a <= 0;
    end else if (en_a) begin 
      acc_a <= $signed(acc_a) + $signed(mult_a); //32.30
    end
  end

  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      acc_b <= 0;
    end else if (en_b) begin 
      acc_b <= $signed(acc_b) + $signed(mult_b); //32.30
    end
  end


endmodule