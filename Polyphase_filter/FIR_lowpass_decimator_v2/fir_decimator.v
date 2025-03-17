module fir_decimator#(
  parameter ORD = 255,
  parameter M = 8, 
  parameter D = 100,
  parameter COEFF_SIZE = 16, 
  parameter SAMPLE_SIZE = 16,
  parameter MAC_NUM = 1
)(
  input  wire nrst,
  input  wire clk,

  input  wire valid_in,
  output reg  valid_out,
  
  input  wire [SAMPLE_SIZE-1:0] din,
  output reg  [SAMPLE_SIZE-1:0] dout,

  input  wire c_we,
  input  wire [COEFF_SIZE-1:0] c_in,
  input  wire [$clog2(ORD + 1)-1:0] c_addr
);

  localparam POLY_NUM = (ORD+1)/M;
  localparam IS_ODD = (M % 2 == 0) ? 0 : 1;
  localparam MAC_NUM_FIX = ((POLY_NUM+(D-2)-1)/(D-2) > MAC_NUM) ? (POLY_NUM+(D-2)-1)/(D-2) : MAC_NUM;
  localparam MAC_SIZE = (POLY_NUM+MAC_NUM_FIX-1)/MAC_NUM_FIX;

  wire clk_fs;

  reg clk_fs_d0;
  reg clk_fs_d1;
  reg clk_fs_d2;

  reg  [$clog2(ORD+3)-1:0] valid_data_cnt;
  wire valid_data;
  reg  valid_data_reg;


  reg  valid_in_reg;
  reg  valid_in_reg_del;
  reg  [SAMPLE_SIZE-1:0] din_reg;

  reg  [$clog2(M)-1:0] cnt;
  reg  [$clog2(M)-1:0] cnt_d;

  reg  [M-1:0] coeff_we;
  reg  [M-1:0] ch_mem_en;
  reg  [$clog2(POLY_NUM)-1:0] coeff_dec_addr;
  wire [$clog2(MAC_SIZE)-1:0] coeff_addr;
  wire [$clog2(MAC_SIZE)-1:0] coeff_addr_rev; 

  wire  en;
  reg   mem_en;
  reg   mac_en;
  wire [M-1:0] sample_en;
  reg  [(M+IS_ODD)/2-1:0] coeff_en;
  reg  [$clog2(MAC_SIZE+1)-1:0] mem_en_cnt;

  reg  [SAMPLE_SIZE-1:0] mac_s_in [0:MAC_NUM-1];
  reg  [COEFF_SIZE-1:0]  mac_c_in [0:MAC_NUM-1];
  wire [SAMPLE_SIZE+COEFF_SIZE-1:0] mac_dout [0:MAC_NUM-1];
  reg  [SAMPLE_SIZE+COEFF_SIZE-1:0] sum;

  wire [SAMPLE_SIZE*MAC_NUM_FIX-1:0] s_out [0:M-1];
  wire [COEFF_SIZE*MAC_NUM_FIX -1:0] c_out [0:(M+IS_ODD)/2-1];

  reg  [SAMPLE_SIZE+COEFF_SIZE-1:0] acc;
  wire [SAMPLE_SIZE+1:0] acc_round;
  wire [SAMPLE_SIZE-1:0] acc_conv;

  clock_divider #(D) i_clk_div_0(
    .in_clk(clk), 
    .rst(nrst),
    .out_clk(clk_fs)
  );

  always @(posedge clk) begin
    clk_fs_d0 <= clk_fs;
    clk_fs_d1 <= clk_fs_d0;
    clk_fs_d2 <= clk_fs_d1;
  end

  always @(posedge clk) begin
    if (clk_fs) begin
      valid_in_reg <= valid_in;
      valid_in_reg_del <= valid_in_reg;
      valid_data_reg <= valid_data;
      din_reg <= din;
    end
  end

  assign en = !c_we && valid_in_reg;

  //check if memories are empty
  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      valid_data_cnt <= 0;
    end else if (en) begin
      if (clk_fs_d1) begin
        if (valid_data_cnt == ORD+2) valid_data_cnt <= ORD+2;
        else valid_data_cnt <= valid_data_cnt + 1;
      end
    end
  end

  assign valid_data = (valid_data_cnt == ORD+2) ? 1 : 0;

  integer j,k;

  //coeff adress decoder
  always @(*) begin
    coeff_dec_addr = 0;
    coeff_we = 0;
    for (j = 0; j < (POLY_NUM+1)/2; j = j+1) begin
      for (k = 0; k < M; k = k+1) begin
        if (c_addr == k+j*M) begin
          if (k < (M+IS_ODD)/2) begin
            coeff_dec_addr = j;
            coeff_we = (c_we) ? 1 << k : 0;
          end else begin
            coeff_dec_addr = POLY_NUM-j-1;
            coeff_we = (c_we) ? 1 << (M-k-1) : 0;
          end
        end
      end
    end
  end

  //counts step of 'fir'
  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      cnt <= 0;
    end else if (!c_we && valid_in) begin
      if (clk_fs) begin
        if (cnt == 0) cnt <= M-1;
        else cnt <= cnt - 1;
      end
    end
  end

  always @(posedge clk) begin
    cnt_d <= cnt;
  end

  //enable memories according to cnt
  always @(*) begin
    if (c_we) begin
      ch_mem_en = coeff_we;
    end else begin
      ch_mem_en = 0;
      for (j = 0; j < M; j = j+1) begin
        if (cnt == j) ch_mem_en = 1 << j;
      end
    end
  end

