module fir #(
  parameter ORD = 256,
  parameter D = 52,
  parameter SAMPLE_SIZE = 16,
  parameter COEFF_SIZE = 16)
(
  input  wire nrst,
  input  wire clk,
  input  wire [SAMPLE_SIZE-1:0] din,
  output reg  [SAMPLE_SIZE-1:0] dout,

  input  wire c_WE,
  input  wire [COEFF_SIZE-1:0] c_in,
  input  wire [$clog2((ORD + 1) >> 1)-1:0] c_addr
);

  //MAC_SIZE - needed cells in MAC
  //MAC_NUM - needed number of MACs
  //D - number of periods og working rate in period fs
  //ORD - order of filter
  
  localparam MAC_SIZE = (ORD+1)/6;
  localparam MAC_NUM = (((ORD/2) + (D-2))/(D - 2));
  localparam RND = 2**(SAMPLE_SIZE-1);

  reg [SAMPLE_SIZE+COEFF_SIZE:0] sum;

  wire [SAMPLE_SIZE+2 : 0] sum_round;

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

  clock_divider #(D) i_clk_div(
    .in_clk(clk), 
    .rst(nrst),
    .out_clk(clk_fs)
  );

  always @(posedge clk) begin
    clk_fs_dl <= clk_fs;
  end

  //counts sum of MAC outputs format Q16.15
  integer j,k;
  always @(*) begin
    sum = mac_outs[0];
    for(j = 1; j < MAC_NUM; j = j + 1) begin
      sum = $signed(sum) + $signed(mac_outs[j]);  //33.30
    end
  end

  /////////////////////////////////////////////////////////////////////////
  //                                                                     //
  //     ROUND:                                                          //
  //                                                                     //
  //     sum_round is [32,31,30 . 29,28,...,15,(14)],    Q19.16          //
  //                                            +1                       //
  //              !!!: 14's will be deleted                              //
  //                                                                     //
  //     check:       [(32),(31),30] from sum_r                          //       
  //                  [(18),(17),16] from sum_round                      //
  //                                                                     //
  //              !!!: 32'nd, 31'st (18's, 17's) will be deleted         //
  //                                                                     //
  //     out is       [30 . 29,28,...,16,15]             Q16.15          //
  //                                                                     //        
  /////////////////////////////////////////////////////////////////////////

  assign sum_round = sum[SAMPLE_SIZE+COEFF_SIZE -: SAMPLE_SIZE+3]+1;  //19.16

  reg [$clog2(ORD+1)-1:0] valid_data_cnt;
  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      valid_data_cnt <= 0;
    end else if (!c_WE) begin
      if (clk_fs) begin
        if (valid_data_cnt == ORD+1) valid_data_cnt <= ORD+1;
        else valid_data_cnt <= valid_data_cnt + 1;
      end
    end
  end

  assign valid_data = (valid_data_cnt == ORD+1) ? 1 : 0;

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
      dout <= 0;
    end else if (clk_fs) begin
      if (valid_data && !c_WE) begin
          dout <= (sum_round[SAMPLE_SIZE+2] == 1 && ~&sum_round[SAMPLE_SIZE+2 -: 2]) ? RND   :
                  (sum_round[SAMPLE_SIZE+2] == 0 &&  |sum_round[SAMPLE_SIZE+2 -: 2]) ? RND-1 :
                   sum_round[SAMPLE_SIZE : 1];
      end else dout <= 0;
    end
  end

  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      en <= 0;
      mac_addr_0 <= 0;
      mac_addr_1 <= MAC_SIZE-1;
      en_dl_0 <= 0;
      en_dl_1 <= 0;
      mac_s_we <= 0;
    end else begin
      if (!c_WE) begin
      
      // addresses of sample memories
        if (clk_fs || clk_fs_dl) begin
          mac_addr_0 <= step_cnt;    
          mac_addr_1 <= step_cnt;
        end else begin
          mac_addr_0 <= cnt_0; 
          mac_addr_1 <= cnt_1;
        end

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
      end
    end
  end
  
  always @(posedge clk) begin
    if (c_WE) begin
      mac_c_in <= c_in;
      for (j = 0; j < MAC_SIZE; j = j+1) begin
        for (k = 0; k < MAC_NUM; k = k+1) begin
          if (c_addr == j+k*MAC_SIZE) begin
            mac_c_addr <= j;
            mac_c_we <= 1 << k;
          end
        end
      end
    end else begin
      mac_c_we <= 0;
      mac_c_addr <= coeff_cnt;
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