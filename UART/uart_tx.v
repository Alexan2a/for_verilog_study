module uart_tx(input wire rst, clk, tx_valid,
	input wire[7:0] tx_data,
	output reg tx, tx_ready);

	//reg tx_to_reg, tx_to_shift;
	wire clk1, clk2;
	reg tx_empty;
	reg[13:0] div10 = 14'd10;
	reg[13:0] div868 = 14'd868;
	reg [7:0] tx_reg;
	reg [9:0] tx_shift;
	
	//parameter N = 868;
	//parameter M = 10;

	clock_divider d1(.rst(rst), .coef(div10), .in_clk(clk2), .out_clk(clk1));
	clock_divider d2(.rst(rst), .coef(div868), .in_clk(clk), .out_clk(clk2));

	always @(posedge clk2 or negedge rst)
		begin
			if(!rst) begin
				tx_shift <= 10'd2047;
				tx_empty <= 1'b1;
				tx_ready <= 1'b1;
				//tx_to_reg <= 1'b1;
				//tx_to_shift <= 1'b1;
			end else begin 
				if(~tx_empty) begin
					tx_shift <= {1'b0, tx_reg, 1'b0};
					tx_empty <= 1'b1;
				end else begin
					if (tx_shift[7:0] == 8'b01111111) 
						tx_ready <= 1'b1;
					tx <= tx_shift[9];
					tx_shift <= {tx_shift[8:0],1'b1};
				end
				if (clk1) begin
					if (tx_empty && tx_valid && tx_ready) begin
						tx_reg <= tx_data;
						tx_empty <= 1'b0;
						tx_ready <= 1'b0;
						//tx_to_reg <= ~tx_to_reg;
					end
				end
			end
		end

endmodule