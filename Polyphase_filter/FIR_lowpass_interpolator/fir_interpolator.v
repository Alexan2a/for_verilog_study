module fir_interpolator#(
  parameter ORD = 255, 
  parameter M = 8,
  parameter D = 100,
  parameter COEFF_SIZE = 16, 
  parameter SAMPLE_SIZE = 16,
  parameter MAC_NUM = 1)
(
  input  wire nrst,
  input  wire clk,

  input  wire valid_in,
  output reg  valid_out,

  input  wire [$clog2(M/2+1)-1:0] div,
  input  wire [SAMPLE_SIZE-1:0] din,
  output reg [SAMPLE_SIZE-1:0] dout,

  input  wire c_we,
  input  wire [COEFF_SIZE-1:0] c_in,
  input  wire [$clog2((ORD + 1) >> 1)-1:0] c_addr
);
  
  localparam POLY_NUM = (ORD+1)/M;
  localparam MAC_NUM_FIX = ((POLY_NUM+(D-2)-1)/(D-2) > MAC_NUM) ? (POLY_NUM+(D-2)-1)/(D-2) : MAC_NUM;
  localparam MAC_POLY_NUM = (POLY_NUM+MAC_NUM_FIX-1)/MAC_NUM_FIX;
  localparam MAC_COEFF_NUM = MAC_POLY_NUM*M;
  localparam IS_ONE = (MAC_NUM_FIX == 1) ? 1 : 0;
  localparam IS_ODD = (MAC_NUM_FIX%2 == 1) ? 1 : 0;
  
  localparam GND = 0;

  wire clk_fs_new;
  reg  clk_fs_new_d0;
  reg  clk_fs_new_d1;
  reg  clk_fs_new_d2;

  wire en;
  reg [SAMPLE_SIZE-1:0] din_reg;
  reg  valid_in_reg;
  reg  en_pr;
  wire en_pr_a, en_pr_b;
  reg  en_a, en_b;
  wire sample_mem_en;
  wire coeff_mem_en;
  wire clk_div_out;
  wire we;
  wire acc_nrst;

  reg  [$clog2(POLY_NUM+1)-1:0] valid_data_cnt;
  wire valid_data;

  reg  [$clog2(M)-1:0] phase_step_cnt;
  reg  [$clog2(M)-1:0] phase_step_cnt_d;
  reg  [$clog2(M/2+1)-1:0] div_phase_cnt;

  reg  [$clog2(MAC_POLY_NUM)-1:0] poly_step_cnt;
  reg  [$clog2(MAC_POLY_NUM)-1:0] poly_addr_cnt;
  reg  [$clog2(MAC_POLY_NUM)-1:0] poly_rev_addr_cnt;
  wire [$clog2(MAC_POLY_NUM)-1:0] poly_addr;
  reg  [$clog2(MAC_POLY_NUM)-1:0] cnt;

  reg  [MAC_NUM_FIX/2+IS_ODD-1:0] coeff_we;
  reg  [$clog2(MAC_COEFF_NUM)-1:0] dec_c_addr;
  wire [$clog2((MAC_COEFF_NUM+1)/2)-1:0] coeff_addr;
  wire [$clog2(MAC_COEFF_NUM)-1:0] coeff_addr_a;
  wire [$clog2(MAC_COEFF_NUM)-1:0] coeff_addr_b;
  
  wire [COEFF_SIZE-1:0] coeff_out [0:MAC_NUM_FIX-1];
  wire [SAMPLE_SIZE-1:0] samples [0:MAC_NUM_FIX];
  wire [SAMPLE_SIZE+COEFF_SIZE-1:0] dout_a [0:MAC_NUM_FIX-1];
  wire [SAMPLE_SIZE+COEFF_SIZE-1:0] dout_b [0:MAC_NUM_FIX-1];

  reg  [SAMPLE_SIZE+COEFF_SIZE-1:0] sum_a;
  reg  [SAMPLE_SIZE+COEFF_SIZE-1:0] sum_b;
  wire [SAMPLE_SIZE+COEFF_SIZE-1:0] sum_a_scaled;
  wire [SAMPLE_SIZE+COEFF_SIZE-1:0] sum_b_scaled;
  wire [SAMPLE_SIZE+1:0] sum_a_round;
  wire [SAMPLE_SIZE+1:0] sum_b_round;
  wire [SAMPLE_SIZE-1:0] sum_a_conv;
  wire [SAMPLE_SIZE-1:0] sum_b_conv;
  reg  [SAMPLE_SIZE-1:0] phases [0:M/2-1];
  wire phase_0;

  clock_divider #(D) i_clk_div_0(
    .in_clk(clk), 
    .rst(nrst),
    .out_clk(clk_fs_new)
  );

  //holds valid_in value
  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      valid_in_reg <= 0;
    end else if (!c_we && clk_fs_new) begin
      if (phase_step_cnt == M-1) valid_in_reg <= 0;
      else if (valid_in) valid_in_reg <= 1;
    end
  end

  //holds input
  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      din_reg <= 0;
    end else if (!c_we && clk_fs_new && valid_in) begin
      din_reg <= din;
    end
  end

  assign en = (phase_step_cnt_d == phase_step_cnt) ? 0 : 1;

  //check if memories are empty
  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      valid_data_cnt <= 0;
    end else if (!c_we) begin
      if (phase_0 && clk_fs_new_d1) begin
        if (valid_data_cnt == POLY_NUM) valid_data_cnt <= POLY_NUM;
        else valid_data_cnt <= valid_data_cnt + 1;
      end
    end
  end

  assign valid_data = (valid_data_cnt == POLY_NUM) ? 1 : 0;
  
  //counts what phase should be calculated
  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      phase_step_cnt <= 0;
    end else if (!c_we) begin
      if (clk_fs_new) begin
        if ((phase_step_cnt == M-1)) phase_step_cnt <= (valid_in || valid_in_reg) ? 0 : M-1;
        else phase_step_cnt <= phase_step_cnt + 1;
      end
    end
  end

  assign phase_0 = (phase_step_cnt == 0) ? 1 : 0;

  //counts what address should new sample be written to
  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      poly_step_cnt <= 0;
    end else if (!c_we && en) begin
      if (clk_fs_new && (phase_step_cnt == M-1)) begin
        if (poly_step_cnt == MAC_POLY_NUM-1) poly_step_cnt <= 0;
        else poly_step_cnt <= poly_step_cnt + 1;
      end
    end
  end

  //counts address of needed sample for mac
  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      poly_addr_cnt <= 0;
    end else if (!c_we && en) begin
      if (clk_fs_new_d1) poly_addr_cnt <= poly_step_cnt;
      else if (poly_addr_cnt == 0) poly_addr_cnt <= MAC_POLY_NUM-1;
      else poly_addr_cnt <= poly_addr_cnt - 1;
    end
  end

  //counts reversed address of needed sample for mac
  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      poly_rev_addr_cnt <= MAC_POLY_NUM-1;
    end else if (!c_we && en) begin
      if (clk_fs_new_d1) poly_rev_addr_cnt <= (poly_step_cnt == MAC_POLY_NUM-1) ? 0 : poly_step_cnt+1;
      else if (poly_rev_addr_cnt == MAC_POLY_NUM-1) poly_rev_addr_cnt <= 0;
      else poly_rev_addr_cnt <= poly_rev_addr_cnt + 1;
    end
  end

  //counts mac step
  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      cnt <= 0;
    end else if (!c_we && en) begin
      if (clk_fs_new_d1) cnt <= 0;
      else if (cnt == MAC_POLY_NUM) cnt <= MAC_POLY_NUM;
      else cnt <= cnt + 1;
    end
  end

  //counts phases according to div input
  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      div_phase_cnt <= 0;
    end else if (!c_we) begin
      if (clk_fs_new) begin
        if (div_phase_cnt == div-1 || phase_step_cnt == M-1) div_phase_cnt <= 0;
        else div_phase_cnt <= div_phase_cnt + 1;
      end
    end
  end

  always @(posedge clk) begin
    en_a <= en_pr_a;
    en_b <= en_pr_b;
  end

  always @(posedge clk) begin
    clk_fs_new_d0 <= clk_fs_new;
    clk_fs_new_d1 <= clk_fs_new_d0;
    clk_fs_new_d2 <= clk_fs_new_d1;
  end
  
  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      en_pr <= 0;
    end else begin
      if (cnt == MAC_POLY_NUM-1 || c_we) en_pr <= 0;
      else if (clk_fs_new_d1 && phase_step_cnt < (M+1)/2) en_pr <= 1;
    end
  end

  assign poly_addr = (phase_0 && (clk_fs_new_d0 || clk_fs_new_d1)) ? poly_step_cnt : poly_addr_cnt;

  assign en_pr_a = (div_phase_cnt == 0) && en_pr;
  assign en_pr_b = (div_phase_cnt == div-1) && en_pr;

  assign sample_mem_en = en_pr_a || (phase_0&& (clk_fs_new_d0 || clk_fs_new_d1));
  assign coeff_mem_en = en_pr_a || en_pr_b;

  assign clk_div_out = (div_phase_cnt == 1 || div == 1) && clk_fs_new_d1;

  assign we = clk_fs_new_d1 && phase_0;
  assign acc_nrst = nrst && !clk_fs_new_d2;

  integer j,k;

  //coeff adresses decoder (according to phase)
  generate
    if (IS_ODD == 1) begin : center_mac_addr
      // odd symmetry
      reg [$clog2((MAC_COEFF_NUM+1)/2)-1:0] coeff_addr_r;
      always @(*) begin
        coeff_addr_r = 0;
        for (j=0; j < MAC_POLY_NUM; j=j+1) begin
          for (k=0; k < M; k=k+1) begin
            if (cnt == j && phase_step_cnt == k) coeff_addr_r = (k+j*M<(MAC_COEFF_NUM+1)/2) ? k+j*M : (MAC_COEFF_NUM%2 == 0) ? MAC_POLY_NUM*M-1-(k+j*M) : MAC_POLY_NUM*M-2-(k+j*M);
          end
        end
      end
      assign coeff_addr = (c_we) ? dec_c_addr[$clog2(MAC_COEFF_NUM+1/2)-1:0] : coeff_addr_r;
    end

    if (MAC_NUM_FIX != 1) begin : paired_mac_addr
      // symmetric macs
      reg [$clog2(MAC_COEFF_NUM)-1:0] coeff_addr_a_r;
      always @(*) begin
        coeff_addr_a_r = 0;
        for (j=0; j < MAC_POLY_NUM; j=j+1) begin
          for (k=0; k < M; k=k+1) begin
            if (cnt == j && phase_step_cnt == k) coeff_addr_a_r = k+j*M;
          end
        end
      end
      assign coeff_addr_a = (c_we) ? dec_c_addr : coeff_addr_a_r;
      assign coeff_addr_b = MAC_COEFF_NUM-1-coeff_addr_a_r;
    end
  endgenerate

  //coeff adresses decoder (according to c_addr)
  always @(*) begin
    dec_c_addr = 0;
    coeff_we = 0;
    for (j = 0; j < MAC_COEFF_NUM; j = j+1) begin
      for (k = 0; k < MAC_NUM_FIX/2+IS_ODD; k = k+1) begin
        if (c_addr == j+k*(MAC_COEFF_NUM)) begin
          dec_c_addr = j;
          coeff_we = (c_we) ? 1 << k : 0;
        end
      end
    end
  end
  
  always @(*) begin
    sum_a = dout_a[0];
    sum_b = dout_b[0];
    for(j = 1; j < MAC_NUM_FIX; j = j + 1) begin
      sum_a = $signed(sum_a) + $signed(dout_a[j]);
      sum_b = $signed(sum_b) + $signed(dout_b[j]);
    end
  end

  assign sum_a_scaled = $signed(sum_a)*M;
  assign sum_b_scaled = $signed(sum_b)*M;

  assign sum_a_round = sum_a_scaled[SAMPLE_SIZE+COEFF_SIZE-1 -: SAMPLE_SIZE+2] + 1;
  assign sum_b_round = sum_b_scaled[SAMPLE_SIZE+COEFF_SIZE-1 -: SAMPLE_SIZE+2] + 1;

  localparam OVF = 2**(SAMPLE_SIZE-1);

  assign sum_a_conv = (sum_a_round[SAMPLE_SIZE+1 -: 2] == 2'b10) ? OVF   :
                      (sum_a_round[SAMPLE_SIZE+1 -: 2] == 2'b01) ? OVF-1 :
                       sum_a_round[SAMPLE_SIZE:1];

  assign sum_b_conv = (sum_b_round[SAMPLE_SIZE+1 -: 2] == 2'b10) ? OVF   :
                      (sum_b_round[SAMPLE_SIZE+1 -: 2] == 2'b01) ? OVF-1 :
                       sum_b_round[SAMPLE_SIZE:1];
  
  always @(posedge clk) begin
    if (clk_fs_new) begin
      phase_step_cnt_d <= phase_step_cnt;
    end
  end

  //load to second half phases reg
  always @(posedge clk or negedge nrst) begin
      if (!nrst) begin
        for (j = 0; j < M/2; j = j+1) begin
          phases[j] <= 0;
        end
      end else if (!c_we && valid_data) begin
        if (clk_fs_new_d1) begin
          if (phase_step_cnt_d < M/2) begin
            phases[0] <= sum_b_conv;
            for (j = 0; j < M/2-1; j = j+1) begin
                phases[j+1] <= phases[j];
            end
          end
        end
      end
    end
  
  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      dout <= 0;
    end else if (valid_data) begin
      if (clk_div_out) begin
         if (phase_step_cnt_d >= (M+1)/2) dout <= phases[phase_step_cnt_d-(M+1)/2];
         else dout <= sum_a_conv;
      end
    end
  end

  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      valid_out <= 0;
    end else if (!c_we && valid_data && clk_fs_new_d1) begin
         valid_out <= (en && clk_div_out) ? 1 : 0;
    end
  end

  assign samples[0] = din_reg;
  
  genvar i;
  generate
    for(i = 0; i < (MAC_NUM_FIX-IS_ODD)/2+IS_ONE; i = i + 1) begin
      if (i == (MAC_NUM_FIX-IS_ODD)/2-1+IS_ONE && IS_ODD == 1) begin
        MAC #(MAC_POLY_NUM, SAMPLE_SIZE, COEFF_SIZE) i_MAC(
          .clk(clk),
          .nrst(acc_nrst),
          .en_a(en_a),
          .en_b(en_b),
          .mem_en_a(sample_mem_en),
          .mem_en_b(en_pr_b),
          .coeff_a(coeff_out[(MAC_NUM_FIX-1)/2]),
          .coeff_b(coeff_out[(MAC_NUM_FIX-1)/2]),
          .we(we),
          .addr_a(poly_addr),
          .addr_b(poly_rev_addr_cnt),
          .mem_in(samples[(MAC_NUM_FIX-1)/2]),
          .mem_out(samples[(MAC_NUM_FIX-1)/2+1]),
          .dout_a(dout_a[(MAC_NUM_FIX-1)/2]),
          .dout_b(dout_b[(MAC_NUM_FIX-1)/2])
        );
        single_port_RAM #(COEFF_SIZE, (MAC_COEFF_NUM+1)/2) coeff_single_ram(
          .clk(clk),
          .en(coeff_mem_en || c_we),
          .we(coeff_we[i+1-IS_ONE]),
          .addr(coeff_addr),
          .din(c_in),
          .dout(coeff_out[(MAC_NUM_FIX-1)/2])
        );
      end
      if (IS_ONE != 1) begin
        MAC #(MAC_POLY_NUM, SAMPLE_SIZE, COEFF_SIZE) i_MAC_a(
          .clk(clk),
          .nrst(acc_nrst),
          .en_a(en_a),
          .en_b(en_b),
          .mem_en_a(sample_mem_en),
          .mem_en_b(en_pr_b),
          .coeff_a(coeff_out[i]),
          .coeff_b(coeff_out[MAC_NUM_FIX-1-i]),
          .we(we),
          .addr_a(poly_addr),
          .addr_b(poly_rev_addr_cnt),
          .mem_in(samples[i]),
          .mem_out(samples[i+1]),
          .dout_a(dout_a[i]),
          .dout_b(dout_b[i])
        );
        MAC #(MAC_POLY_NUM, SAMPLE_SIZE, COEFF_SIZE) i_MAC_b(
          .clk(clk),
          .nrst(acc_nrst),
          .en_a(en_a),
          .en_b(en_b),
          .mem_en_a(sample_mem_en),
          .mem_en_b(en_pr_b),
          .coeff_a(coeff_out[MAC_NUM_FIX-1-i]),
          .coeff_b(coeff_out[i]),
          .we(we),
          .addr_a(poly_addr),
          .addr_b(poly_rev_addr_cnt),
          .mem_in(samples[MAC_NUM_FIX-1-i]),
          .mem_out(samples[MAC_NUM_FIX-i]),
          .dout_a(dout_a[MAC_NUM_FIX-1-i]),
          .dout_b(dout_b[MAC_NUM_FIX-1-i])
        );
        true_dual_port_RAM #(COEFF_SIZE, MAC_COEFF_NUM) coeff_dual_ram(
          .clk_a(clk),
          .clk_b(clk),
          .en_a(coeff_mem_en || c_we),
          .en_b(coeff_mem_en),
          .we_a(coeff_we[i]),
          .we_b(GND),
          .addr_a(coeff_addr_a),
          .addr_b(coeff_addr_b),
          .din_a(c_in),
          .din_b(GND),
          .dout_a(coeff_out[i]),
          .dout_b(coeff_out[MAC_NUM_FIX-1-i])
        );
      end
    end
  endgenerate

endmodule