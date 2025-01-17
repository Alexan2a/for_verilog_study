module iir_sos #(
  parameter SAMP_WH = 4,
  parameter SAMP_FR = 23,
  parameter COEFF_WH = 2,
  parameter COEFF_FR = 14,
  parameter K_WH = 1,
  parameter K_FR = 15,
  parameter REC_WH = 8,
  parameter REC_FR = 24
) (
  input  wire nrst,
  input  wire clk,
  input  wire ce,

  input  wire mult_sel,

  input  wire c_we,
  input  wire [1:0] c_addr,
  input  wire [COEFF_WH+COEFF_FR-1:0] c_in,

  input  wire [SAMP_WH+SAMP_FR-1:0] din,
  output wire [SAMP_WH+SAMP_FR-1:0] dout
);

  reg ce_del;
  
  always @(posedge clk) begin
    ce_del <= ce;
  end
  
  wire ce_end;
  
  assign ce_end = !(ce || !ce_del);

  reg  [COEFF_FR-1:0] a_lsb [0:1];
  wire [COEFF_FR-1:0] sel_a_lsb;
  
  reg  [COEFF_WH+COEFF_FR-1:0] a_coeff [0:1];
  reg  [COEFF_WH+COEFF_FR-1:0] b_coeff;
  reg  [COEFF_WH+COEFF_FR-1:0] K_coeff;
  wire [COEFF_WH+COEFF_FR-1:0] sel_coeff;  

  wire [REC_WH+REC_FR-1:0] sum_a;
  reg  [REC_WH+REC_FR-1:0] sum_a_del_0;
  reg  [REC_WH+REC_FR-1:0] sum_a_del_1;
  wire [REC_WH+REC_FR-1:0] sel_sum_a_del;

  reg  [COEFF_FR+REC_WH+REC_FR-1:0] a_prod;
  wire [COEFF_FR+REC_WH+REC_FR-1:0] a_prod_lsb;
  wire [COEFF_FR+REC_WH+REC_FR-1:0] b_prod;

  wire [REC_WH+REC_FR-1:0] a_prod_conv;
  reg  [REC_WH+REC_FR-1:0] b_prod_conv;
  reg  [REC_WH+REC_FR-1:0] acc;

  wire [REC_WH+REC_FR-1:0]   out;
  reg  [SAMP_WH+SAMP_FR-1:0] out_r;

  wire [SAMP_WH+SAMP_FR+K_WH+K_FR-1:0] K_prod;
  reg  [SAMP_WH+SAMP_FR-1:0] K_din;
  
  assign dout = out_r;

  

  assign K_prod = $signed(K_coeff)*$signed(din);
 // assign K_din = ({{(REC_WH-SAMP_WH-K_WH){K_prod[SAMP_WH+SAMP_FR+K_WH+K_FR-1]}}, K_prod[SAMP_WH+SAMP_FR+K_WH+K_FR-1 -: SAMP_WH+K_WH+REC_FR+1]}+1)>>>1;

  assign sel_sum_a_del = (mult_sel) ? sum_a_del_1 : sum_a_del_0;
  assign sel_coeff     = (mult_sel) ? a_coeff[1] : a_coeff[0];
  assign sel_a_lsb     = (mult_sel) ? a_lsb[0] : a_lsb[1];

  assign a_prod_lsb = $signed(a_prod)+$signed(sel_a_lsb);
  assign b_prod = $signed(sum_a_del_0)*$signed(b_coeff);

  assign a_prod_conv = (a_prod_lsb[REC_WH+REC_FR+COEFF_FR-1 -: REC_WH+REC_FR+1]+1)>>>1;
  //assign b_prod_conv = (b_prod[REC_WH+REC_FR+COEFF_FR-1 -: REC_WH+REC_FR+1]+1)>>>1;

  assign sum_a = $signed(K_din)+$signed(acc);
  assign out = $signed(sum_a)+$signed(b_prod_conv)+$signed(sum_a_del_1);

  always @(posedge clk) begin
      a_prod <= $signed(sel_sum_a_del)*$signed(sel_coeff);
      b_prod_conv <= (b_prod[REC_WH+REC_FR+COEFF_FR-1 -: REC_WH+REC_FR+1]+1)>>>1;
      K_din <= ({{(REC_WH-SAMP_WH-K_WH){K_prod[SAMP_WH+SAMP_FR+K_WH+K_FR-1]}}, K_prod[SAMP_WH+SAMP_FR+K_WH+K_FR-1 -: SAMP_WH+K_WH+REC_FR+1]}+1)>>>1;
  end

  always @(posedge clk) begin
    if (c_we) begin
      case(c_addr)
         2'b00: a_coeff[0] <= c_in;
         2'b01: a_coeff[1] <= c_in;
         2'b10: b_coeff    <= c_in;
         2'b11: K_coeff    <= c_in;
         default: begin
         end
      endcase
    end
  end

  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
        sum_a_del_0 <= 0;
        sum_a_del_1 <= 0;
    end else if (ce_end) begin
        sum_a_del_0 <= sum_a;
        sum_a_del_1 <= sum_a_del_0;
    end
  end

  //assign acc_rst = nrst && ce;
  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      acc <= 0;
    end else begin
      if (ce) acc <= $signed(acc) + $signed(a_prod_conv);
      else acc <= 0;
    end
  end

  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      a_lsb[0] <= 0;
      a_lsb[1] <= 0;
    end else if (ce) begin
      if (mult_sel) a_lsb[0] <= a_prod_lsb[COEFF_FR-1:0];
      else a_lsb[1] <= a_prod_lsb[COEFF_FR-1:0];
    end
  end

  always @(posedge clk) begin
    if (ce_end) begin
      out_r <= (out[REC_WH+REC_FR-1] == 1 && ~&out[REC_WH+REC_FR-2 -: REC_WH-SAMP_WH]) ? 2**(SAMP_WH+SAMP_FR-1)   :
               (out[REC_WH+REC_FR-1] == 0 &&  |out[REC_WH+REC_FR-2 -: REC_WH-SAMP_WH]) ? 2**(SAMP_WH+SAMP_FR-1)-1 :
               (out[SAMP_WH+REC_FR-1 -: SAMP_WH+SAMP_FR+1]+1)>>>1;
    end
  end

endmodule