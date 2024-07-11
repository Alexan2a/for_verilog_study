module uart_tb();
	
	reg clk, rst;
	reg [7:0] in;
	wire [7:0] b;
	wire out;
	reg a;

	initial 
		begin
			clk = 0;
			in = 0;
		end

	initial 
		begin
			rst = 1;
			#10 rst = 0;
			#10 rst = 1;
		end

	always #5 clk = ~clk;
	always #60 in = in + 1;

	uart mygate(rst, clk, a, in, b, out);
	

	
endmodule