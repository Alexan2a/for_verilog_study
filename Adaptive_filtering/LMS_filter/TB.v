module tb();

  reg [15:0] u_vect[0:200000];
  reg [15:0] d_vect[0:200000];

  wire[15:0] out;
  reg clk, clk_fs_0, clk_fs_1, nrst, mode, mu_we;
  reg valid;
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
    begin: read_block_u
      $readmemb("In_noise.txt", u_vect);
    end

  initial
    begin: read_block_d
      $readmemb("In_data.txt", d_vect);
    end

  initial
    begin: file_IO_block
      FILE_1 = $fopen("Out_data.txt", "w");
      #4258250000 $fclose(FILE_1);
    end

  initial begin
     clk = 1'b1;
     clk_fs_0 = 1'b1;
     clk_fs_1 = 1'b1;
     N = -1;
     mode = 0;
     nrst = 1'b1;
     valid = 1;
     u = 0;
     d = 0;
     mu_we = 1'b1;
  #5 nrst = 1'b0;
  #5 nrst = 1'b1;
  #5 mu_we = 1'b0;
  #65000 valid = 0;
  #5000 valid = 1;
  #1133750000 mode = 1;
  end


  always #5 clk = ~clk;
  always #22675 clk_fs_0 = !clk_fs_0;
  always #20830 clk_fs_1 = !clk_fs_1;

  assign clk_fs = (mode) ? clk_fs_1 : clk_fs_0;

  always @(clk_fs) begin
      N = N + 1;
      u = u_vect[N];
      d = d_vect[N];
  end

  always @(clk_fs)
    begin: write_block
      if (valid_out) begin
        $fdisplay(FILE_1, "0b%bs16", out);
      end
    end

  LMS_filter #(S, C) i_fir(
    .nrst(nrst),
    .clk(clk),
    .valid_in(valid),
    .valid_out(valid_out),
    .mode(mode),
    .mu_in(mu),
    .mu_we(mu_we),
    .u_in(u),
    .d_in(d),
    .out(out)
  );

endmodule