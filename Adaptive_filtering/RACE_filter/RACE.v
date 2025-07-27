module RACE #(
  parameter L = 7,
  parameter BETA_SHIFT = 4,
  parameter IN_SIZE = 16,
  parameter OUT_SIZE = 16,
  parameter COEFF_WH = 20,
  parameter COEFF_FR = 19,
  parameter EXP_IN_WH = 32,
  parameter EXP_IN_FR = 30,
  parameter EXP_VAL_WH = 32,
  parameter EXP_VAL_FR = 30
)(
  input  wire clk,
  input  wire nrst,
  input  wire strobe_resync,
  input  wire valid_in,
  input  wire [IN_SIZE-1:0] in_real,
  input  wire [IN_SIZE-1:0] in_imag,
  output wire [OUT_SIZE-1:0] out_real,
  output wire [OUT_SIZE-1:0] out_imag,
  output reg  data_ready
);
  
  wire [COEFF_WH-1:0] rxx_real;
  wire [COEFF_WH-1:0] rxx_imag;
  reg  [COEFF_WH-1:0] rxx;

  reg  en;
  reg  dr0, dr1;
  wire acc_rst;
  reg  acc_en;
  reg  [$clog2(2*L+1)-1:0] sel_cnt;
  
  //obviously enable blocks
  //en is active while sel_cnt counts to the 2*L+1
  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      en <= 1'b0;
    end else if (sel_cnt == 0 && valid_in) begin
      en <= 1'b1;
    end else if (sel_cnt == 2*L+1) begin
      en <= 1'b0;
    end
  end

  always @(posedge clk) begin
    acc_en <= en;
  end

  assign acc_rst = (sel_cnt == 2);

  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      dr0 <= 1'b0;
    end else begin
      dr0 <= (sel_cnt == 2*L) ? 1'b1 : 1'b0;
    end
  end

 //data_ready reflects that mac data is ready
  always @(posedge clk) begin
    dr1 <= dr0;
    data_ready <= dr1;
  end

 //just for selection of input taps, counts from 0 to 2*L+1
  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      sel_cnt <= 0;
    end else begin
      if (strobe_resync) begin 
        sel_cnt <= 0;
      end else if (sel_cnt == 2*L+1) begin
        sel_cnt <= 2*L+1;
      end else sel_cnt <= sel_cnt + 1;
    end
  end

  //count average from imaginary and real rxx to use as coeffitients)))
  always @(posedge clk) begin
    rxx <= $signed($signed(rxx_real) + $signed(rxx_imag) + 1) >>> 1;
  end
  
  RACE_part #(L, BETA_SHIFT, IN_SIZE, OUT_SIZE, COEFF_WH, COEFF_FR, EXP_IN_WH, EXP_IN_FR, EXP_VAL_WH, EXP_VAL_FR) i_RACE_real(
    .clk(clk),
    .nrst(nrst),
    .en(en),
    .acc_en(acc_en),
    .acc_rst(acc_rst),
    .strobe_resync(strobe_resync),
    .sel(sel_cnt),
    .in(in_real),
    .in_rxx(rxx),
    .out(out_real),
    .out_rxx(rxx_real)
  );

  RACE_part #(L, BETA_SHIFT, IN_SIZE, OUT_SIZE, COEFF_WH, COEFF_FR, EXP_IN_WH, EXP_IN_FR, EXP_VAL_WH, EXP_VAL_FR) i_RACE_imag(
    .clk(clk),
    .nrst(nrst),
    .en(en),
    .acc_en(acc_en),
    .acc_rst(acc_rst),
    .strobe_resync(strobe_resync),
    .sel(sel_cnt),
    .in(in_imag),
    .in_rxx(rxx),
    .out(out_imag),
    .out_rxx(rxx_imag)
  );
  
endmodule