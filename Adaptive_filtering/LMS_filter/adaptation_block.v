module adaptation_block #(
  parameter COEFF_SIZE = 17, 
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


  reg  [MU_SIZE+SAMPLE_SIZE-1:0] prod_e_mu; //32.30
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
      prod_e_mu <= $signed(e_in)*$signed(mu); //32.30
    end
  end

  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      prod_e_mu_u <= 0;
    end else if (prod2_en) begin
      prod_e_mu_u <= $signed(u_in)*$signed(prod_e_mu_conv); //32.30
    end
  end

  
  localparam S_OVF = 2**(SAMPLE_SIZE-1);

  assign prod_e_mu_round = prod_e_mu[SAMPLE_SIZE+MU_SIZE-1 -: SAMPLE_SIZE+2] + 1;  //18.16
  assign prod_e_mu_conv = (prod_e_mu_round[SAMPLE_SIZE+1 -: 2] == 2'b10) ? S_OVF   :
                          (prod_e_mu_round[SAMPLE_SIZE+1 -: 2] == 2'b01) ? S_OVF-1 :
                           prod_e_mu_round[SAMPLE_SIZE:1]; //16.15
                           
  assign prod_e_mu_u_conv = (prod_e_mu_u[2*SAMPLE_SIZE-1 -: COEFF_SIZE+1] + 1) >> 1; //17.15

  assign w_new = $signed(w_mux_del)+$signed(prod_e_mu_u_conv);
  
endmodule
