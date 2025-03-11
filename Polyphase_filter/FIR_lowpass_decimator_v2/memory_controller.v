module memory_controller#(
  parameter MAC_SIZE = 255, 
  parameter D = 100,
  parameter COEFF_SIZE = 16, 
  parameter SAMPLE_SIZE = 16,
  parameter MAC_NUM = 1
)(
  input  wire clk,
  input  wire sample_we,
  input  wire sample_en,
  input  wire coeff_en,
  input  wire [$clog2(MAC_SIZE)-1:0] sample_addr,
  input  wire [$clog2(MAC_SIZE)-1:0] coeff_addr,
  input  wire [SAMPLE_SIZE-1:0] s_in,

  input  wire c_we,
  input  wire [COEFF_SIZE-1:0] c_in,
  input  wire [$clog2(MAC_SIZE)-1:0] c_addr,

  output reg  [SAMPLE_SIZE*MAC_NUM-1:0] s_out,
  output reg  [COEFF_SIZE*MAC_NUM-1:0] c_out

);

  reg  [MAC_NUM-1:0] coeff_we;
  reg  [$clog2(MAC_SIZE)-1:0] coeff_dec_addr;
  wire [$clog2(MAC_SIZE)-1:0] coeff_addr_mod;
  
  wire [SAMPLE_SIZE-1:0] samples [0:MAC_NUM];
  wire [COEFF_SIZE-1:0] coeffs [0:MAC_NUM];

  assign coeff_addr_mod = (c_we) ? coeff_dec_addr : coeff_addr;

  integer j,k;

  //coeff adresses decoder (according to c_addr)
  always @(*) begin
    coeff_we = 0;
    coeff_dec_addr = 0;
    for (j = 0; j < MAC_SIZE; j = j+1) begin
      for (k = 0; k < MAC_NUM; k = k+1) begin
        if (c_addr == j+k*MAC_SIZE) begin
          coeff_dec_addr = j;
          coeff_we = (c_we) ? 1 << k : 0;
        end
      end
    end
  end

  always @(*) begin
    for (j = 0; j < MAC_NUM; j = j+1) begin
      s_out[j*SAMPLE_SIZE +: SAMPLE_SIZE+COEFF_SIZE] = samples[j+1];
      c_out[j*COEFF_SIZE +: COEFF_SIZE] = coeffs[j];
    end
  end

  assign samples[0] = s_in;
  
  genvar i;
  generate
    for(i = 0; i < MAC_NUM; i = i + 1) begin
     dual_port_RAM #(SAMPLE_SIZE, MAC_SIZE) i_sample_ram(
       .clk(clk),
       .en(sample_en),
       .wr_addr(sample_addr),
       .rd_addr(sample_addr),
       .wr_din(samples[i]),
       .we(sample_we),
       .rd_dout(samples[i+1])
     );
     single_port_RAM #(COEFF_SIZE, MAC_SIZE) i_coeff_ram(
       .clk(clk),
       .en(coeff_en),
       .we(coeff_we[i]),
       .addr(coeff_addr_mod),
       .din(c_in),
       .dout(coeffs[i])
     );
    end
  endgenerate

endmodule