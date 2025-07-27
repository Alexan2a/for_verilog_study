module RACE_top #(
  parameter L = 7,
  parameter ALPHA_SHIFT = 5,
  parameter BETA_SHIFT = 4,
  parameter SAMPLE_SIZE = 16,
  parameter COEFF_WH = 20,
  parameter COEFF_FR = 19,
  parameter EXP_IN_WH = 32,
  parameter EXP_IN_FR = 30,
  parameter EXP_VAL_WH = 32,
  parameter EXP_VAL_FR = 30,
  parameter AGC_WH = 16,
  parameter AGC_FR = 15,
  parameter GAIN_WH = 16,
  parameter GAIN_FR = 8
)(
  input  wire clk,
  input  wire nrst,
  input  wire strobe,
  input  wire valid_in,
  output reg  valid_out,
  input  wire [SAMPLE_SIZE-1:0] in_real,
  input  wire [SAMPLE_SIZE-1:0] in_imag,
  output reg  [SAMPLE_SIZE-1:0] out_real,
  output reg  [SAMPLE_SIZE-1:0] out_imag
);

  //WARNING! IF frequency of input data is lower than work frequency in less than 20 times,
  //         then uncomment valid_in_reg_prev and use valid_out <= valid_in_reg_prev

  wire strobe_resync;
  reg  q0, q1, q2;

  reg  valid_in_reg;
 // reg  valid_in_reg_prev;

  wire [SAMPLE_SIZE-1:0] mac_out_real;
  wire [SAMPLE_SIZE-1:0] mac_out_imag;

  wire [SAMPLE_SIZE-1:0] agc_out_real;
  wire [SAMPLE_SIZE-1:0] agc_out_imag;
 
  wire data_ready;
  
  // synchronizator
  // catches negedge activating strobe_resync;
  always @(posedge clk) begin
    q0 <= strobe;
    q1 <= q0;
    q2 <= q1;
  end

  reg strobe_resync_del_0, strobe_resync_del_1;
  reg gain_en;

  always @(posedge clk) begin
    strobe_resync_del_0 <= strobe_resync;
    strobe_resync_del_1 <= strobe_resync_del_0;
    gain_en  <= (strobe_resync_del_1 & valid_in_reg);
  end

  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      valid_in_reg <= 1'b0;
 //   valid_in_reg_prev <= 1'b0;
    end else if (strobe_resync) begin
      valid_in_reg <= valid_in;
 //   valid_in_reg_prev <= valid_in_reg;
    end
  end
  
  assign strobe_resync = q1 & !q2;
  
  RACE #(L, BETA_SHIFT, SAMPLE_SIZE, COEFF_WH, COEFF_FR, EXP_IN_WH, EXP_IN_FR, EXP_VAL_WH, EXP_VAL_FR) i_RACE(
    .clk(clk),
    .strobe_resync(strobe_resync_del_1),
    .nrst(nrst),
    .valid_in(valid_in_reg),
    .in_real(agc_out_real),
    .in_imag(agc_out_imag),
    .out_real(mac_out_real),
    .out_imag(mac_out_imag),
    .data_ready(data_ready)
  );

  AGC #(ALPHA_SHIFT, AGC_WH, AGC_FR, GAIN_WH, GAIN_FR) i_agc(
    .clk(clk),
    .nrst(nrst),
    .en(strobe_resync),
    .gain_en(gain_en),
    .in_real(in_real),
    .in_imag(in_imag),
    .out_real(agc_out_real),
    .out_imag(agc_out_imag)
  );

  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      out_real <= 0;
      out_imag <= 0;
      valid_out <= 0;
    end else if (data_ready) begin
      out_real <= mac_out_real;
      out_imag <= mac_out_imag;
      valid_out <= valid_in_reg;
    end
  end

endmodule