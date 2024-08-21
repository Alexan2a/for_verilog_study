module DC_filter_TB();

reg [15:0] in_vect[0:435], in;
wire[15:0] out;
reg clk, rst;
integer N;

DC_filter mygate (clk, rst, in, out);

integer FILE_1;

initial
  begin: read_block
    $readmemb("in_Data.txt", in_vect);
  end
initial
  begin: file_IO_block
    FILE_1 = $fopen("Data_out.txt", "w");
    #8700 $fclose(FILE_1);
  end

initial
  begin
    clk = 1'b1;
    rst = 1'b1;
    N = 0;
    in = in_vect[0];
    #5 rst = 1'b0;
  end


always #10 clk = ~clk;

always @(posedge clk)
  begin: write_block
    $fdisplay(FILE_1, "0b%bs16", out);
  end

always @(posedge clk)
  begin
    N = N + 1;
    in = in_vect[N];
  end

endmodule
