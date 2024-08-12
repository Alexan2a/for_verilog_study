module Moore_TB (
);

  reg [2:0] q_TB;
  wire [2:0] w_TB;
  reg clk_TB, r_TB;

  Moore mygate (.q(q_TB), .w(w_TB), .clk(clk_TB), .reset(r_TB));

  initial begin
      r_TB = 1;
      q_TB = 0;
      clk_TB = 0;
      #6 q_TB = 1;
      #2 r_TB = 0;
      #40 q_TB = 1;
      #120 q_TB = 0;
      #47 q_TB = 4;
      #20 q_TB = 1;
      #80 q_TB = 5;
      #75 q_TB = 2;
      #164 q_TB = 3;
      #14 q_TB = 7;
      #20 q_TB = 4;
      #87 q_TB = 1;
      #20 q_TB = 8;
      #130 q_TB = 2;
      #35 q_TB = 6;
      #150 q_TB = 1;
      #40 q_TB = 4;
      #28 q_TB = 2;
  end

  always #5 clk_TB = ~clk_TB;

endmodule
