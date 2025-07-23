module RACE_part #(
  parameter L = 7,
  parameter ALPHA_SHIFT = 4,
  parameter BETA_SHIFT = 4,
  parameter SAMPLE_SIZE = 16,
  parameter COEFF_SIZE = 16
)(
  input  wire clk,
  input  wire clk_div,
  input  wire nrst,
  input  wire en,
  input  wire [$clog2(2*L+1)-1:0] sel,
  input  wire [SAMPLE_SIZE-1:0] in,
  input  wire [COEFF_SIZE -1:0] in_rxx,
  output wire [SAMPLE_SIZE  :0] out,
  output wire [COEFF_SIZE -1:0] out_rxx
);

  reg  [SAMPLE_SIZE-1:0] x_buf [0:2*L];
  wire [SAMPLE_SIZE-1:0] mux_x;
  reg  [SAMPLE_SIZE-1:0] mux_x_del;

  wire [SAMPLE_SIZE*2-1:0] rxx_filt_in;
  reg  [SAMPLE_SIZE+1:0] rxx_filt_in_rnd;

  wire [SAMPLE_SIZE+COEFF_SIZE-1:0] mac_out;
  wire [SAMPLE_SIZE+COEFF_SIZE-1:0] mac_out_round;
  
  // input taps
  integer i;
  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      for(i = 0; i < 2*L+1; i = i + 1) begin
        x_buf[i] <= 0;
      end
    end else if (clk_div) begin
      for(i = 0; i < 2*L; i = i + 1) begin
        x_buf[i+1] <= x_buf[i];
      end
      x_buf[0] <= in;
    end
  end

  always @(posedge clk) begin
     mux_x_del <= mux_x;
  end

  mux_15_to_1 #(SAMPLE_SIZE) i_mux(
    .Sel(sel),
    .A0(x_buf[0]),
    .A1(x_buf[1]),
    .A2(x_buf[2]),
    .A3(x_buf[3]),
    .A4(x_buf[4]),
    .A5(x_buf[5]),
    .A6(x_buf[6]),
    .A7(x_buf[7]),
    .A8(x_buf[8]),
    .A9(x_buf[9]),
    .A10(x_buf[10]),
    .A11(x_buf[11]),
    .A12(x_buf[12]),
    .A13(x_buf[13]),
    .A14(x_buf[14]),
    .B(mux_x)
  );
  
  assign rxx_filt_in = $signed(x_buf[L]) * $signed(mux_x);
  
  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      rxx_filt_in_rnd <= 0;
    end else begin
      rxx_filt_in_rnd <= rxx_filt_in[SAMPLE_SIZE*2-1 -: SAMPLE_SIZE+2] + 1;
    end
  end
  
  exp_smoothing_filter #(L, SAMPLE_SIZE+1, COEFF_SIZE, BETA_SHIFT) i_rxx_filt(
    .clk(clk),
    .nrst(nrst),
    .en(en),
    .in(rxx_filt_in_rnd[SAMPLE_SIZE+1:1]),
    .out(out_rxx)
  );
  
  MAC #(SAMPLE_SIZE, COEFF_SIZE) i_mac(
    .clk(clk),
    .en(en),
    .nrst(!clk_div && nrst),
    .c_in(in_rxx),
    .s_in(mux_x_del),
    .dout(mac_out)
  );
  
  //round...
  assign mac_out_round = mac_out[SAMPLE_SIZE+COEFF_SIZE-1 -: SAMPLE_SIZE+2] + 1;
  assign out = mac_out_round[SAMPLE_SIZE+1:1];
  

endmodule