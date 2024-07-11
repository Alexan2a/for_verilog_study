module clock_divider #(parameter N)(input wire in_clk, output reg out_clk);

	reg [9:0] counter = 10'd0;
	always @(posedge in_clk)
		begin
 			if (counter >= (N - 1))
  				counter <= 10'd0;
			else
				counter <= counter + 10'd1;
			if (counter < N/2) 
				out_clk <= 1'b1;
			else
				out_clk <= 1'b0;
 			//out_clk <= (counter < N/2) ? 1'b1 : 1'b0;
		end
endmodule

module uart(input wire rst, clk, 
	input wire rx,
	input wire[7:0] tx_data,
	output wire[7:0] rx_data, 
	output reg tx);

	reg ti, tx_empty;
	wire clk1, clk2;
	reg [9:0] count1 = 10'd0;
	reg [6:0] count2;
	reg [7:0] tx_reg, rx_reg;
	reg [9:0] tx_shift, rx_shift;
	
	parameter N = 868;
	parameter M = 87;

	clock_divider #(N) d1(.in_clk(clk), .out_clk(clk1));
	clock_divider #(M) d2(.in_clk(clk), .out_clk(clk2));


	//transfer input 
	always @(posedge clk1) 
		begin
			if(!rst) begin
				tx_empty <= 1'b1; //maybe this has no sense
			end else begin
				if (tx_empty) begin
					tx_reg <= tx_data;
					tx_empty <= 1'b0;
				end
			end
		end

	//shift register
	always @(posedge clk2 or negedge rst)
		begin
			if(!rst) begin
				tx_shift <= 10'd2047;
				ti <= 1;
				tx_empty <= 1'b1;
			end else begin
				if(ti&&(~tx_empty)) begin
					tx_shift <= {1'b0, tx_reg, 1'b0};
					ti <= 1'b0;
					tx_empty <= 1'b1;
				end
				else begin
					if (tx_shift == 10'b0111111111) 
						ti <= 1'b1;
					tx <= tx_shift[9];
					tx_shift <= {tx_shift[8:0],1'b1};
				end
			end
		end
endmodule