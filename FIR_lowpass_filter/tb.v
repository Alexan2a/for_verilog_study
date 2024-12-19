`include "fir_coeffs.v"
`resetall

module tb();

  reg [15:0] in_vect[0:1920], in;
  wire [15:0] coeffs_array_0[0:128];

// Execute macro
  `COEFFS_ARRAY_0

  wire[15:0] out;
  reg clk, clk_fs, rst;
  reg c_we, check_en;
  reg [7:0] err_cnt;
  reg [15:0] check;
  integer N;
  integer M;

  localparam D = 52;
  localparam ORD = 257;
  localparam S = 16;
  localparam C = 16;

  integer FILE_1;

  initial
    begin: read_block
      $readmemb("in_Data.txt", in_vect);
    end

  initial
    begin: file_IO_block
      FILE_1 = $fopen("Data_out.txt", "w");
      #1000900 $fclose(FILE_1);
    end

  initial begin
     clk = 1'b1;
     clk_fs = 1'b1;
     rst = 1'b1;
     c_we = 1'b1;
     N = 0;
     M = 0;
     in = in_vect[0];
     check_en = 0;
     err_cnt = 0;
  #5 rst = 1'b0;
  #5 rst = 1'b1;
  #135470 check_en = 1;
  end


  always #5 clk = ~clk;
  always #520 clk_fs = !clk_fs;

  //coeff load
  reg [7:0] cnt = 0;
  always @(posedge clk or negedge rst) begin
    if (!rst) begin
      cnt <= 0;
    end else if (cnt == 128) begin //128
      cnt <= 128;
      c_we <= 1'b0;
    end else begin
      cnt <= cnt+1;
    end
  end

  //pick next sample
  always @(clk_fs) begin
    if (!c_we) begin
      N = N + 1;
      in = in_vect[N];
    end
  end

  always @(clk_fs)
    begin: write_block
      $fdisplay(FILE_1, "0b%bs16", out);
    end

  fir#(ORD, D, S, C) i_fir(
    .nrst(rst),
    .clk(clk),
    .din(in),
    .dout(out),
    .c_WE(c_we),
    .c_in(coeffs_array_0[cnt]),
    .c_addr(cnt)
  );

  always @(clk_fs) begin
    if (check_en) begin
      check = $signed(coeffs_array_0[M]) >>> 3;
      if (out != check) begin
	      err_cnt = err_cnt + 1;
        $error("out: expected = %h, real = %h",check, out);
      end
      M = M + 1;
    end
  end

  initial begin
    #1000900 $display("Output errors: %d", err_cnt);
    $stop();
  end

endmodule