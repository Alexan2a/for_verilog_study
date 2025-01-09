module iir #(parameter ORD = 10, SAMP_WH = 3, SAMP_FR = 22, COEFF_WH = 2, COEFF_FR = 15, K_WH = 1, K_FR = 16, D = 52) (
  input clk,
  input nrst,

  input c_we,
  input [COEFF_WH+COEFF_FR-1:0] c_in,
  input  [$clog2(ORD/2*3)-1:0] c_addr,

  input  [SAMP_WH+SAMP_FR-1:0] din,
  output [SAMP_WH+SAMP_FR-1:0] dout
);


  wire clk_fs; 

  clock_divider #(D) i_clk_div(
    .in_clk(clk), 
    .rst(nrst),
    .out_clk(clk_fs)
  );

  localparam SOS_NUM = ORD / 2;

////////////////////////////
//  FOR TESTING

  wire [K_WH+K_FR-1:0] K [0:SOS_NUM-1];
  assign K[0] = 17'h0A192;
  assign K[1] = 17'h06007;
  assign K[2] = 17'h01C98;
  assign K[3] = 17'h001EB;
  assign K[4] = 17'h0C499;
  

////////////////////////////

  reg cnt;
  reg [4:0] sos_cnt;
  
  wire [SAMP_WH+SAMP_FR-1:0] sos_samples[0:SOS_NUM];
  reg  [SOS_NUM-1:0] sos_ce;
  reg  [SOS_NUM-1:0] sos_c_we;
  reg  [1:0] sos_c_addr;

  assign sos_samples[0] = {{2{din[15]}}, din};
  assign dout = sos_samples[SOS_NUM][SAMP_WH+SAMP_FR-1:0];

  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      cnt <= 1'b0;
    end else if (!c_we) begin
      if (clk_fs) cnt <= 0;
      else cnt <= !cnt;
    end
  end

  always @(negedge clk or negedge nrst) begin
    if (!nrst) begin
      sos_cnt <= 1'b0;
    end else if (!c_we) begin
      if (clk_fs) sos_cnt <= 0;
      else if (sos_cnt == SOS_NUM) sos_cnt <= SOS_NUM;
      else if (cnt == 1) sos_cnt = sos_cnt + 1;
    end
  end

  always @(*) begin //or maybe "for" cycle
    if (c_we) sos_ce = 0;
    else sos_ce = 1 << sos_cnt;
  end

  integer j;
  always @(*) begin
    if (c_addr >= SOS_NUM*3) begin
      sos_c_we = 0;
    end else begin
      for (j = 0; j < SOS_NUM*3; j = j+3) begin
        if (c_addr >= j && c_addr < j+3) begin
          sos_c_we = 0;
          sos_c_we[j/3] = 1;
          sos_c_addr = c_addr - j;
        end
      end
    end
  end

  reg [SAMP_WH+SAMP_FR+K_WH+K_FR-1:0] K_prods [0:SOS_NUM-1];
  reg [SAMP_WH+SAMP_FR-1:0] sos_ins [0:SOS_NUM-1];

  always @(*) begin
    for (j = 0; j < SOS_NUM; j = j+1) begin
      K_prods[j] = $signed(K[j])*$signed(sos_samples[j]);
      sos_ins[j] = (K_prods[j][SAMP_WH+SAMP_FR+K_FR-1 -: SAMP_WH+SAMP_FR+1]+1)>>>1;
    end
  end

  genvar i;
  generate
    for(i = 0; i < SOS_NUM; i = i + 1) begin
      iir_sos i_iir_sos(
        .nrst(nrst),
        .clk(clk),
        .ce(sos_ce[i]),
        .mult_sel(cnt),
        .c_we(sos_c_we[i]),
        .c_in(c_in),
        .c_addr(sos_c_addr),
        .din(sos_ins[i]), //round
        .dout(sos_samples[i+1])
      );
    end
  endgenerate

endmodule