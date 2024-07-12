module uart_tx(input wire rst, clk, tx_valid,
	input wire[7:0] tx_data,
	output reg tx, tx_ready);

	reg tx_empty;
	wire clk1, clk2;
	reg [7:0] tx_reg;
	reg [9:0] tx_shift;
	
	parameter N = 868;
	parameter M = 87;

	clock_divider #(N) d1(.rst(rst), .in_clk(clk), .out_clk(clk1));
	clock_divider #(M) d2(.rst(rst), .in_clk(clk), .out_clk(clk2));

	//transfer input 
	always @(posedge clk1) 
		begin
			if(!rst) begin
				tx_empty <= 1'b1; //maybe this has no sense
			end else begin
				if (tx_empty && tx_valid && tx_ready) begin
					tx_reg <= tx_data;
					tx_empty <= 1'b0;
					tx_ready <= 1'b0;
				end
			end
		end

	//shift register
	always @(posedge clk2 or negedge rst)
		begin
			if(!rst) begin
				tx_shift <= 10'd2047;
				tx_ready <= 1'b1;
				//ti <= 1;
				tx_empty <= 1'b1;
			end else begin
				if(~tx_empty) begin
					tx_shift <= {1'b0, tx_reg, 1'b0};
					//ti <= 1'b0;
					tx_empty <= 1'b1;
				end
				else begin
					if (tx_shift[8:0] == 9'b011111111) 
						//ti <= 1'b1;
						tx_ready = 1'b1;
					tx <= tx_shift[9];
					tx_shift <= {tx_shift[8:0],1'b1};
				end
			end
		end
endmodule