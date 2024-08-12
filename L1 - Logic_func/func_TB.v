//variant 1
module func_TB();
reg x1_TB, x2_TB, x3_TB, x4_TB;
wire y1_TB, y2_TB, y3_TB;

func mygate (x1_TB, x2_TB, x3_TB, x4_TB, y1_TB, y2_TB, y3_TB);

initial
	begin
    		x1_TB = 0;
		x2_TB = 0;
		x3_TB = 0;
		x4_TB = 0;
    
    	end
	always #200 x1_TB = ~x1_TB;
	always #100 x2_TB = ~x2_TB;
	always #50 x3_TB = ~x3_TB;
	always #25 x4_TB = ~x4_TB;
    
endmodule

