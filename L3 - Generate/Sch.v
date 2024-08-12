module AND2 (
  input x1, x2,
  output reg y
);

  always @(x1,x2) begin
    y = x1 & x2;
  end

endmodule

module ADD2 (
  input a1, a2,
  output wire [1:0]p
);

  reg [1:0] s;

  always @(a1,a2) begin
    s = a1 + a2;
  end

  assign p = s;

endmodule

module ADD3 (
  input a1, a2, a3, 
  output wire [1:0]p
);

  reg [1:0] s;

  always @(a1,a2,a3) begin
    s = a1 + a2 + a3;
  end
  assign p = s;
endmodule


module MULT2 (
  input a1, a0, b1, b0, 
  output wire [3:0]p
);

  wire [3:0]z;

  AND2 el_1(.x1(a0),.x2(b0),.y(p[0]));
  AND2 el_2(.x1(a0),.x2(b1),.y(z[0]));
  AND2 el_3(.x1(a1),.x2(b0),.y(z[1]));
  AND2 el_4(.x1(a1),.x2(b1),.y(z[2]));
  ADD2 a_1(.a1(z[0]),.a2(z[1]),.p({z[3],p[1]}));
  ADD2 a_2(.a1(z[2]),.a2(z[3]),.p(p[3:2]));

endmodule

module subSch (
  input wire [1:0] a1, a0, m2, m1, m0, 
  input wire cin,
  output wire [1:0] mout3, mout2, mout1, mout0, 
  output wire cout
);

  wire [2:0] z;

  ADD3 a_0(.a1(a0[0]),.a2(a1[0]),.a3(cin),.p(z[1:0]));
  MULT2 m_0(.a1(z[0]),.a0(m2[0]),.b1(m1[0]),.b0(m0[0]),.p({mout3[0], mout2[0], mout1[0], mout0[0]}));
  ADD3 a_1(.a1(a0[1]),.a2(a1[1]),.a3(z[1]),.p({cout,z[2]}));
  MULT2 m_1(.a1(z[2]),.a0(m2[1]),.b1(m1[1]),.b0(m0[1]),.p({mout3[1], mout2[1], mout1[1], mout0[1]}));

endmodule


module Sch_v1 (
  input wire [3:0] a1, a0, m2, m1, m0,
  input wire cin,
  output wire [3:0] mout3, mout2, mout1, mout0,
  output wire cout
);

  wire z;

  subSch sb0(a1[1:0], a0[1:0], m2[1:0], m1[1:0], m0[1:0], cin, mout3[1:0], mout2[1:0], mout1[1:0], mout0[1:0], z);
  subSch sb1(a1[3:2], a0[3:2], m2[3:2], m1[3:2], m0[3:2], z, mout3[3:2], mout2[3:2], mout1[3:2], mout0[3:2], cout);

endmodule

module Sch_v2 #(parameter N=4)(
  input wire [N-1:0] a1, a0, m2, m1, m0,
  input wire cin,
  output wire [N-1:0] mout3, mout2, mout1, mout0,
  output wire cout
);

  wire [N:0] z;
  wire [N-1:0] z_m;

  assign z[0] = cin;
  assign cout = z[N];

  genvar i;
  generate
    for(i = 0; i < N; i = i + 1) begin
      ADD3 a_0(.a1(a0[i]),.a2(a1[i]),.a3(z[i]),.p({z[i+1],z_m[i]}));
      MULT2 m_0(.a1(z_m[i]),.a0(m2[i]),.b1(m1[i]),.b0(m0[i]),.p({mout3[i], mout2[i], mout1[i], mout0[i]}));
    end
  endgenerate

endmodule