////////////////////////////////////////////////////////
//MEMORY SIGNALS

  //counts mac step
  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      mem_en_cnt <= 0;
    end else if (en) begin
      if (clk_fs_d1) mem_en_cnt <= 0;
      else if (mem_en_cnt == MAC_SIZE) mem_en_cnt <= MAC_SIZE;
      else mem_en_cnt <= mem_en_cnt + 1;
    end
  end


  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      mem_en <= 0;
    end else begin
      if (mem_en_cnt == MAC_SIZE-1 || c_we) mem_en  <= 0;
      else if (clk_fs_d1 && valid_in_reg) mem_en <= 1;
    end
  end

  assign sample_en = (!en || ((cnt == MAC_SIZE) && !(clk_fs || clk_fs_d0))) ? 0 : ch_mem_en;

  always @(*) begin
    for (j = 0; j < (M+IS_ODD)/2; j = j+1) begin
      coeff_en[j] = (ch_mem_en[j] || ch_mem_en [M-j-1]) && (mem_en || c_we);
    end
  end

  reg  [$clog2(MAC_SIZE)-1:0] sample_step_cnt;
  reg  [$clog2(MAC_SIZE)-1:0] sample_addr_cnt;
  wire [$clog2(MAC_SIZE)-1:0] sample_addr;

  //counts what address should new sample be written to
  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      sample_step_cnt <= 0;
    end else if (!c_we && valid_in) begin
      if (clk_fs && (cnt == 0)) begin
        if (sample_step_cnt == MAC_SIZE-1) sample_step_cnt <= 0;
        else sample_step_cnt <= sample_step_cnt + 1;
      end
    end
  end

  //counts address of needed sample for mac
  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      sample_addr_cnt <= 0;
    end else if (!c_we && valid_in_reg) begin
      if (clk_fs_d1) sample_addr_cnt <= sample_step_cnt;
      else if (sample_addr_cnt == 0) sample_addr_cnt <= MAC_SIZE-1;
      else sample_addr_cnt <= sample_addr_cnt - 1;
    end
  end

  assign sample_addr = (clk_fs_d0 || clk_fs_d1) ? sample_step_cnt : sample_addr_cnt;
  assign coeff_addr = mem_en_cnt[$clog2(MAC_SIZE)-1:0];
  assign coeff_addr_rev = MAC_SIZE-1-coeff_addr;

