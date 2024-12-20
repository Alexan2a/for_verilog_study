module fir#(parameter ORD = 256, parameter D = 52, parameter SAMPLE_SIZE = 16, parameter COEFF_SIZE = 16)(
  input  wire nrst,
  input  wire clk,
  
  input  wire [SAMPLE_SIZE-1:0] din,
  output wire [SAMPLE_SIZE-1:0] dout,

  input  wire c_WE,
  input  wire [COEFF_SIZE-1:0] c_in,
  input  wire [$clog2((ORD + 1) >> 1)-1:0] c_addr
);

  //MAC_SIZE - needed cells in MAC
  //MAC_NUM - needed number of MACs
  //D - number of periods og working rate in period fs
  //ORD - order of filter
  
  localparam MAC_SIZE = (ORD+1)/6; // should be 43 
  localparam MAC_NUM = $ceil(((ORD)/2)/(D - 3) + 1); // should be 3 (-3 for memory new sample writes)
  localparam RND = 2**(SAMPLE_SIZE-1);

  localparam N = 2; // !!!READ THIS PLEASE this is for sum rounding, if it is 5, number of mistakes is 0

  reg [SAMPLE_SIZE-1:0]          out_r;
  reg [SAMPLE_SIZE+COEFF_SIZE:0] sum_r;
  reg [SAMPLE_SIZE+COEFF_SIZE-1 : COEFF_SIZE-N]          sum_round;
  reg [1:0] check_sum;

  reg                  mac_s_we;
  reg [MAC_NUM-1:0]    mac_c_we;
  reg [COEFF_SIZE-1:0] mac_c_in;
  
  reg [$clog2(MAC_SIZE)-1:0] cnt_0; 
  reg [$clog2(MAC_SIZE)-1:0] cnt_1;
  reg [$clog2(MAC_SIZE)-1:0] coeff_cnt; 
  reg [$clog2(MAC_SIZE)-1:0] step_cnt;
  reg [$clog2(MAC_SIZE)-1:0] mac_addr_0;
  reg [$clog2(MAC_SIZE)-1:0] mac_addr_1;
  reg [$clog2(MAC_SIZE)-1:0] mac_c_addr;

  wire [SAMPLE_SIZE-1:0] mac_samples[0: MAC_NUM*2 + 1];
  wire [SAMPLE_SIZE+COEFF_SIZE:0] mac_outs[0:MAC_NUM-1];

  reg  en;
  reg  en_dl_0;
  reg  en_dl_1;
  wire mac_en;

  wire clk_fs;
  reg  clk_fs_dl;

  clock_divider #(D) i_clk_div( //coeff 52
    .in_clk(clk), 
    .rst(nrst),
    .out_clk(clk_fs)
  );

  always @(posedge clk) begin
    clk_fs_dl <= clk_fs;
  end

  assign dout = out_r;

  //counts sum of MAC outputs format Q16.15
  integer j;
  always @(*) begin
    sum_r = 0;
    for(j = 0; j < MAC_NUM; j = j + 1) begin
      sum_r = $signed(sum_r) + $signed(mac_outs[j]);  //33.30
    end
    sum_round = sum_r[SAMPLE_SIZE+COEFF_SIZE-1 -: SAMPLE_SIZE+N] + 1; //18.16
    check_sum = sum_round[SAMPLE_SIZE+COEFF_SIZE-1 -: 2];
  end

  // for 1'st sample memory
  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      cnt_0 <= 0;
    end else if (!c_WE) begin
      if (clk_fs_dl) cnt_0 <= step_cnt;
      else if (cnt_0 == 0) cnt_0 <= MAC_SIZE-1;
      else cnt_0 <= cnt_0 - 1;
    end
  end

  // for 2'nd sample memory
  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      cnt_1 <= MAC_SIZE-1;
    end else if (!c_WE) begin
      if (clk_fs_dl) cnt_1 <= (step_cnt == MAC_SIZE-1) ? 0 : (step_cnt + 1);
      else if (cnt_1 == MAC_SIZE-1) cnt_1 <= 0;
      else cnt_1 <= cnt_1 + 1;
    end
  end


  // for coeffs memory
  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      coeff_cnt <= 0;
    end else if (!c_WE) begin
      if (clk_fs_dl) coeff_cnt <= 0;
      else if (coeff_cnt == MAC_SIZE-1) coeff_cnt <= MAC_SIZE-1;
      else coeff_cnt <= coeff_cnt + 1;
    end
  end

   // just to count adresses of sample memories
  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      step_cnt <= 0;
    end else if (!c_WE) begin
      if (clk_fs_dl) begin
        if (step_cnt == MAC_SIZE-1) step_cnt <= 0;
        else step_cnt <= step_cnt + 1;
      end
    end
  end

  always @(posedge clk or negedge nrst) begin

    if (!nrst) begin
      mac_c_we <= 0;
      en <= 0;
    end else begin
      if (c_WE) begin

        mac_c_in <= c_in;
        if (c_addr < MAC_SIZE) begin
          mac_c_addr <= c_addr;
          mac_c_we[0] <= 1;
          mac_c_we[1] <= 0;
          mac_c_we[2] <= 0;
        end else if (c_addr > MAC_SIZE*2 - 1) begin
          mac_c_addr <= (c_addr - MAC_SIZE*2);
          mac_c_we[0] <= 0;
          mac_c_we[1] <= 0;
          mac_c_we[2] <= 1;
        end else begin
          mac_c_addr <= (c_addr - MAC_SIZE);
          mac_c_we[0] <= 0;
          mac_c_we[1] <= 1;
          mac_c_we[2] <= 0;
        end

      end else begin

        mac_c_we <= 0;

      // addresses of sample memories
        if (clk_fs || clk_fs_dl) begin
          mac_addr_0 <= step_cnt;    
          mac_addr_1 <= step_cnt;
        end else begin
          mac_addr_0 <= cnt_0; 
          mac_addr_1 <= cnt_1;
        end

      //coeff address
        mac_c_addr <= coeff_cnt;

        if (clk_fs || clk_fs_dl) en <= 1'b1;
        else if (coeff_cnt == MAC_SIZE-1) en <= 1'b0;
        else en <= 1'b1;

        en_dl_0 <= en;
        en_dl_1 <= en_dl_0;

      // write enable
        if (clk_fs_dl) begin
          mac_s_we <= 1;
        end else begin
          mac_s_we <= 0;
        end

        if (clk_fs) begin
          out_r <= (check_sum == 2'b01) ? RND :
                   (check_sum == 2'b10) ? RND-1 :
                    sum_round[SAMPLE_SIZE+COEFF_SIZE-2 -: SAMPLE_SIZE];
        end
      end
    end
  end

  assign mac_samples[0] = din;
  assign mac_samples[MAC_NUM+1] = mac_samples[MAC_NUM];
  assign mac_en = en || en_dl_1 || en_dl_0;

  genvar i;
  generate
    for(i = 0; i < MAC_NUM; i = i + 1) begin

      MAC #(MAC_SIZE, SAMPLE_SIZE, COEFF_SIZE) i_MAC(
        .clk(clk),
        .rst(nrst),
        .WE(mac_s_we),
        .c_in(mac_c_in),
        .c_addr(mac_c_addr),
        .c_WE(mac_c_we[i]),
        .en(mac_en),
        .wr_addr_0(mac_addr_0),
        .wr_addr_1(mac_addr_1),
        .rd_addr_0(mac_addr_0),
        .rd_addr_1(mac_addr_1),
        .mem_in_0(mac_samples[i]),
        .mem_in_1(mac_samples[MAC_NUM*2-i]),
        .mem_out_0(mac_samples[i+1]),
        .mem_out_1(mac_samples[MAC_NUM*2-i+1]),
        .dout(mac_outs[i])
      );

    end
  endgenerate

endmodule