module N (input X, output reg Y);

always @(X)
  begin
    Y <= #1 ~X;
  end
endmodule

module A2 (input X1, X2, output reg Y);

always @(X1,X2)
  begin
    Y <= #2 X1 & X2;
  end
endmodule

module NO3 (input X1, X2, X3, output reg Y);

always @(X1,X2)
  begin
    Y <= #4 ~(X1 | X2 | X3);
  end
endmodule

module Sch (input wire X0,X1,X2,X3,X4,X5,X6,X7,X8,X9, output wire Y0,Y1,Y2,Y3);

  wire W0, W1, W2, a0, a1, a2, a3, a4, a5, a6, a7;
  N i_n0(X8,W0);
  N i_n1(W0,W1);
  N i_n2(X9,W2);
  A2 i_and0(X0,W0,a0);
  A2 i_and1(X1,W1,a1);
  A2 i_and2(X2,W0,a2);
  A2 i_and3(X3,W1,a3);
  A2 i_and4(X4,W0,a4);
  A2 i_and5(X5,W1,a5);
  A2 i_and6(X6,W0,a6);
  A2 i_and7(X7,W1,a7);
  NO3 i_nor0(a0,a1,W2,Y0);
  NO3 i_nor1(a2,a3,W2,Y1);
  NO3 i_nor2(a4,a5,W2,Y2);
  NO3 i_nor3(a6,a7,W2,Y3);
	
endmodule