/////////////////////////////////////////////
// MAC SIGNALS

  //enable mac accumulator
  always @(posedge clk) begin
    mac_en <= mem_en;
  end

  //mac input mux
  always @(*) begin
    for (k = 0; k < MAC_NUM; k = k+1) begin
      mac_c_in[k] = 0;
      mac_s_in[k] = 0;
    end
    for (j = 0; j < M; j = j+1) begin
      for (k = 0; k < MAC_NUM; k = k+1) begin
        if (cnt_d == j) begin
          mac_c_in[k] = (j < (M+IS_ODD)/2) ? c_out[j][k*COEFF_SIZE +: COEFF_SIZE] : c_out[M-j-1][k*COEFF_SIZE +: COEFF_SIZE];
          mac_s_in[k] = s_out[j][k*SAMPLE_SIZE +: SAMPLE_SIZE];
        end 
      end
    end
  end

  wire mac_nrst;
  assign mac_nrst = nrst && !clk_fs_d2;

  //counts sum of mac outs
  always @(*) begin
    if (valid_data) begin
      sum = mac_dout[0];
      for(j = 1; j < MAC_NUM; j = j + 1) begin
        sum = $signed(sum) + $signed(mac_dout[j]);
      end
    end else sum = 0;
  end

/////////////////////////////////////////////
// PHASE ACC SIGNALS

  //resets
  wire acc_nrst;
  assign acc_nrst = nrst && !((cnt == M-1) && clk_fs && valid_in_reg);

  //accumulate outputs of phases
  always @(posedge clk or negedge acc_nrst) begin
    if (!acc_nrst) begin
      acc <= 0;
    end else if ((!c_we || valid_in_reg_del) && clk_fs_d1) begin 
      acc <= $signed(acc) + $signed(sum); //32.30
    end
  end

  //round
  localparam OVF = 2**(SAMPLE_SIZE-1);
  assign acc_round = acc[SAMPLE_SIZE+COEFF_SIZE-1 -: SAMPLE_SIZE+2] + 1;
  assign acc_conv = (acc_round[SAMPLE_SIZE+1 -: 2] == 2'b10) ? OVF   :
                    (acc_round[SAMPLE_SIZE+1 -: 2] == 2'b01) ? OVF-1 :
                     acc_round[SAMPLE_SIZE:1];


  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      dout <= 0;
    end else if (clk_fs_d2 && (cnt == M-1) && valid_in_reg) begin 
      dout <= acc_conv;
    end
  end

  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      valid_out <= 0;
    end else if (clk_fs_d2) begin 
      valid_out <= (cnt == M-1 && valid_data_reg) ? valid_in_reg : 0;
    end
  end
      
  genvar i;
  generate
    for(i = 0; i < (M + IS_ODD)/2; i = i + 1) begin
      if (i == (M+IS_ODD)/2-1 && IS_ODD == 1) begin 
        memory_block #(MAC_SIZE, D, COEFF_SIZE, SAMPLE_SIZE, MAC_NUM_FIX) i_mem (
          .clk(clk),
          .sample_we(clk_fs_d1),
          .sample_en(sample_en[i]),
          .sample_addr(sample_addr),
          .coeff_en(coeff_en[i]),
          .coeff_addr(coeff_addr),
          .s_in(din_reg),
          .s_out(s_out[i]),
          .c_out(c_out[i]),
          .c_we(coeff_we[i]),
          .c_in(c_in),
          .c_addr(coeff_dec_addr)
        );
      end
      memory_block_2 #(MAC_SIZE, D, COEFF_SIZE, SAMPLE_SIZE, MAC_NUM_FIX) i_mem_2 (
        .clk(clk),
        .sample_we(clk_fs_d1),
        .sample_en_0(sample_en[i]),
        .sample_en_1(sample_en[M-i-1]),
        .sample_addr(sample_addr),
        .coeff_en(coeff_en[i]),
        .coeff_addr(sample_en[i] ? coeff_addr : coeff_addr_rev),
        .s_in(din_reg),
        .s_out_0(s_out[i]),
        .s_out_1(s_out[M-i-1]),
        .c_out(c_out[i]),
        .c_we(coeff_we[i]),
        .c_in(c_in),
        .c_addr(coeff_dec_addr)
      );
    end
  endgenerate

  generate
    for(i = 0; i < MAC_NUM; i = i + 1) begin
      MAC #(MAC_SIZE, SAMPLE_SIZE, COEFF_SIZE) i_MAC(
        .clk(clk),
        .nrst(mac_nrst),
        .en(mac_en),
        .c_in(mac_c_in[i]),
        .s_in(mac_s_in[i]),
        .dout(mac_dout[i])
      );
    end
  endgenerate

endmodule