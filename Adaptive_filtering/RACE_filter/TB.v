module tb();

  reg [15:0] x_vect_real[0:399999];
  reg [15:0] x_vect_imag[0:399999];

  wire[15:0] out_real, out_imag;
  reg clk, nrst;
  reg valid;
  reg [15:0] x_real, x_imag;
  wire valid_out;
  wire strobe;

  integer N;
  integer M;

  localparam S = 16;
  localparam C = 16;

  integer FILE_1, FILE_2;

 initial
    begin: read_block_real
      $readmemb("PATH_TO_FILE/Data_in_real.txt", x_vect_real); //paste your pass to file
    end
 initial
    begin: read_block_imag
      $readmemb("PATH_TO_FILE/Data_in_imag.txt", x_vect_imag); //paste your pass to file
    end

  initial
    begin: file_IO_block1
      FILE_1 = $fopen("PATH_TO_FILE/Data_out_real.txt", "w"); //paste your pass to file
      #80000020 $fclose(FILE_1);
    end

  initial
    begin: file_IO_block2
      FILE_2 = $fopen("PATH_TO_FILE/Data_out_imag.txt", "w"); //paste your pass to file
      #80000020 $fclose(FILE_2);
    end

  initial begin
     clk = 1'b1;
     N = 0;
     nrst = 1'b1;
     valid = 1;
     x_real = 0;
     x_imag = 0;
  #5 nrst = 1'b0;
  #5 nrst = 1'b1;
  #65000 valid = 0;
  #5000 valid = 1;
  end

  always #5 clk = ~clk;

  always @(posedge strobe) begin
      N <= N + 1;
      x_real <= x_vect_real[N];
      x_imag <= x_vect_imag[N];
  end

  always @(posedge strobe)
    begin: write_block1
      //begin
        $fdisplay(FILE_1, "0b%bs16", out_real);
     // end
    end

  always @(posedge strobe)
    begin: write_block2
     // if (valid_out) begin
        $fdisplay(FILE_2, "0b%bs16", out_imag);
     // end
    end

  clock_divider #(20) i_clk_div(
    .in_clk(clk), 
    .rst(nrst),
    .out_clk(strobe)
  );

  RACE_top i_fir(
    .nrst(nrst),
    .clk(clk),
    .strobe(strobe),
    .in_real(x_real),
    .in_imag(x_imag),
    .out_real(out_real),
    .out_imag(out_imag)
  );

endmodule