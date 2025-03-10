module fir_decimator#(
  parameter ORD = 255,
  parameter M = 8, 
  parameter D = 100,
  parameter COEFF_SIZE = 16, 
  parameter SAMPLE_SIZE = 16,
  parameter MAC_NUM = 1
)(
  input  wire nrst,
  input  wire en,
  input  wire clk,
  input  wire [SAMPLE_SIZE-1:0] din,
  output reg  [SAMPLE_SIZE-1:0] dout,

  input  wire c_we,
  input  wire [COEFF_SIZE-1:0] c_in,
  input  wire [$clog2(ORD + 1)-1:0] c_addr
);

  localparam POLY_NUM = (ORD+1)/M;
  localparam MAC_NUM_FIX = ((POLY_NUM+(D-2)-1)/(D-2) > MAC_NUM) ? (POLY_NUM+(D-2)-1)/(D-2) : MAC_NUM;

  wire clk_fs_old;
  wire clk_fs_new;

  reg clk_fs_old_d0;
  reg clk_fs_old_d1;
  reg clk_fs_old_d2;

  reg  [$clog2(M)-1:0] cnt;
  reg  [$clog2(M)-1:0] cnt_d;
  reg  [M-1:0] fir_en;
  reg  [$clog2(POLY_NUM)-1:0] coeff_addr;
  reg  [M-1:0] coeff_we;
  reg  [SAMPLE_SIZE+COEFF_SIZE-1:0] out;
  wire [SAMPLE_SIZE+COEFF_SIZE-1:0] fir_out [0:M-1];

  reg  [SAMPLE_SIZE+COEFF_SIZE-1:0] acc;
  wire [SAMPLE_SIZE+1:0] acc_round;
  wire [SAMPLE_SIZE-1:0] acc_conv;

  reg  [$clog2(ORD+2)-1:0] valid_data_cnt;
  wire valid_data;

  clock_divider #(D) i_clk_div_0(
    .in_clk(clk), 
    .rst(nrst),
    .out_clk(clk_fs_old)
  );

  clock_divider #(M) i_clk_div_1(
    .in_clk(clk_fs_old), 
    .rst(nrst),
    .out_clk(clk_fs_new)
  );

  always @(posedge clk) begin
    clk_fs_old_d0 <= clk_fs_old;
    clk_fs_old_d1 <= clk_fs_old_d0;
    clk_fs_old_d2 <= clk_fs_old_d1;
  end

  //check if memories are empty
  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      valid_data_cnt <= 0;
    end else if (!c_we) begin
      if (clk_fs_old_d1) begin
        if (valid_data_cnt == ORD+1) valid_data_cnt <= ORD+1;
        else valid_data_cnt <= valid_data_cnt + 1;
      end
    end
  end

  assign valid_data = (valid_data_cnt == ORD+1) ? 1 : 0;

  always @(posedge clk) begin
    if (clk_fs_old) cnt_d <= cnt;
  end

  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      cnt <= 0;
    end else if (!c_we) begin
      if (clk_fs_old) begin
        if (clk_fs_new) cnt <= M-2;
        else if (cnt == 0) cnt <= M-1;
        else cnt <= cnt - 1;
      end
    end
  end

  integer j,k;
  always @(*) begin
    if (c_we) begin
      fir_en = coeff_we;
    end else begin
      for (j = 0; j < M; j = j+1) begin
        if (cnt == j) fir_en = 1 << j;
      end
    end
  end

  always @(*) begin
    for (j = 0; j < POLY_NUM; j = j+1) begin
      for (k = 0; k < M; k = k+1) begin
        if (c_addr == k+j*M) begin
          coeff_addr = j;
          coeff_we = (c_we) ? 1 << k : 0;
        end
      end
    end
  end

  wire acc_nrst;
  assign acc_nrst = nrst && !(clk_fs_new && clk_fs_old_d0);

  /*always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      out <= 0;
    end else if (clk_fs_old_d1) begin 
      if (valid_data) out <= (cnt == M-1) ? fir_out[0] : fir_out[cnt+1]; //32.30
      else out <= 0;
    end
  end*/

  always @(*) begin
    out = (!valid_data) ? 0 : 
          (cnt == M-1)  ? fir_out[0] : 
           fir_out[cnt+1]; //32.30
  end

  always @(posedge clk or negedge acc_nrst) begin
    if (!acc_nrst) begin
      acc <= 0;
    end else if (!c_we && clk_fs_old_d1) begin 
      acc <= $signed(acc) + $signed(out); //32.30
    end
  end

  localparam OVF = 2**(SAMPLE_SIZE-1);
  assign acc_round = acc[SAMPLE_SIZE+COEFF_SIZE-1 -: SAMPLE_SIZE+2] + 1;
  assign acc_conv = (acc_round[SAMPLE_SIZE+1 -: 2] == 2'b10) ? OVF   :
                    (acc_round[SAMPLE_SIZE+1 -: 2] == 2'b01) ? OVF-1 :
                     acc_round[SAMPLE_SIZE:1];

  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      dout <= 0;
    end else if (clk_fs_old && clk_fs_new) begin 
      dout <= acc_conv; //32.30
    end
  end

  genvar i;
  generate
    for(i = 0; i < M; i = i + 1) begin
      fir #(POLY_NUM-1, D, COEFF_SIZE, SAMPLE_SIZE, MAC_NUM_FIX) i_fir(
        .nrst(nrst),
        .en(fir_en[i]),
        .clk(clk),
        .clk_fs(clk_fs_old),
        .clk_fs_d0(clk_fs_old_d0),
        .clk_fs_d1(clk_fs_old_d1),
        .clk_fs_d2(clk_fs_old_d2),
        .din(din),
        .dout(fir_out[i]),
        .c_we(coeff_we[i]),
        .c_in(c_in),
        .c_addr(coeff_addr)
      );
    end
  endgenerate

endmodule