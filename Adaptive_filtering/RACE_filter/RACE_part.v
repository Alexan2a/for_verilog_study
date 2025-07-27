module RACE_part #(
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
  input  wire strobe_resync,
  input  wire nrst,
  input  wire en,
  input  wire acc_en,
  input  wire acc_rst,
  input  wire [$clog2(2*L+1)-1:0] sel,
  input  wire [IN_SIZE-1:0] in,
  input  wire [COEFF_WH -1:0] in_rxx,
  output wire [OUT_SIZE-1:0] out,
  output wire [COEFF_WH-1:0] out_rxx
);

  reg  [IN_SIZE-1:0] x_buf [0:2*L];
  wire [IN_SIZE-1:0] mux_x;
  reg  [IN_SIZE-1:0] mux_del_0, mux_del_1;

  reg  [IN_SIZE*2-1:0] rxx_filt_in;

  wire [EXP_VAL_WH-1:0] exp_out_rxx;
  wire [COEFF_WH+1:0] exp_out_rxx_rnd;

  wire [IN_SIZE+COEFF_WH-1:0] mac_out;
  wire [OUT_SIZE:0] mac_out_round;
  
  // input taps
  integer i;
  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      for(i = 0; i < 2*L+1; i = i + 1) begin
        x_buf[i] <= 0;
      end
    end else if (strobe_resync) begin
      for(i = 0; i < 2*L; i = i + 1) begin
        x_buf[i+1] <= x_buf[i];
      end
      x_buf[0] <= in;
    end
  end 


  assign mux_x = (sel == 2*L+1) ? 16'd0 : x_buf[sel];
  always @(posedge clk) begin
     mux_del_0 <= mux_x;
     mux_del_1 <= mux_del_0;
  end

  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      rxx_filt_in <= 0;
    end else begin
      rxx_filt_in <= $signed(x_buf[L]) * $signed(mux_x);
    end
  end

  exp_smoothing_filter #(L, EXP_IN_WH, EXP_IN_FR, EXP_VAL_WH, EXP_VAL_FR, BETA_SHIFT) i_rxx_filt(
    .clk(clk),
    .nrst(nrst),
    .en(en),
    .in(rxx_filt_in),
    .out(exp_out_rxx)
  );

  MAC #(IN_SIZE, COEFF_WH) i_mac(
    .clk(clk),
    .en(acc_en),
    .nrst(nrst),
    .acc_rst(acc_rst),
    .c_in(in_rxx),
    .s_in(mux_del_1),
    .dout(mac_out)
  );
  
  //round...
  assign mac_out_round = mac_out[IN_SIZE+COEFF_WH-1 -: OUT_SIZE+1] + 1;
  assign out = mac_out_round[OUT_SIZE:1];
  
  localparam OVF = 2**(COEFF_WH-1);
  
  assign exp_out_rxx_rnd = exp_out_rxx[EXP_VAL_WH-1 -: COEFF_WH+2] + 1;
  assign out_rxx = (exp_out_rxx_rnd[COEFF_WH+1 -: 2] == 2'b10) ? OVF   :
                   (exp_out_rxx_rnd[COEFF_WH+1 -: 2] == 2'b01) ? OVF-1 :
                    exp_out_rxx_rnd[COEFF_WH:1]; 

endmodule