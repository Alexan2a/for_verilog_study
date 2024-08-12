//variant 1
module Sch_TB ();

reg [20:0]i;
reg [3:0] a1_TB, a0_TB, m2_TB, m1_TB, m0_TB;
reg cin_TB;
wire [3:0] mout3_TB1, mout2_TB1, mout1_TB1, mout0_TB1, mout3_TB2, mout2_TB2, mout1_TB2, mout0_TB2;
wire cout_TB1, cout_TB2;

reg a;
parameter N = 4;

Sch_v1 mygate1 (a1_TB, a0_TB, m2_TB, m1_TB, m0_TB, cin_TB, mout3_TB1, mout2_TB1, mout1_TB1, mout0_TB1, cout_TB1);
Sch_v2 #(N) mygate2 (a1_TB, a0_TB, m2_TB, m1_TB, m0_TB, cin_TB, mout3_TB2, mout2_TB2, mout1_TB2, mout0_TB2, cout_TB2);
initial
	begin
		a1_TB = 0;
		a0_TB = 0;
		m2_TB = 0;
		m1_TB = 0;
		m0_TB = 0;
		cin_TB = 0;
		i = 0;
		a = 0;
	end
always #20 a = ~a;
always @(a)
	begin
//chisto polet fantasii, ne znayu chto tut nado
		i = i + 1;
		cin_TB = i[20];
		a1_TB = i[19:16];
		a0_TB = i[15:12];
		m2_TB = i[11:8];
		m1_TB = i[7:4];
		m0_TB = i[3:0];
	end

endmodule