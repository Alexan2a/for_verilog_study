module iir #(
  parameter ORD = 10, 
  parameter SAMP_WH = 4,
  parameter SAMP_FR = 23,
  parameter COEFF_WH = 2,
  parameter COEFF_FR = 14,
  parameter K_WH = 1,
  parameter K_FR = 15,
  parameter D = 52
) (
  input  wire clk,
  input  wire nrst,

  input  wire c_we,
  input  wire [COEFF_WH+COEFF_FR-1:0] c_in,
  input  wire [$clog2(ORD*2)-1:0] c_addr,

  input  wire [15:0] din,
  output wire [SAMP_FR:0] dout
);

  wire clk_fs; 

  clock_divider #(D) i_clk_div(
    .in_clk(clk), 
    .rst(nrst),
    .out_clk(clk_fs)
  );

  localparam SOS_NUM = ORD / 2;

  reg [K_WH+K_FR-1:0] K [0:SOS_NUM-1];

  reg cnt;
  reg [4:0] sos_cnt;
  
  wire [SAMP_WH+SAMP_FR-1:0] sos_outs[0:SOS_NUM];
  reg  [SOS_NUM-1:0] sos_ce;
  reg  [SOS_NUM-1:0] sos_c_we;
  reg  [1:0] sos_c_addr;

  assign sos_outs[0] = {{(SAMP_WH+SAMP_FR-16){din[15]}}, din} << (SAMP_FR-15);

  localparam OVF = 2 ** SAMP_FR;
  assign dout = (sos_outs[SOS_NUM][SAMP_WH+SAMP_FR-1] == 1 && ~&sos_outs[SOS_NUM][SAMP_WH+SAMP_FR-2 -: SAMP_WH-1]) ? OVF   :
                (sos_outs[SOS_NUM][SAMP_WH+SAMP_FR-1] == 0 &&  |sos_outs[SOS_NUM][SAMP_WH+SAMP_FR-2 -: SAMP_WH-1]) ? OVF-1 :
                 sos_outs[SOS_NUM][SAMP_FR:0];

  //as clk but restarts on clk_fs
  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      cnt <= 1'b0;
    end else if (!c_we) begin
      if (clk_fs) cnt <= 0;
      else cnt <= !cnt;
    end
  end

  //counts to SOS_NUM, restarts on clk_fs
  always @(negedge clk or negedge nrst) begin
    if (!nrst) begin
      sos_cnt <= 1'b0;
    end else if (!c_we) begin
      if (clk_fs) sos_cnt <= 0;
      else if (sos_cnt == SOS_NUM) sos_cnt <= SOS_NUM;
      else if (cnt == 1) sos_cnt = sos_cnt + 1;
    end
  end
  
  //enable SOS number == sos_cnt
  always @(*) begin //or maybe "for" cycle
    if (c_we) sos_ce = 0;
    else sos_ce = 1 << sos_cnt;
  end

  integer j;

  //write enable sos number == sos_cnt, c_addr decoder for sos coeffs
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

  //c_addr decoder for K coeffs
  always @(posedge clk or negedge nrst) begin
    if (c_we) begin
      for (j = 0; j < SOS_NUM; j = j+1) begin
        if (c_addr == SOS_NUM*3+j) K[j] = c_in;
      end
    end
  end

  reg [SAMP_WH+SAMP_FR+K_WH+K_FR-1:0] K_prods [0:SOS_NUM-1];
  reg [SAMP_WH+SAMP_FR-1:0] sos_ins [0:SOS_NUM-1];

  always @(*) begin //overflow check needed
    for (j = 0; j < SOS_NUM; j = j+1) begin
      K_prods[j] = $signed(K[j])*$signed(sos_outs[j]);
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
        .din(sos_ins[i]),
        .dout(sos_outs[i+1])
      );
    end
  endgenerate

endmodule