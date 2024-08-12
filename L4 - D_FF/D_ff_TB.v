module D_ff_TB (
);

  reg D_TB, C_TB;
  wire Q1_TB, Q2_TB;

  D_ff mygate1 (.D(D_TB), .C(C_TB), .Q(Q1_TB));
  D_ff_alg mygate2 (.D(D_TB), .C(C_TB), .Q(Q2_TB));

  initial begin
      D_TB = 0;
      C_TB = 0;
      #40 D_TB = ~D_TB;
      #120 D_TB = ~D_TB;
      #47 D_TB = ~D_TB;
      #20 D_TB = ~D_TB;
      #80 D_TB = ~D_TB;
      #75 D_TB = ~D_TB;
      #164 D_TB = ~D_TB;
      #14 D_TB = ~D_TB;
      #20 D_TB = ~D_TB;
      #87 D_TB = ~D_TB;
      #20 D_TB = ~D_TB;
      #130 D_TB = ~D_TB;
      #35 D_TB = ~D_TB;
      #150 D_TB = ~D_TB;
      #40 D_TB = ~D_TB;
      #28 D_TB = ~D_TB;
  end

  always #10 C_TB = ~C_TB;

endmodule
