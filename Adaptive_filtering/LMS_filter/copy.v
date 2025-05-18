module adaptation_block #(
  parameter COEFF_SIZE = 16, 
  parameter SAMPLE_SIZE = 16,
  parameter MU_SIZE = 16
)(
  input wire nrst,
  input wire clk,
  input wire prod1_en,
  input wire prod2_en,
  input wire [2:0] sel,

  input  wire [MU_SIZE-1:0] mu,
  input  wire [SAMPLE_SIZE-1:0] u_in,
  input  wire [SAMPLE_SIZE-1:0] e_in,
  output wire [COEFF_SIZE-1 :0] w_mux
);

  reg  w_load_en;

  reg  [COEFF_SIZE-1:0] w [0:6];
  reg  [COEFF_SIZE-1:0] w_mux_del;
  wire [COEFF_SIZE-1:0] w_new;


  reg  [MU_SIZE+SAMPLE_SIZE-1:0] prod_e_mu;
  wire [SAMPLE_SIZE+1:0] prod_e_mu_round;
  wire [SAMPLE_SIZE-1:0] prod_e_mu_conv;

  reg  [2*SAMPLE_SIZE-1:0] prod_e_mu_u;
  wire [COEFF_SIZE-1:0] prod_e_mu_u_conv;

  integer i;

  assign w_out = w_mux;

  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      w_mux_del <= 0;
      w_load_en <= 0;
    end else begin
      w_mux_del <= w_mux;
      w_load_en <= prod2_en;
    end
  end

  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      for (i = 0; i < 7; i = i+1) begin
        w[i] <= 0;
      end
    end else if (w_load_en) begin
      for (i = 0; i < 7; i = i+1) begin
        if (sel == i+1) begin
          w[i] <= w_new;
        end
      end
    end
  end

  mux_7_to_1 #(COEFF_SIZE) i_mux (
    .Sel(sel),
    .A0(w[0]),
    .A1(w[1]),
    .A2(w[2]),
    .A3(w[3]),
    .A4(w[4]),
    .A5(w[5]),
    .A6(w[6]),
    .B(w_mux)
  );

  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      prod_e_mu <= 0;
    end else if (prod1_en) begin
      prod_e_mu <= $signed(e_in)*$signed(mu);
    end
  end

  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      prod_e_mu_u <= 0;
    end else if (prod2_en) begin
      prod_e_mu_u <= $signed(u_in)*$signed(prod_e_mu_conv);
    end
  end

  
  localparam S_OVF = 2**(SAMPLE_SIZE-1);
  localparam C_OVF = 2**(COEFF_SIZE-1);

  assign prod_e_mu_round = prod_e_mu[SAMPLE_SIZE+MU_SIZE-1 -: COEFF_SIZE+2] + 1;
  assign prod_e_mu_conv = (prod_e_mu_round[SAMPLE_SIZE+1 -: 2] == 2'b10) ? S_OVF   :
                          (prod_e_mu_round[SAMPLE_SIZE+1 -: 2] == 2'b01) ? S_OVF-1 :
                           prod_e_mu_round[SAMPLE_SIZE:1];
                           
  assign prod_e_mu_u_conv = (prod_e_mu_u[2*SAMPLE_SIZE-1 -: COEFF_SIZE+1] + 1) >> 1;

  assign w_new = $signed(w_mux_del)+$signed(prod_e_mu_u_conv);
  
endmodule



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
 // input wire valid_in,

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

  wire [SAMPLE_SIZE+COEFF_SIZE-1:0] y;
  wire [SAMPLE_SIZE+1:0] y_round;
  wire [SAMPLE_SIZE-1:0] y_conv;

  reg  [SAMPLE_SIZE:0] e;

  integer i;

  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      for (i = 0; i < 6; i = i+1) begin
        u[i] <= 0;
      end
    end else if (clk_fs /*&& valid_in*/) begin
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

  localparam OVF = 2**(SAMPLE_SIZE-1);
  assign y_round = y[SAMPLE_SIZE+COEFF_SIZE-1 -: SAMPLE_SIZE+2] + 1;
  assign y_conv = (y_round[SAMPLE_SIZE+1 -: 2] == 2'b10) ? OVF   :
                  (y_round[SAMPLE_SIZE+1 -: 2] == 2'b01) ? OVF-1 :
                   y_round[SAMPLE_SIZE:1];

  assign dout = (e[SAMPLE_SIZE -: 2] == 2'b10) ? OVF   :
                (e[SAMPLE_SIZE -: 2] == 2'b01) ? OVF-1 :
                 e[SAMPLE_SIZE-1:0];

  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      e <= 0;
    end else if ((sel == 7) && out_en) begin
      e <= $signed({d_in[SAMPLE_SIZE-1],d_in}) - $signed(y_conv);
    end
  end

endmodule



module LMS_filter #(
  parameter COEFF_SIZE = 17, 
  parameter SAMPLE_SIZE = 16,
  parameter MU_SIZE = 16,
  parameter D0 = 2268,
  parameter D1 = 2083
)(
  input wire nrst,
  input wire clk,
  input wire mode,

 // input  wire valid_d_in,
 // input  wire valid_u_in,
 // output reg  valid_out,

  input  wire [MU_SIZE-1:0] mu_in,
  input  wire  mu_we,

  input  wire [SAMPLE_SIZE-1:0] u_in,
  input  wire [SAMPLE_SIZE-1:0] d_in,
  output wire [SAMPLE_SIZE-1:0] out
);

  wire clk_fs_0;
  wire clk_fs_1;
  wire clk_fs;

  reg  [2:0] sel_cnt;
  reg  sel_en;
  reg  sel_en_del_0;
  reg  sel_en_del_1;

  wire mac_en;
  wire out_en;
  wire sel_rst_en;
  wire prod2_e;

  reg valid;

  reg  [SAMPLE_SIZE-1:0] u;
  reg  [SAMPLE_SIZE-1:0] d;
  reg  [MU_SIZE-1:0] mu_hold;
  reg  [MU_SIZE-1:0] mu;

  wire [SAMPLE_SIZE-1:0] u_connect;
  wire [COEFF_SIZE-1 :0] w_connect;

  clock_divider #(D0) i_clk_div_44100(
    .in_clk(clk), 
    .rst(nrst),
    .out_clk(clk_fs_0)
  );

  clock_divider #(D1) i_clk_div_48000(
    .in_clk(clk), 
    .rst(nrst),
    .out_clk(clk_fs_1)
  );

  assign clk_fs = (mode) ? clk_fs_1 : clk_fs_0;

  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      u <= 0;
      d <= 0;
      mu <= 0;
 //     valid <= 0;
    end else if (clk_fs) begin
      u <= u_in;
      d <= d_in;
      mu <= mu_hold;
 //     valid <= valid_d_in && valid_u_in;
    end
  end

 /* always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      valid_out <= 0;
    end else if (out_en) begin
      valid_out <= valid;
    end
  end*/

  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      sel_en_del_0 <= 0;
      sel_en_del_1 <= 0;
    end else begin
      sel_en_del_0 <= sel_en;
      sel_en_del_1 <= sel_en_del_0;
    end
  end

  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      mu_hold <= 0;
    end else if (mu_we) begin
      mu_hold <= mu_in;
    end
  end

  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      sel_en <= 1;
    end else begin
      if (clk_fs) begin
        sel_en <= 1;
      end else if (sel_cnt == 7) begin
        sel_en <= 0;
      end
    end
  end

  assign mac_en = sel_en || sel_en_del_0;
  assign out_en = !sel_en && sel_en_del_0;

  assign sel_rst_en = !sel_en_del_0 && sel_en_del_1;
  assign prod2_en = !(sel_en || (sel_cnt == 7));

  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      sel_cnt <= 0;
    end else begin
      if (clk_fs) begin
        sel_cnt <= 0;
      end else if (sel_cnt == 7) begin
        sel_cnt <= (sel_rst_en) ? 0 : 7;
      end else sel_cnt <= sel_cnt + 1;
    end
  end

  filter_block #(COEFF_SIZE, SAMPLE_SIZE) i_filter(
    .nrst(nrst),
    .clk(clk),
    .clk_fs(clk_fs),
    .mac_en(mac_en),
    .out_en(out_en),
    .sel(sel_cnt),
  //  .valid_in(valid),

    .w_in(w_connect),
    .u_in(u),
    .d_in(d),
    .u_mux(u_connect),
    .dout(out)
);
  adaptation_block #(COEFF_SIZE, SAMPLE_SIZE, MU_SIZE) i_adapt(
    .nrst(nrst),
    .clk(clk),
    .prod1_en(/*valid &&*/ sel_rst_en),
    .prod2_en(/*valid &&*/ prod2_en),
    .sel(sel_cnt),

    .u_in(u_connect),
    .e_in(out),
    .mu(mu),
    .w_mux(w_connect)
  );

endmodule



module MAC #(parameter SAMPLE_SIZE = 16, parameter COEFF_SIZE = 16)(
  input  wire clk,
  input  wire mult_en,
  input  wire acc_en,
  input  wire nrst,

  input  wire [COEFF_SIZE-1:0] c_in,
  input  wire [SAMPLE_SIZE-1:0] s_in,

  output wire [SAMPLE_SIZE+COEFF_SIZE-1:0] dout
);

  reg [SAMPLE_SIZE+COEFF_SIZE-1:0] mult;
  reg [SAMPLE_SIZE+COEFF_SIZE-1:0] acc;

  assign dout = acc; 

  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      mult <= 0;
    end else if (mult_en) begin 
      mult <= $signed(s_in) * $signed(c_in); //33.30
    end
  end

  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      acc <= 0;
    end else if (acc_en) begin 
      acc <= $signed(acc) + $signed(mult); //33.30
    end
  end

endmodule