//variant 37
module Sch_TB();

reg [7:0]D_i;
wire [3:0]D_o;
reg a, E, SED;
Sch mygate (D_i[0],D_i[1],D_i[2],D_i[3],D_i[4],D_i[5],D_i[6],D_i[7],SED,E,D_o[0],D_o[1],D_o[2],D_o[3]);

initial
	begin
		E = 1;
		SED = 0;
		D_i = 0;
		a = 0;
	end
always #10240 E = ~E;
always #5120 SED = ~SED;
always #20 a = ~a;
always @(a)
	begin
		D_i = D_i + 1;
	end
endmodule  

