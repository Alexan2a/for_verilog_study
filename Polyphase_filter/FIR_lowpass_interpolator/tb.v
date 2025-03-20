`include "coeffs.v"
`resetall

module tb();

  reg clk, clk_fs_new, clk_fs_old, c_we, nrst, check_en, valid;
  reg [15:0] check;
  wire [15:0] out;
  
  reg [15:0] in_vect[0:512], in;
  wire [15:0] coeffs_array_0[0:127];
  integer N=0, K=0, err_cnt=0;

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
  #258025 check_en = 1;
  end

  initial begin
  valid = 1;
  #288000 valid = 0;
  #1000 valid = 1;
  #1000 valid = 0;
  #3000 valid = 1;
  #1000 valid = 0;
  #13000 valid = 1;
  end

  always #5 clk = !clk;
  always #500 clk_fs_new = !clk_fs_new;
  always #4000 clk_fs_old = !clk_fs_old;

  localparam ORD = 255;
  localparam D = 100; 
  localparam M = 8;
  localparam COEFF_SIZE = 16;
  localparam SAMPLE_SIZE = 16;

  reg [7:0] cnt = 0;
  always @(posedge clk or negedge nrst) begin
    if (!nrst) begin
      cnt <= 0;
    end else if (cnt == 127) begin
      cnt <= 127;
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
      #1200000 $fclose(FILE_1);
    end
  wire valid_out;
  always @(posedge clk_fs_new)
    begin: write_block
      if(valid_out) $fdisplay(FILE_1, "0b%bs16", out);
    end

  always @(posedge clk_fs_new) begin
    if (check_en) begin
      check = ((($signed(-coeffs_array_0[K])*M )>>> 2) + 1) >>> 1;
      if (out != check) begin
	      err_cnt = err_cnt + 1;
        $error("out: expected = %h, real = %h",check, out);
      end
      if (valid_out) K = K + 1;
    end
  end

  initial begin
    #400000 $display("Output errors: %d", err_cnt);
    $stop();
  end
  wire [2:0] div = 1;
  fir_interpolator #(ORD,M,D,COEFF_SIZE,SAMPLE_SIZE) i_fir(
    .nrst(nrst),
    .clk(clk),
    .valid_in(valid),
    .valid_out(valid_out),
    .div(div),
    .din(in),
    .dout(out),

    .c_we(c_we),
    .c_in(coeffs_array_0[cnt]),
    .c_addr(cnt)
);

endmodule