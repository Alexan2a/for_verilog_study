module filter_block #(
  parameter COEFF_SIZE = 16, 
  parameter SAMPLE_SIZE = 16
)(
  input wire nrst,
  input wire clk,
  input wire clk_fs,
  input wire mac_en,
  input wire out_en,
  input wire [2:0] sel,
  input wire valid_in,

  input  wire [COEFF_SIZE-1 :0] w_in,
  input  wire [SAMPLE_SIZE-1:0] u_in,
  input  wire [SAMPLE_SIZE-1:0] d_in,
  output wire [SAMPLE_SIZE-1:0] u_mux,
  output wire [SAMPLE_SIZE-1:0] dout
);

  wire mac_nrst;
  wire acc_en;

  reg  [SAMPLE_SIZE-1:0] u [0:5];
  wire [SAMPLE_SIZE-1:0] mac_w;

  wire [SAMPLE_SIZE+COEFF_SIZE-1:0] y;  //33.30
  wire [COEFF_SIZE+1:0] y_round;
  wire [COEFF_SIZE-1:0] y_conv;

  reg  [COEFF_SIZE-1:0] e;

  integer i;

  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      for (i = 0; i < 6; i = i+1) begin
        u[i] <= 0;
      end
    end else if (clk_fs && valid_in) begin
      for (i = 1; i < 6; i = i+1) begin
        u[i] <= u[i-1];
      end
        u[0] <= u_in;
    end
  end

  mux_7_to_1 #(SAMPLE_SIZE) i_mux (
    .Sel(sel),
    .A0(u_in),
    .A1(u[0]),
    .A2(u[1]),
    .A3(u[2]),
    .A4(u[3]),
    .A5(u[4]),
    .A6(u[5]),
    .B(u_mux)
  );

  assign mac_nrst = nrst && !clk_fs;
  assign mult_en = mac_en && !(sel == 7);

  MAC #(SAMPLE_SIZE, COEFF_SIZE) i_mac (
    .clk(clk),
    .mult_en(mult_en),
    .acc_en(mac_en),
    .nrst(mac_nrst),
    .c_in(w_in),
    .s_in(u_mux),
    .dout(y)
  );

  localparam C_OVF = 2**(COEFF_SIZE-1);
  localparam S_OVF = 2**(SAMPLE_SIZE-1);
  assign y_round = y[SAMPLE_SIZE+COEFF_SIZE-1 -: COEFF_SIZE+2] + 1; //19.16
  assign y_conv = (y_round[COEFF_SIZE+1 -: 2] == 2'b10) ? C_OVF   :
                  (y_round[COEFF_SIZE+1 -: 2] == 2'b01) ? C_OVF-1 :
                   y_round[COEFF_SIZE:1];  //17.15

  assign dout = (e[COEFF_SIZE-1 -: 2] == 2'b10) ? S_OVF   :
                (e[COEFF_SIZE-1 -: 2] == 2'b01) ? S_OVF-1 :
                 e[SAMPLE_SIZE-1:0];  //16.15

  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      e <= 0;
    end else if ((sel == 7) && out_en) begin
      e <= $signed({d_in[SAMPLE_SIZE-1],d_in}) - $signed(y_conv); //17.15
    end
  end

endmodule