module memory_controller_2#(
  parameter MAC_SIZE = 255, 
  parameter D = 100,
  parameter COEFF_SIZE = 16, 
  parameter SAMPLE_SIZE = 16,
  parameter MAC_NUM = 1
)(
  input  wire nrst,
  input  wire en_0,
  input  wire en_1,
  input  wire clk,
  input  wire clk_fs,
  input  wire clk_fs_d0,
  input  wire clk_fs_d1,
  input  wire clk_fs_d2,
  input  wire [SAMPLE_SIZE-1:0] s_in,

  input  wire c_we,
  input  wire [COEFF_SIZE-1:0] c_in,
  input  wire [$clog2(MAC_SIZE)-1:0] c_addr,

  output reg  [SAMPLE_SIZE*MAC_NUM-1:0] s_out_0,
  output reg  [SAMPLE_SIZE*MAC_NUM-1:0] s_out_1,
  output reg  [COEFF_SIZE*MAC_NUM-1:0] c_out
);

  reg  en_pr_0;
  reg  en_pr_1;
  wire sample_en_0;
  wire sample_en_1;
  wire coeff_en;
  wire we;

  reg  [$clog2(MAC_SIZE)-1:0] sample_step_cnt_0;
  reg  [$clog2(MAC_SIZE)-1:0] sample_step_cnt_1;
  reg  [$clog2(MAC_SIZE)-1:0] sample_addr_cnt_0;
  reg  [$clog2(MAC_SIZE)-1:0] sample_addr_cnt_1;
  wire [$clog2(MAC_SIZE)-1:0] sample_addr_0;
  wire [$clog2(MAC_SIZE)-1:0] sample_addr_1;

  reg  [$clog2(MAC_SIZE)-1:0] cnt_0;
  reg  [$clog2(MAC_SIZE)-1:0] cnt_1;

  reg  [MAC_NUM-1:0] coeff_we;
  reg  [$clog2(MAC_SIZE)-1:0] coeff_dec_addr;
  wire [$clog2(MAC_SIZE)-1:0] coeff_addr;
  
  
  wire [SAMPLE_SIZE-1:0] samples_0 [0:MAC_NUM];
  wire [SAMPLE_SIZE-1:0] samples_1 [0:MAC_NUM];
  wire [COEFF_SIZE-1:0] coeffs [0:MAC_NUM-1];


  //counts what address should new sample be written to
  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      sample_step_cnt_0 <= 0;
    end else if (!c_we) begin
      if (clk_fs && en_0) begin
        if (sample_step_cnt_0 == MAC_SIZE-1) sample_step_cnt_0 <= 0;
        else sample_step_cnt_0 <= sample_step_cnt_0 + 1;
      end
    end
  end

  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      sample_step_cnt_1 <= 0;
    end else if (!c_we) begin
      if (clk_fs && en_1) begin
        if (sample_step_cnt_1 == MAC_SIZE-1) sample_step_cnt_1 <= 0;
        else sample_step_cnt_1 <= sample_step_cnt_1 + 1;
      end
    end
  end

  //counts address of needed sample for mac
  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      sample_addr_cnt_0 <= 0;
    end else if (!c_we) begin
      if (clk_fs_d1) sample_addr_cnt_0 <= sample_step_cnt_0;
      else if (sample_addr_cnt_0 == 0) sample_addr_cnt_0 <= MAC_SIZE-1;
      else sample_addr_cnt_0 <= sample_addr_cnt_0 - 1;
    end
  end

  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      sample_addr_cnt_1 <= 0;
    end else if (!c_we) begin
      if (clk_fs_d1) sample_addr_cnt_1 <= sample_step_cnt_1;
      else if (sample_addr_cnt_1 == 0) sample_addr_cnt_1 <= MAC_SIZE-1;
      else sample_addr_cnt_1 <= sample_addr_cnt_1 - 1;
    end
  end

  //counts mac step
  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      cnt_0 <= 0;
    end else if (!c_we) begin
      if (clk_fs_d1) cnt_0 <= 0;
      else if (cnt_0 == MAC_SIZE) cnt_0 <= MAC_SIZE;
      else cnt_0 <= cnt_0 + 1;
    end
  end

  //counts mac step
  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      cnt_1 <= MAC_SIZE-1;
    end else if (!c_we) begin
      if (clk_fs_d1) cnt_1 <= MAC_SIZE-1;
      else if (cnt_1 == 0) cnt_1 <= 0;
      else cnt_1 <= cnt_1 - 1;
    end
  end

  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      en_pr_0 <= 0;
      en_pr_1 <= 0;
    end else begin
      if (cnt_0 == MAC_SIZE-1 || c_we) begin
        en_pr_0 <= 0;
        en_pr_1 <= 0;
      end else begin
        if (clk_fs_d1 && en_0) en_pr_0 <= 1;
        if (clk_fs_d1 && en_1) en_pr_1 <= 1;
      end
    end
  end

  assign sample_addr_0 = (clk_fs_d0 || clk_fs_d1) ? sample_step_cnt_0 : sample_addr_cnt_0;
  assign sample_addr_1 = (clk_fs_d0 || clk_fs_d1) ? sample_step_cnt_1 : sample_addr_cnt_1;
  assign coeff_addr = (c_we) ? coeff_dec_addr : (en_pr_0) ? cnt_0 : cnt_1;
  assign sample_en_0 = en_pr_0 || ((clk_fs_d0 || clk_fs_d1) && en_0);
  assign sample_en_1 = en_pr_1 || ((clk_fs_d0 || clk_fs_d1) && en_1);
  assign coeff_en = en_pr_0 || en_pr_1 || c_we;

  assign we = clk_fs_d1;

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
    for (j = 0; j < MAC_NUM; j = j+1) begin
      s_out_0[j*(SAMPLE_SIZE) +: SAMPLE_SIZE] = samples_0[j+1];
      s_out_1[j*(SAMPLE_SIZE) +: SAMPLE_SIZE] = samples_1[j+1];
      c_out[j*COEFF_SIZE +: COEFF_SIZE] = coeffs[j];
    end
  end

  assign samples_0[0] = s_in;
  assign samples_1[0] = s_in;
  
  genvar i;
  generate
    for(i = 0; i < MAC_NUM; i = i + 1) begin
      dual_port_RAM #(SAMPLE_SIZE, MAC_SIZE) i_sample_ram_0(
        .clk(clk),
        .en(sample_en_0),
        .wr_addr(sample_addr_0),
        .rd_addr(sample_addr_0),
        .wr_din(samples_0[i]),
        .we(we),
        .rd_dout(samples_0[i+1])
      );
      dual_port_RAM #(SAMPLE_SIZE, MAC_SIZE) i_sample_ram_1(
        .clk(clk),
        .en(sample_en_1),
        .wr_addr(sample_addr_1),
        .rd_addr(sample_addr_1),
        .wr_din(samples_1[i]),
        .we(we),
        .rd_dout(samples_1[i+1])
      );
      single_port_RAM #(COEFF_SIZE, MAC_SIZE) i_MAC(
        .clk(clk),
        .en(coeff_en),
        .we(coeff_we[i]),
        .addr(coeff_addr),
        .din(c_in),
        .dout(coeffs[i])
      );
    end
  endgenerate

endmodule