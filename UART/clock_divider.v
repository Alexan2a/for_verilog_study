module clock_divider #(parameter N)(input wire in_clk, rst, output reg out_clk);

	reg [9:0] counter;
	always @(posedge in_clk or negedge rst)
		begin
 			if (counter >= (N - 1) || !rst)
  				counter <= 10'd0;
			else
				counter <= counter + 10'd1;
 			out_clk <= (counter < N/2) ? 1'b1 : 1'b0;
		end
endmodule
