module uart_tb();
	
	reg clk, rst, valid;
	reg [7:0] in;
	wire out, ready;

	initial 
		begin
			valid = 1;
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
	always #600 in = in + 1;

	uart_tx mygate(.rst(rst), .clk(clk), .tx_data(in), .tx(out), .tx_ready(ready), .tx_valid(valid));
	
endmodule