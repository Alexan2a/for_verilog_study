module tb();

  reg [15:0] in_vect[0:1920], in;

  wire[15:0] out;
  reg clk, clk_fs_0, clk_fs_1, nrst, mode, mu_we;
  reg valid_d, valid_u;
  reg [15:0] u, d;
  wire valid_out;
  wire [15:0] mu;
  wire clk_fs;
  integer N;
  integer M;

  assign mu = 16'b0000110111110011;

  localparam S = 17;
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
     clk_fs_0 = 1'b1;
     clk_fs_1 = 1'b1;
     mode = 0;
     nrst = 1'b1;
     valid_d = 1;
     valid_u = 1;
     u = 16'b0000100000000001;
     d = 16'b1100000000000000;
     mu_we = 1'b1;
  #5 nrst = 1'b0;
  #5 nrst = 1'b1;
  #5 mu_we = 1'b0;
  #65000 valid_u = 0;
  #5000 valid_u = 1;
  #1000000 mode = 1;
  end


  always #5 clk = ~clk;
  always #22675 clk_fs_0 = !clk_fs_0;
  always #20830 clk_fs_1 = !clk_fs_1;

  assign clk_fs = (mode) ? clk_fs_1 : clk_fs_0;

  always @(clk_fs) begin
      N = N + 1;
      in = in_vect[N];
      u = u+1;
  end

  always @(clk_fs)
    begin: write_block
      $fdisplay(FILE_1, "0b%bs16", out);
    end

  LMS_filter #(S, C) i_fir(
    .nrst(nrst),
    .clk(clk),
    .valid_d_in(valid_d),
    .valid_u_in(valid_u),
    .valid_out(valid_out),
    .mode(mode),
    .mu_in(mu),
    .mu_we(mu_we),
    .u_in(u),
    .d_in(d),
    .out(out)
  );

endmodule