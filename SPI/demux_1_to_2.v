module demux_2_to_1(
  input  wire Sel,
  input  wire D,
  output wire S0,
  output wire S1
);

  assign S0 = ~Sel | D;
  assign S1 =  Sel | D;

endmodule
