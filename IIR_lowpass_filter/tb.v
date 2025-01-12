`include "iir_coeffs.v"
`resetall

module tb();

  reg  [15:0] in_vect[0:5000], in;
  wire [15:0] coeffs_array [0:19];

// Execute macro
  `COEFFS_ARRAY

  wire[23:0] out;
  wire[31:0] out_f;
  reg clk, clk_fs, rst;
  reg c_we;
  integer N;
  integer M;

  integer FILE_1;

  /*initial
    begin: read_block
      $readmemb("Data_in.txt", in_vect);
    end*/

  initial
    begin: file_IO_block
      FILE_1 = $fopen("Data_out.txt", "w");
      #2700900 $fclose(FILE_1);
    end

  integer i;
  initial begin
    for (i = 0; i < 5000; i=i+1) begin
      in_vect[i] = 0;
      if (i == 2) begin
        in_vect[i][15] = 1;
      end
    end
  end

  initial begin
     clk = 1'b1;
     clk_fs = 1'b1;
     rst = 1'b1;
     c_we = 1'b1;
     N = 0;
     M = 0;
     in = in_vect[0];
  #5 rst = 1'b0;
  #5 rst = 1'b1;
  end


  always #5 clk = ~clk;
  always #520 clk_fs = !clk_fs;

  //coeff load
  reg [4:0] cnt = 0;
  always @(posedge clk or negedge rst) begin
    if (!rst) begin
      cnt <= 0;
    end else if (cnt == 19) begin //128
      cnt <= 19;
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

  assign out_f = {{8{out[23]}}, out};
  always @(clk_fs)
    begin: write_block
      $fdisplay(FILE_1, "0b%bs32", out_f);
    end

  iir i_iir(
    .clk(clk),
    .nrst(rst),

    .c_we(c_we),
    .c_in(coeffs_array[cnt]),
    .c_addr(cnt),

    .din(in),
    .dout(out)
  );

endmodule