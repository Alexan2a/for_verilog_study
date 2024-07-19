module uart_tb();
	
	reg clk, clk1, rst, valid;
	reg [7:0] in;
	wire out, tx_ready, rx_ready, n_out, err;

	initial 
		begin
			valid = 1;
			clk = 0;
			clk1 = 1;
			in = 0;
			#300000 valid = 0;
			#50000 valid = 1;
		end

	initial 
		begin
			rst = 1;
			#10 rst = 0;
			#10 rst = 1;
		end

	always #5 clk = ~clk;
	always #5 clk1 = ~clk1;
	always #600 in = in + 1;

	uart_tx mygate(.rst(rst), .clk(clk), .tx_data(in), .tx(out), .tx_ready(tx_ready), .tx_valid(valid));
	uart_rx mygate1(.rst(rst), .clk(clk1), .rx_data(n_out), .rx(out), .rx_ready(rx_ready), .rx_err(err));
	
endmodule