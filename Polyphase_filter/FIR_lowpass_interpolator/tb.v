`include "coeffs.v"
`resetall

module tb();

  reg clk, clk_fs_new, clk_fs_old, c_we, nrst;
  reg [15:0] din;
  wire [15:0] out;
  
  reg [15:0] in_vect[0:512], in;
  wire [15:0] coeffs_array_0[0:127];
  integer N=0;

  `COEFFS_ARRAY_0

  initial begin
  N = 0;
  in = 0;
  din = 16'd0;
  clk = 0;
  clk_fs_new = 0;
  clk_fs_old = 0;
  c_we = 1;
  nrst = 0;
  #5 nrst = 1;
  #80000 din[15] = 1;
  #8000 din = 16'd0;
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
    end else if (cnt == 127) begin //128
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

  always @(clk_fs_old) begin
    if (!c_we) begin
      N = N + 1;
      in = in_vect[N];
    end
  end

  initial
    begin: file_IO_block
      FILE_1 = $fopen("Data_out.txt", "w");
      #1000900 $fclose(FILE_1);
    end

  always @(clk_fs_new)
    begin: write_block
      $fdisplay(FILE_1, "0b%bs16", out);
    end

  fir_interpolator #(ORD,M,D,COEFF_SIZE,SAMPLE_SIZE) i_fir(
    .nrst(nrst),
    .clk(clk),
    .din(in),
    .dout(out),

    .c_we(c_we),
    .c_in(coeffs_array_0[cnt]),
    .c_addr(cnt)
);

endmodule