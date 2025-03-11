`include "coeffs.v"
`resetall

module tb();

  reg clk, clk_fs_new, clk_fs_old, c_we, nrst, check_en;
  wire clk_fs_new_div;
  reg [15:0] check;
  wire [15:0] out;
  
  reg [15:0] in_vect[0:1024], in;
  wire [15:0] coeffs_array_0[0:255];
  integer N=0, K=0, err_cnt=0;

  localparam ORD = 255;
  localparam M = 8;
  localparam D = 100;
  localparam COEFF_SIZE = 16;
  localparam SAMPLE_SIZE = 16;

  `COEFFS_ARRAY_0

  initial begin
  check_en = 0;
  N = 0;
  K = 0;
  err_cnt = 0;
  in = 0;
  clk = 0;
  clk_fs_new = 0;
  clk_fs_old = 0;
  c_we = 1;
  nrst = 0;
  #5 nrst = 1;
  #130000 check_en = 1;
  end

  clock_divider #(D) i_clk_div_0(
    .in_clk(clk), 
    .rst(nrst),
    .out_clk(clk_fs_new_div)
  );

  always #5 clk = !clk;
  always #500 clk_fs_old = !clk_fs_old;
  always #4000 clk_fs_new = !clk_fs_new;

  reg [7:0] cnt = 0;
  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      cnt <= 0;
    end else if (cnt == 255) begin
      cnt <= 255;
      c_we <= 1'b0;
    end else begin
      cnt <= cnt+1;
    end
  end

  integer FILE_1;

  initial
    begin: read_block
      $readmemb("Data_in.txt", in_vect);
    end

  always @(posedge clk_fs_old) begin
    if (!c_we) begin
      N = N + 1;
      in = in_vect[N];
    end
  end

  initial
    begin: file_IO_block
      FILE_1 = $fopen("Data_out.txt", "w");
      #1000000 $fclose(FILE_1);
    end

  always @(posedge clk_fs_new)
    begin: write_block
      $fdisplay(FILE_1, "0b%bs16", out);
    end

  always @(posedge clk_fs_old) begin
    if (check_en) begin
      check = ((($signed(-coeffs_array_0[K]))>>> 2) + 1) >>> 1;
      if (out != check) begin
	err_cnt = err_cnt + 1;
        $error("out: expected = %h, real = %h",check, out);
      end
      K = K + 1;
    end
  end

  initial begin
    #1000000 $display("Output errors: %d", err_cnt);
    $stop();
  end

  fir_decimator #(ORD,M,D,COEFF_SIZE,SAMPLE_SIZE) i_fir(
    .nrst(nrst),
    .clk(clk),
    .din(in),
    .dout(out),

    .c_we(c_we),
    .c_in(coeffs_array_0[cnt]),
    .c_addr(cnt)
);

endmodule