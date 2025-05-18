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

  input  wire valid_d_in,
  input  wire valid_u_in,
  output reg  valid_out,

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
      valid <= 0;
    end else if (clk_fs) begin
      u <= u_in;
      d <= d_in;
      mu <= mu_hold;
      valid <= valid_d_in && valid_u_in;
    end
  end

  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      valid_out <= 0;
    end else if (out_en) begin
      valid_out <= valid;
    end
  end

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
    .valid_in(valid),

    .w_in(w_connect),
    .u_in(u),
    .d_in(d),
    .u_mux(u_connect),
    .dout(out)
);
  adaptation_block #(COEFF_SIZE, SAMPLE_SIZE, MU_SIZE) i_adapt(
    .nrst(nrst),
    .clk(clk),
    .prod1_en(valid && sel_rst_en),
    .prod2_en(valid && prod2_en),
    .sel(sel_cnt),

    .u_in(u_connect),
    .e_in(out),
    .mu(mu),
    .w_mux(w_connect)
  );

endmodule