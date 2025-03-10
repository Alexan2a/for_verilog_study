module fir#(
  parameter ORD = 255, 
  parameter D = 100,
  parameter COEFF_SIZE = 16, 
  parameter SAMPLE_SIZE = 16,
  parameter MAC_NUM = 1
)(
  input  wire nrst,
  input  wire en,
  input  wire clk,
  input  wire clk_fs,
  input  wire clk_fs_d0,
  input  wire clk_fs_d1,
  input  wire clk_fs_d2,
  input  wire [SAMPLE_SIZE-1:0] din,
  output reg  [SAMPLE_SIZE+COEFF_SIZE-1:0] dout,

  input  wire c_we,
  input  wire [COEFF_SIZE-1:0] c_in,
  input  wire [$clog2(ORD + 1)-1:0] c_addr
);

  localparam MAC_SIZE = (ORD+MAC_NUM)/MAC_NUM;

  reg  en_pr;
  reg  mac_en;
  wire sample_en;
  wire coeff_en;
  wire we;
  wire acc_nrst;

  reg  [$clog2(MAC_SIZE)-1:0] sample_step_cnt;
  reg  [$clog2(MAC_SIZE)-1:0] sample_addr_cnt;
  wire [$clog2(MAC_SIZE)-1:0] sample_addr;
  reg  [$clog2(MAC_SIZE)-1:0] cnt;

  reg  [MAC_NUM-1:0] coeff_we;
  reg  [$clog2(MAC_SIZE)-1:0] coeff_dec_addr;
  wire [$clog2(MAC_SIZE)-1:0] coeff_addr;
  
  wire [SAMPLE_SIZE-1:0] samples [0:MAC_NUM];
  wire [SAMPLE_SIZE+COEFF_SIZE-1:0] mac_dout [0:MAC_NUM-1];

  reg  [SAMPLE_SIZE+COEFF_SIZE-1:0] sum;

  //counts what address should new sample be written to
  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      sample_step_cnt <= 0;
    end else if (!c_we) begin
      if (clk_fs && en) begin
        if (sample_step_cnt == MAC_SIZE-1) sample_step_cnt <= 0;
        else sample_step_cnt <= sample_step_cnt + 1;
      end
    end
  end

  //counts address of needed sample for mac
  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      sample_addr_cnt <= 0;
    end else if (!c_we) begin
      if (clk_fs_d1) sample_addr_cnt <= sample_step_cnt;
      else if (sample_addr_cnt == 0) sample_addr_cnt <= MAC_SIZE-1;
      else sample_addr_cnt <= sample_addr_cnt - 1;
    end
  end

  //counts mac step
  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      cnt <= 0;
    end else if (!c_we) begin
      if (clk_fs_d1) cnt <= 0;
      else if (cnt == MAC_SIZE) cnt <= MAC_SIZE;
      else cnt <= cnt + 1;
    end
  end

  always @(posedge clk) begin
    mac_en <= en_pr;
  end

  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      en_pr <= 0;
    end else begin
      if (cnt == MAC_SIZE-1 || c_we) en_pr <= 0;
      else if (clk_fs_d1 && en) en_pr <= 1;
    end
  end

  assign sample_addr = (clk_fs_d0 || clk_fs_d1) ? sample_step_cnt : sample_addr_cnt;
  assign coeff_addr = (c_we) ? coeff_dec_addr : cnt;
  assign sample_en = en_pr || ((clk_fs_d0 || clk_fs_d1) && en);
  assign coeff_en = en_pr || c_we;

  assign we = clk_fs_d1;
  assign acc_nrst = nrst && !clk_fs_d2;

  integer j,k;

  //coeff adresses decoder (according to c_addr)
  always @(*) begin
    coeff_we = 0;
    coeff_dec_addr = 0;
    for (j = 0; j < MAC_SIZE; j = j+1) begin
      for (k = 0; k < MAC_NUM; k = k+1) begin
        if (c_addr == j+k*MAC_SIZE) begin
          coeff_dec_addr = j;
          coeff_we = (c_we) ? 1 << k : 0;
        end
      end
    end
  end
  
  always @(*) begin
    sum = mac_dout[0];
    for(j = 1; j < MAC_NUM; j = j + 1) begin
      sum = $signed(sum) + $signed(mac_dout[j]);
    end
  end

  
  /*always @(posedge clk or negedge nrst) begin
      if (!nrst) begin
        dout <= 0;
      end else begin
        if (clk_fs_d1) begin
           dout <= sum;
        end
      end
    end
*/

  always @(*) begin
    dout = sum;
  end
  assign samples[0] = din;
  
  genvar i;
  generate
    for(i = 0; i < MAC_NUM; i = i + 1) begin
      MAC #(MAC_SIZE, SAMPLE_SIZE, COEFF_SIZE) i_MAC(
        .clk(clk),
        .nrst(acc_nrst),
        .en(mac_en),
        .c_we(coeff_we[i]),
        .c_en(coeff_en),
        .c_addr(coeff_addr),
        .c_in(c_in),
        .s_we(we),
        .s_en(sample_en),
        .s_addr(sample_addr),
        .s_in(samples[i]),
        .s_out(samples[i+1]),
        .dout(mac_dout[i])
      );
    end
  endgenerate

endmodule